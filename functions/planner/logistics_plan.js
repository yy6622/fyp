
const { normalize } = require("../discussion_summary/textproc");

const MONTHS = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];
const toMin = (t) => { const [h, m] = String(t).split(":").map(Number); return h * 60 + (m || 0); };
const toHHMM = (n) => `${String(Math.floor(n / 60)).padStart(2, "0")}:${String(n % 60).padStart(2, "0")}`;

function dayMonthOf(text) {
  const s = normalize(text);
  let m = /(\d{4})-(\d{1,2})-(\d{1,2})/.exec(s);
  if (m) return { d: +m[3], m: +m[2] };
  m = /(\d{1,2})\s*([a-z]{3})[a-z]*/.exec(s);
  if (m && MONTHS.includes(m[2])) return { d: +m[1], m: MONTHS.indexOf(m[2]) + 1 };
  m = /([a-z]{3})[a-z]*\s*(\d{1,2})(?![0-9])/.exec(s);
  if (m && MONTHS.includes(m[1])) return { d: +m[2], m: MONTHS.indexOf(m[1]) + 1 };
  m = /(\d{1,2})月(\d{1,2})/.exec(s);
  if (m) return { d: +m[2], m: +m[1] };
  return null;
}

function clockOf(text) {
  const s = normalize(text);
  let m = /t(\d{2}):(\d{2})/.exec(s);
  if (m) return `${m[1]}:${m[2]}`;
  m = /(\d{1,2}):(\d{2})\s*(am|pm)?/.exec(s) || /(\d{1,2})\s*(am|pm)/.exec(s);
  if (!m) return null;
  let h = +m[1];
  const ap = m[3] || (m[2] && /am|pm/.test(m[2]) ? m[2] : null);
  const min = m[2] && /^\d{2}$/.test(m[2]) ? m[2] : "00";
  if (ap === "pm" && h < 12) h += 12;
  if (ap === "am" && h === 12) h = 0;
  return h <= 23 ? `${String(h).padStart(2, "0")}:${min}` : null;
}

function tripDayOf(text, days) {
  const dm = dayMonthOf(text || "");
  if (!dm) return null;
  const hit = days.find((d) => {
    const x = dayMonthOf(d.date || "");
    return x && x.d === dm.d && x.m === dm.m;
  });
  return hit ? hit.day : null;
}

const flightName = (f) => [f.airline, f.flightNumber].filter(Boolean).join(" ").trim() || "Flight";

function tripLogistics({ flights = [], hotelStays = [], days = [], window = null, messages = [] }) {
  const n = days.length;
  const out = { window: { floor: window && window.floor, ceil: window && window.ceil }, fixed: [], checkIn: null, stays: [],
    flightsBooked: (flights || []).length > 0, notes: [] };

  // ---- flights
  const parsed = (flights || []).filter(Boolean).map((f) => {
    const depDay = tripDayOf(f.departureAtIso || f.dateTime, days);
    const depTime = clockOf(f.departureAtIso || f.dateTime || "");
    const arrDay = tripDayOf(f.arrivalAtIso || f.arrivalTime, days) || (f.arrivalTime ? null : depDay);
    const arrTime = clockOf(f.arrivalAtIso || f.arrivalTime || "");
    return { f, depDay, depTime, arrDay, arrTime, route: f.routeCode || "" };
  }).filter((x) => x.depDay || x.arrDay);
  parsed.sort((a, b) => ((a.depDay || a.arrDay) - (b.depDay || b.arrDay)) || String(a.depTime).localeCompare(String(b.depTime)));
  const outbound = parsed[0];
  const home = parsed.length >= 2 ? parsed[parsed.length - 1] : null;
  if (outbound) {
    const day = outbound.arrDay || outbound.depDay;
    const time = outbound.arrTime || (outbound.depTime ? toHHMM(Math.min(toMin(outbound.depTime) + 180, 23 * 60)) : null);
    if (day && time) {
      out.fixed.push({ day, time, label: `${flightName(outbound.f)} lands`, kind: "flight", location: outbound.route });
      if (!out.window.floor) out.window.floor = { day, minMinutes: toMin(time) + 90 };
    }
  }
  if (home && home.depDay && home.depTime) {
    out.fixed.push({ day: home.depDay, time: home.depTime, label: `${flightName(home.f)} departs`, kind: "flight", location: home.route });
    if (!out.window.ceil) out.window.ceil = { day: home.depDay, maxMinutes: toMin(home.depTime) - 180 };
  }

  if (!parsed.length) {
    const { readDay, readTime } = require("../itinerary_engine");
    const ARRIVE = /(land|arrive|arrival|reach|到达|抵达|降落|落地|飞到|sampai|tiba|(点|:\d\d|am|pm)\s*(左右|多)?\s*(就)?到)/i;
    const LEAVE = /(fly back|flight back|flight home|return flight|depart|回程|回去的飞机|飞回|起飞|balik)/i;
    for (const m of messages) {
      const t = m.text || "";
      if (!/(flight|fly|plane|航班|飞机|机票|飞|kapal terbang)/i.test(t) || /[?？]\s*$/.test(t.trim())) continue;
      const time = /\d|点/.test(t) ? readTime(t) : null;
      if (!time || !/\d/.test(time)) continue;
      if (ARRIVE.test(t) && !out.window.floor) {
        const day = readDay(t, days) || 1;
        out.window.floor = { day, minMinutes: toMin(time) + 90 };
        out.fixed.push({ day, time, label: "Arrive (from the chat)", kind: "flight", location: "" });
      } else if (LEAVE.test(t) && !out.window.ceil) {
        const day = readDay(t, days) || n;
        out.window.ceil = { day, maxMinutes: toMin(time) - 180 };
        out.fixed.push({ day, time, label: "Flight home (from the chat)", kind: "flight", location: "" });
      }
    }
  }

  // ---- hotel stays
  for (const h of (hotelStays || []).filter(Boolean)) {
    const fromDay = tripDayOf(h.checkIn, days);
    const toDay = tripDayOf(h.checkOut, days);
    if (!fromDay && !toDay) continue;
    out.stays.push({ name: h.name || "Hotel", location: h.location || "", fromDay: fromDay || 1, toDay: toDay || n });
    if (fromDay) {
      const land = out.window.floor && out.window.floor.day === fromDay ? out.window.floor.minMinutes : 0;
      const t = Math.max(15 * 60, Math.ceil(land / 15) * 15);
      out.fixed.push({ day: fromDay, time: toHHMM(Math.min(t, 23 * 60)), label: `Check in · ${h.name || "hotel"}`, kind: "hotel", location: h.location || "" });
      if (!out.checkIn || fromDay < out.checkIn.day) out.checkIn = { day: fromDay, time: toHHMM(Math.min(t, 23 * 60)) };
    }
    if (toDay && toDay !== fromDay) {
      out.fixed.push({ day: toDay, time: "11:00", label: `Check out · ${h.name || "hotel"}`, kind: "hotel", location: h.location || "" });
    }
  }
  out.fixed.sort((a, b) => a.day - b.day || a.time.localeCompare(b.time));
  return out;
}

module.exports = { tripLogistics, tripDayOf, clockOf, dayMonthOf };
