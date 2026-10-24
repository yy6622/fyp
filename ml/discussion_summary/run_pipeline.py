"""Runs the whole pipeline in order (about 2-4 minutes):

  1. template chats            generate_template_data.py
  2. hand-written chats        challenge_data.py (test only), manual_data.py (training)
  2b. public datasets         import_public_datasets.py (MultiWOZ, CrossWOZ, DialogSum; downloaded once)
  3. merge + split             build_dataset.py      (also picks up your checked real chats,
                                                       data/real_*.csv, as the test_real split)
  4. Experiment A + train      train_classifier.py
  4b. Experiment A3            experiment_public.py  (with vs without the public data; full run only)
  5. export + copy to app      export_model.py --deploy
  6. Experiment B              evaluate_summary.py
  7. Python == JavaScript      test_parity.py        (skipped if Node.js is not installed)

  python run_pipeline.py            full run (5-8 minutes)
  python run_pipeline.py --quick    retrain only the selected model, skip the weight search (~1 minute)
"""
import shutil
from pathlib import Path
import subprocess
import sys

QUICK = "--quick" in sys.argv   # skip Experiment A's model comparison (about 1 minute instead of 5-8)

STEPS = [
    ["generate_template_data.py"],
    ["challenge_data.py"],
    ["manual_data.py"],
    ["smalltalk_test.py"],
    ["import_public_datasets.py"],
    ["build_dataset.py"],
    ["train_classifier.py"] + (["--quick"] if QUICK else []),
] + ([] if QUICK else [["experiment_public.py"]]) + [
    ["export_model.py", "--deploy"],
    ["evaluate_summary.py"] + (["--quick"] if QUICK else []),
]

for step in STEPS:
    print(f"\n=== python {' '.join(step)}")
    subprocess.run([sys.executable] + step, check=True)
if shutil.which("node"):
    print("\n=== python test_parity.py")
    subprocess.run([sys.executable, "test_parity.py"], check=True)
    print("\n=== node test_planner.js (AI Summarise builds an organised plan)")
    subprocess.run(["node", "../ml/discussion_summary/test_planner.js"], check=True, cwd=str(Path(__file__).resolve().parents[2] / "functions"))
    print("\n=== node test_optimise.js (Optimise reworks a plan, no AI)")
    subprocess.run(["node", "../ml/discussion_summary/test_optimise.js"], check=True, cwd=str(Path(__file__).resolve().parents[2] / "functions"))
    print("\n=== node test_osm_places.js (wishes without a place name: catalog_places / OpenStreetMap)")
    subprocess.run(["node", "../ml/discussion_summary/test_osm_places.js"], check=True, cwd=str(Path(__file__).resolve().parents[2] / "functions"))
else:
    print("\n(Node.js not found - skipped test_parity.py)")
print("\nDone. Results: results/experiment_A.md, results/experiment_B.md")
