"""Fine-tune a Gemini model on the Voya itinerary dataset (Vertex AI supervised tuning).

Before running (once):
    pip install -r requirements.txt
    gcloud auth application-default login
    gcloud config set project voya-f69f0
    gcloud services enable aiplatform.googleapis.com storage.googleapis.com

Run:
    python generate_dataset.py
    python train_vertex.py

It uploads data/train.jsonl + data/val.jsonl to Cloud Storage, starts the
tuning job, waits for it, and writes tuned_model.json with the endpoint
name that functions/index.js (generateItinerary) should call.
"""
import argparse
import json
import sys
import time
from pathlib import Path

HERE = Path(__file__).parent


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", default="voya-f69f0")
    ap.add_argument("--location", default="us-central1")
    ap.add_argument("--bucket", default=None, help="GCS bucket name (default: <project>-itinerary-tuning)")
    ap.add_argument("--base-model", default="gemini-3.5-flash",
                    help="must be a model Vertex AI currently allows tuning on - see README")
    ap.add_argument("--epochs", type=int, default=3)
    ap.add_argument("--adapter-size", type=int, default=4, choices=[1, 2, 4, 8, 16, 32])
    ap.add_argument("--lr-multiplier", type=float, default=None)
    ap.add_argument("--name", default="voya-itinerary-v2")
    ap.add_argument("--no-wait", action="store_true", help="start the job and exit")
    args = ap.parse_args()

    from google import genai
    from google.cloud import storage
    from google.genai import types

    for split in ("train", "val"):
        if not (HERE / "data" / f"{split}.jsonl").exists():
            sys.exit("data/ is missing - run: python generate_dataset.py")

    # 1. upload the dataset
    bucket_name = args.bucket or f"{args.project}-itinerary-tuning"
    gcs = storage.Client(project=args.project)
    bucket = gcs.lookup_bucket(bucket_name) or gcs.create_bucket(bucket_name, location=args.location)
    uris = {}
    for split in ("train", "val"):
        blob = bucket.blob(f"{args.name}/{split}.jsonl")
        blob.upload_from_filename(str(HERE / "data" / f"{split}.jsonl"))
        uris[split] = f"gs://{bucket_name}/{blob.name}"
        print("uploaded", uris[split])

    # 2. start tuning
    client = genai.Client(vertexai=True, project=args.project, location=args.location)
    adapter = {1: "ONE", 2: "TWO", 4: "FOUR", 8: "EIGHT", 16: "SIXTEEN", 32: "THIRTY_TWO"}[args.adapter_size]
    job = client.tunings.tune(
        base_model=args.base_model,
        training_dataset=types.TuningDataset(gcs_uri=uris["train"]),
        config=types.CreateTuningJobConfig(
            tuned_model_display_name=args.name,
            validation_dataset=types.TuningValidationDataset(gcs_uri=uris["val"]),
            epoch_count=args.epochs,
            adapter_size=getattr(types.AdapterSize, f"ADAPTER_SIZE_{adapter}"),
            learning_rate_multiplier=args.lr_multiplier,
        ),
    )
    print("tuning job:", job.name)
    print(f"watch it: https://console.cloud.google.com/vertex-ai/studio/tuning?project={args.project}")
    if args.no_wait:
        return

    # 3. wait (usually well under an hour for this dataset)
    state = lambda j: getattr(j.state, "name", str(j.state))
    while state(job) in ("JOB_STATE_PENDING", "JOB_STATE_RUNNING", "JOB_STATE_QUEUED"):
        time.sleep(60)
        job = client.tunings.get(name=job.name)
        print(time.strftime("%H:%M:%S"), state(job))

    if state(job) != "JOB_STATE_SUCCEEDED":
        sys.exit(f"tuning did not succeed: {state(job)} {job.error}")

    result = {
        "job": job.name,
        "base_model": args.base_model,
        "endpoint": job.tuned_model.endpoint,   # <- what the Cloud Function calls
        "model": job.tuned_model.model,
        "epochs": args.epochs,
        "adapter_size": args.adapter_size,
    }
    (HERE / "tuned_model.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))
    print("\nnext:  python evaluate.py --model", args.base_model, "--label base")
    print("       python evaluate.py --model", result["endpoint"], "--label tuned")
    print("       python evaluate.py --report")


if __name__ == "__main__":
    main()
