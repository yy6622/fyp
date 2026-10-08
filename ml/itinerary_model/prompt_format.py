"""The one place that defines what the model sees and what it must answer.

functions/itinerary_prompt.js (buildItineraryPrompt) builds the *same* user
prompt from a real Firestore trip, so a model tuned on this format is called
with this format. If you change anything here, change it there too, re-copy
system_prompt.txt into functions/itinerary_system_prompt.txt, and run
test_prompt_parity.py.

Format v2: the model also sees the group's saved places and the current
plan, and answers with changes (add / update / remove) instead of a whole
new itinerary.

Format v3: the model also sees LOGISTICS — the real booked flight arrival
time and hotel check-in/check-out time, when the trip has them — so it can
avoid scheduling anything before the flight actually lands or before
check-in (see system_prompt.txt rule 9), instead of only guessing from the
generic "day 1 / last day" rule.
"""
import json
from pathlib import Path

SYSTEM_PROMPT = (Path(__file__).parent / "system_prompt.txt").read_text(encoding="utf-8").strip()

ICONS = ["flight", "hotel", "shopping", "food", "place", "activity"]


def build_user_prompt(trip: dict, messages: list) -> str:
    """trip: {destination,
              days:   [{day, weekday, date}],
              members:[name],
              saved:  [{name, location, type}]            type: attraction | restaurant
              plan:   {day: [{time, label, location, icon}]},
              flightArrival: str,                          real booked flight's arrival date+time, '' if none
              hotelCheckIn: str,                            real booked hotel's check-in date+time, '' if none
              hotelCheckOut: str}                           real booked hotel's check-out date+time, '' if none
    messages: [{sender, text}] oldest first."""
    lines = ["TRIP", f"destination: {trip['destination']}", f"days: {len(trip['days'])}"]
    for d in trip["days"]:
        lines.append(f"day {d['day']}: {d['weekday']} {d['date']}")
    lines.append("members: " + ", ".join(trip["members"]))

    lines += ["", "LOGISTICS"]
    logistics = []
    if trip.get("flightArrival"):
        logistics.append(f"flight arrival: {trip['flightArrival']}")
    if trip.get("hotelCheckIn"):
        logistics.append(f"hotel check-in: {trip['hotelCheckIn']}")
    if trip.get("hotelCheckOut"):
        logistics.append(f"hotel check-out: {trip['hotelCheckOut']}")
    lines += logistics if logistics else ["(none booked yet)"]

    lines += ["", "SAVED PLACES"]
    if trip.get("saved"):
        for s in trip["saved"]:
            lines.append(f"- {s['name']} | {s['location']} | {s['type']}")
    else:
        lines.append("(none)")

    lines += ["", "CURRENT PLAN"]
    for d in trip["days"]:
        items = (trip.get("plan") or {}).get(d["day"]) or []
        if not items:
            lines.append(f"day {d['day']}: (nothing yet)")
            continue
        lines.append(f"day {d['day']}:")
        for it in items:
            lines.append(f"- {it['time']} | {it['label']} | {it['location']} | {it['icon']}")

    lines += ["", "DISCUSSION"]
    for m in messages:
        text = " ".join(str(m["text"]).split())
        lines.append(f"{m['sender']}: {text}")
    return "\n".join(lines)


def dump_answer(gold: dict) -> str:
    return json.dumps(gold, ensure_ascii=False, separators=(",", ":"))


def to_gemini_example(user_prompt: str, answer: str) -> dict:
    """One line of a Vertex AI supervised-tuning JSONL file."""
    return {
        "systemInstruction": {"role": "system", "parts": [{"text": SYSTEM_PROMPT}]},
        "contents": [
            {"role": "user", "parts": [{"text": user_prompt}]},
            {"role": "model", "parts": [{"text": answer}]},
        ],
    }
