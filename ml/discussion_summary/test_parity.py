"""Checks that the deployed JavaScript summariser (functions/discussion_summary/)
gives the same result as the Python one evaluated in the report.

  python test_parity.py            # every test split
Needs Node.js on PATH. Also checks that model.json / lexicons.json in functions/
are byte-identical to the ones here.
"""

import filecmp
import json
import subprocess
import sys

from common import DATA, MODELS, ROOT, read_jsonl
from model_runtime import TextModel
from summariser import summarise

FN = ROOT.parent.parent / "functions" / "discussion_summary"
NUM_TOL = 2e-3


def compare(a, b, path=""):
    if isinstance(a, dict) and isinstance(b, dict):
        if set(a) != set(b):
            return f"{path}: keys {sorted(set(a) ^ set(b))}"
        for k in a:
            d = compare(a[k], b[k], f"{path}.{k}")
            if d:
                return d
        return None
    if isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            return f"{path}: length {len(a)} vs {len(b)}"
        for i, (x, y) in enumerate(zip(a, b)):
            d = compare(x, y, f"{path}[{i}]")
            if d:
                return d
        return None
    if isinstance(a, (int, float)) and isinstance(b, (int, float)) and not isinstance(a, bool):
        return None if abs(a - b) <= NUM_TOL else f"{path}: {a} vs {b}"
    return None if a == b else f"{path}: {a!r} vs {b!r}"


def main():
    for name in ("model.json", "lexicons.json"):
        src = (MODELS / name) if name == "model.json" else (ROOT / name)
        if not filecmp.cmp(src, FN / name, shallow=False):
            sys.exit(f"functions/discussion_summary/{name} is out of date - run: python export_model.py --deploy")
    model = TextModel.load(MODELS / "model.json")
    total = bad = 0
    for p in sorted((DATA / "splits").glob("test_*.jsonl")):
        convs = read_jsonl(p)
        if not convs:
            continue
        out = subprocess.run(["node", str(ROOT / "parity_runner.js"), str(p)], capture_output=True, text=True,
                             encoding="utf-8", check=True).stdout.splitlines()
        for c, js_line in zip(convs, out):
            py = json.loads(json.dumps(summarise(c["messages"], model, c["members"]), ensure_ascii=False))
            diff = compare(py, json.loads(js_line))
            total += 1
            if diff:
                bad += 1
                if bad <= 5:
                    print(f"  {c['conv_id']}: {diff}")
        print(f"{p.stem}: {len(convs)} chats compared")
    print(f"parity: {total - bad}/{total} chats identical")
    if bad:
        sys.exit(1)


if __name__ == "__main__":
    main()
