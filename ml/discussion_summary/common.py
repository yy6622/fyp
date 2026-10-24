"""Shared definitions: labels, dataset schema, file locations.

Dataset format (data/*.jsonl, one conversation per line):
{
  "conv_id": "tpl-0001",
  "source": "template" | "manual" | "challenge" | "firestore",
  "destination": "Shanghai, China",
  "members": ["Amy", "Ben", "Chloe"],
  "messages": [
     {"id": "m001", "speaker": "Amy", "text": "...",
      "label": "ATTRACTION",          # gold message class (one of LABELS)
      "topic": "t3" | null,          # which decision topic the message belongs to
      "stance": "propose" | "agree" | "reject" | "defer" | "finalize" | "info" | "ask" | "none"}
  ],
  "topics": [                        # every proposal made in the chat and how it ended
     {"id": "t3", "category": "ATTRACTION", "value": "The Bund",
      "proposal": "m004",            # id of the message that proposed it
      "status": "confirmed" | "rejected" | "pending"}
  ],
  "facts": {"budget": 3000, "budget_basis": "per_person" | "total" | null,
            "destination": "Shanghai"},
  "reference_summary": "..."         # human-style summary used for ROUGE
}
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent
DATA = ROOT / "data"
MODELS = ROOT / "models"
RESULTS = ROOT / "results"

LABELS = [
    "BUDGET", "DATE", "DESTINATION", "ATTRACTION", "TRANSPORT",
    "ACCOMMODATION", "PREFERENCE", "DECISION", "OTHER",
]
# Categories that carry a decision (something the group can agree on).
TOPIC_CATEGORIES = ["DESTINATION", "BUDGET", "DATE", "ATTRACTION", "TRANSPORT", "ACCOMMODATION"]
# Categories where only one value can win: confirming a new value overrides the old one.
SINGLE_VALUE = {"DESTINATION", "BUDGET", "DATE", "ACCOMMODATION"}
STATUSES = ["confirmed", "rejected", "pending"]


def read_jsonl(path):
    import json
    with open(path, encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def write_jsonl(path, rows):
    import json
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
