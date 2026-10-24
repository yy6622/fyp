"""Model-assisted labelling of your REAL group chats (no external API).

Step 1  node export_firestore_chats.js            -> data/raw/firestore_messages.csv
Step 2  python prepare_real_labelling.py          -> three CSV files to check in Excel:

  data/real_labels.csv   one row per message. The model's guesses are in model_label /
                         model_stance / model_topic. Where a guess is wrong, type the right
                         value in label / stance / topic. Empty = the guess is right.
                           label : BUDGET DATE DESTINATION ATTRACTION TRANSPORT ACCOMMODATION
                                   PREFERENCE DECISION OTHER
                           stance: propose agree reject defer finalize info ask none
                           topic : id of the topic the message belongs to (t1, t2 ...), "-" for none.
                                   New topic? Use a new id (e.g. u1) and add it to real_topics.csv.
  data/real_topics.csv   one row per topic: category, proposal_message_id, value, status.
                         Correct status where model_status is wrong (confirmed / rejected / pending);
                         delete the row's content (keep id, set status to "drop") for topics that
                         are not real proposals; add rows for topics the model missed.
  data/real_facts.csv    one row per chat: the CONFIRMED destination / budget / budget_basis / dates,
                         and reference_summary - write it yourself, 4-8 short lines like the
                         example in the file. model_summary is only there to save typing; do not
                         just copy it (that would make ROUGE meaningless).

Step 3  python run_pipeline.py   -> the chats become the test_real split (never used for training).

Honesty note for the report: pre-filled labels can anchor the annotator towards the model's
answer. Say that you checked every row, and how many you changed (build_dataset.py prints it).
"""

import csv
from collections import defaultdict

from common import DATA, MODELS
from model_runtime import TextModel
from summariser import summarise

RAW = DATA / "raw" / "firestore_messages.csv"


def main():
    if not RAW.exists():
        raise SystemExit(f"{RAW} not found - run: node export_firestore_chats.js")
    model = TextModel.load(MODELS / "model.json")
    chats = defaultdict(list)
    for r in csv.DictReader(open(RAW, encoding="utf-8-sig")):
        chats[r["conv_id"]].append(r)

    label_rows, topic_rows, fact_rows = [], [], []
    for conv_id, rows in chats.items():
        msgs = [{"id": r["message_id"], "speaker": r["speaker"], "text": r["message"]} for r in rows]
        s = summarise(msgs, model)
        pred = {m["id"]: m for m in s["messages"]}
        for r in rows:
            p = pred[r["message_id"]]
            label_rows.append({"conv_id": conv_id, "message_id": r["message_id"], "speaker": r["speaker"],
                               "message": r["message"], "model_label": p["label"], "model_stance": p["stance"],
                               "model_topic": p["topic"] or "-", "label": "", "stance": "", "topic": ""})
        text_of = {m["id"]: m["text"] for m in msgs}
        for t in s["topics"]:
            topic_rows.append({"conv_id": conv_id, "topic": t["id"], "category": t["category"],
                               "proposal_message_id": t["proposal"], "value": text_of[t["proposal"]][:60],
                               "model_status": t["status"], "status": ""})
        f = s["facts"]
        fact_rows.append({"conv_id": conv_id, "destination": rows[0].get("destination", ""),
                          "budget": f["budget"] or "", "budget_basis": f["budget_basis"] or "",
                          "dates": f["dates"] or "", "reference_summary": "", "model_summary": s["text"]})

    def write(name, rows):
        with open(DATA / name, "w", newline="", encoding="utf-8-sig") as fh:
            w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
            w.writeheader()
            w.writerows(rows)
        print(f"wrote data/{name} ({len(rows)} rows)")

    write("real_labels.csv", label_rows)
    write("real_topics.csv", topic_rows)
    write("real_facts.csv", fact_rows)
    print("Check the three files in Excel (see the top of this script), save as CSV UTF-8, then run run_pipeline.py.")


if __name__ == "__main__":
    main()
