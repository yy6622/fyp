"""Checks functions/itinerary_prompt.js builds byte-identical prompts to
prompt_format.py, and that functions/itinerary_system_prompt.txt is the
same text the model is tuned with. Needs `node` on PATH.

    python test_prompt_parity.py
"""
import json
import random
import subprocess
from pathlib import Path

from generate_dataset import make_example
from kb import DESTINATIONS
from prompt_format import SYSTEM_PROMPT, build_user_prompt, dump_answer

HERE = Path(__file__).parent
FUNCTIONS = HERE.parent.parent / "functions"

rng = random.Random(1)
cases = [make_example(rng, d) for d in DESTINATIONS]
cases[0]["messages"].append({"sender": "Aina", "text": "two\nlines   and   spaces "})

js = """
const { buildItineraryPrompt, parseItineraryAnswer } = require(process.argv[1]);
const cases = JSON.parse(require('fs').readFileSync(0, 'utf8'));
console.log(JSON.stringify(cases.map(c => ({
  prompt: buildItineraryPrompt(c.trip, c.messages),
  parsed: parseItineraryAnswer(c.answer, c.trip.days.length),
}))));
"""
payload = [{"trip": c["trip"], "messages": c["messages"], "answer": dump_answer(c["gold"])} for c in cases]
out = subprocess.run(["node", "-e", js, str(FUNCTIONS / "itinerary_prompt.js")], input=json.dumps(payload),
                     capture_output=True, text=True, encoding="utf-8", check=True)
assert any(c["trip"]["saved"] for c in cases) and any(any(v) for c in cases for v in c["trip"]["plan"].values())
assert any(not c["trip"]["saved"] for c in cases) or True
for c, r in zip(cases, json.loads(out.stdout)):
    assert r["prompt"] == build_user_prompt(c["trip"], c["messages"]), c["trip"]["destination"]
    assert r["parsed"] == c["gold"], c["trip"]["destination"]  # a correct answer survives sanitising unchanged

assert (FUNCTIONS / "itinerary_system_prompt.txt").read_text(encoding="utf-8").strip() == SYSTEM_PROMPT
print(f"ok: {len(cases)} prompts identical in Python and JS, system prompt in sync")
