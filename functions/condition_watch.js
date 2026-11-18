const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp, getApps } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

if (getApps().length === 0) initializeApp();

// Mirrors lib/models/day_plan_models.dart's word lists exactly (same
// comment appears in functions/optimise_engine.js) -- kept in sync by hand
// since there's no shared source between Dart and these Cloud Functions.
const OUTDOOR_WORDS = /(beach|hiking?|trail|park|garden|zoo|safari|mountain|lake|river|waterfall|outdoor|night market|street food|market|viewpoint|cruise|boat|island|cycling|bike|trekking|climbing|ski|surfing|rooftop|walking tour|picnic|sunrise|sunset|海滩|沙滩|爬山|登山|公园|花园|动物园|夜市|海岛|骑车|徒步|日出|日落)/i;
const INDOOR_WORDS = /(museum|gallery|mall|shopping (centre|center)|department store|supermarket|cinema|movie|theatre|theater|aquarium|planetarium|arcade|bowling|karaoke|spa|massage|indoor|casino|ice rink|restaurant|cafe|café|food court|博物馆|美术馆|商场|购物中心|百货|电影院|水族馆|按摩|室内|咖啡|餐厅)/i;
const isOutdoorLabel = (label) => OUTDOOR_WORDS.test(String(label || "")) && !INDOOR_WORDS.test(String(label || ""));

function toMin(hhmm) {
  const m = /^(\d{1,2}):(\d{2})$/.exec(String(hhmm || "").trim());
  return m ? Number(m[1]) * 60 + Number(m[2]) : null;
}

// Same key already shipped inside the public client bundle
// (lib/config/secrets.dart's googleRoutesApiKey) -- this project keeps all
// its third-party keys inline like this, so this mirrors existing practice
// rather than introducing a new pattern.
const GOOGLE_ROUTES_API_KEY = "AIzaSyDeaepe6JYvJDx2hdb9xSmdZe1VmzQa1B4";
// Generic client identifier for Nominatim's usage policy -- deliberately
// without a personal contact address (unlike the client app's own copy of
// this header in places_api_service.dart).
const NOMINATIM_USER_AGENT = "VoyaTravelApp/1.0 (student FYP project)";

// Mirrors lib/services/places_api_service.dart's geocode() (same provider)
// so results line up with what the app itself would resolve a location
// string to.
async function geocode(query) {
  const trimmed = String(query || "").trim();
  if (!trimmed) return null;
  try {
    const url = `https://nominatim.openstreetmap.org/search?${new URLSearchParams({
      q: trimmed, format: "json", limit: "1",
    })}`;
    const res = await fetch(url, { headers: { "User-Agent": NOMINATIM_USER_AGENT } });
    if (!res.ok) return null;
    const list = await res.json();
    const hit = Array.isArray(list) ? list[0] : null;
    const lat = hit ? Number(hit.lat) : NaN;
    const lon = hit ? Number(hit.lon) : NaN;
    return Number.isFinite(lat) && Number.isFinite(lon) ? { lat, lon } : null;
  } catch (_) {
    return null;
  }
}

// Mirrors lib/services/weather_service.dart's hourlyRainWindows data source
// (Open-Meteo, no API key needed) -- just reads the single hour bucket that
// covers the activity's scheduled time instead of building full windows.
async function weatherCodeAt(lat, lon, dateStr, hour) {
  try {
    const url = `https://api.open-meteo.com/v1/forecast?${new URLSearchParams({
      latitude: String(lat), longitude: String(lon), hourly: "precipitation_probability,weathercode",
      start_date: dateStr, end_date: dateStr, timezone: "auto",
    })}`;
    const res = await fetch(url);
    if (!res.ok) return null;
    const body = await res.json();
    const codes = body && body.hourly && body.hourly.weathercode;
    const probs = body && body.hourly && body.hourly.precipitation_probability;
    if (!Array.isArray(codes)) return null;
    return { code: codes[hour] ?? null, prob: Array.isArray(probs) ? (probs[hour] ?? null) : null };
  } catch (_) {
    return null;
  }
}

// Same formula as lib/services/traffic_service.dart's TrafficRoute.isCongested.
async function trafficBetween(from, to) {
  try {
    const res = await fetch("https://routes.googleapis.com/directions/v2:computeRoutes", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": GOOGLE_ROUTES_API_KEY,
        "X-Goog-FieldMask": "routes.duration,routes.staticDuration",
      },
      body: JSON.stringify({
        origin: { location: { latLng: { latitude: from.lat, longitude: from.lon } } },
        destination: { location: { latLng: { latitude: to.lat, longitude: to.lon } } },
        travelMode: "DRIVE",
        routingPreference: "TRAFFIC_AWARE",
      }),
    });
    if (!res.ok) return null;
    const body = await res.json();
    const route = body.routes && body.routes[0];
    if (!route) return null;
    const actual = Number(String(route.duration || "0s").replace("s", ""));
    const typical = Number(String(route.staticDuration || "0s").replace("s", ""));
    if (!actual || !typical) return null;
    const extra = actual - typical;
    const isCongested = extra >= 600 && actual >= typical * 1.3;
    return { isCongested, extraMinutes: Math.max(1, Math.round(extra / 60)) };
  } catch (_) {
    return null;
  }
}

/// Checks every ongoing trip's *today* for any activity starting in the
/// next 2 hours, re-checking weather (for a confidently-outdoor activity)
/// and traffic (the leg from the item right before it) -- same signals and
/// thresholds the app already uses in live_conditions_card.dart /
/// optimise_engine.js, just re-run here every 30 minutes instead of once
/// when the person happens to have the page open. Sends a real push (via
/// FCM, to every member's stored device tokens) plus the same in-app
/// notification every other alert in this app uses, the first time a given
/// activity trips either check on a given day -- not on every run, so
/// leaving the condition unresolved for 2 hours doesn't mean 4 repeats of
/// the same alert.
///
/// Known simplification: compares against this function's own run-time
/// clock with no per-trip timezone conversion -- there is nowhere in this
/// app's data model that records a trip's destination timezone, so this
/// matches the same assumption the rest of the app already makes (e.g.
/// "today" on the Home screen is the *viewer's* device date, not the
/// destination's).
async function runConditionWatch() {
  const db = getFirestore();
  const now = new Date();
  const nowMinutes = now.getHours() * 60 + now.getMinutes();
  const todayStr = now.toISOString().slice(0, 10);
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  const tripsSnap = await db.collection("trips").get();
  const messaging = getMessaging();

  for (const tripDoc of tripsSnap.docs) {
    const trip = tripDoc.data();
    const start = trip.startDate && trip.startDate.toDate ? trip.startDate.toDate() : null;
    const end = trip.endDate && trip.endDate.toDate ? trip.endDate.toDate() : null;
    if (!start || !end) continue;
    const startDay = new Date(start.getFullYear(), start.getMonth(), start.getDate());
    const endDay = new Date(end.getFullYear(), end.getMonth(), end.getDate());
    if (todayStart < startDay || todayStart > endDay) continue; // trip isn't happening today

    const dayNumber = Math.round((todayStart - startDay) / 86400000) + 1;
    const daysRaw = trip.days || {};
    const dayKeys = Object.keys(daysRaw).sort((a, b) => Number(a) - Number(b));
    const dayKey = dayKeys[dayNumber - 1];
    const day = dayKey ? daysRaw[dayKey] : null;
    if (!day || !day.items) continue;

    const items = Object.entries(day.items)
      .map(([id, it]) => ({ id, label: String(it.label || ""), location: String(it.location || ""), time: String(it.time || "") }))
      .filter((it) => it.label && it.time)
      .sort((a, b) => (toMin(a.time) ?? 0) - (toMin(b.time) ?? 0));

    for (let i = 0; i < items.length; i++) {
      const it = items[i];
      const t = toMin(it.time);
      if (t == null) continue;
      const minutesUntil = t - nowMinutes;
      if (minutesUntil < 0 || minutesUntil > 120) continue; // only the next 2 hours

      const alertRef = tripDoc.ref.collection("conditionAlerts").doc(`${todayStr}_${it.id}`);
      // eslint-disable-next-line no-await-in-loop
      const already = await alertRef.get();
      if (already.exists) continue; // already alerted for this activity today

      let reason = null;

      if (it.location && isOutdoorLabel(it.label)) {
        // eslint-disable-next-line no-await-in-loop
        const geo = await geocode(it.location) || await geocode(trip.destination || "");
        if (geo) {
          // eslint-disable-next-line no-await-in-loop
          const w = await weatherCodeAt(geo.lat, geo.lon, todayStr, Math.floor(t / 60));
          const disruptive = w && typeof w.code === "number" && w.code >= 51 && (w.prob == null || w.prob >= 40);
          if (disruptive) reason = `Rain is likely around ${it.time} for your outdoor plan "${it.label}".`;
        }
      }

      if (!reason && i > 0 && it.location && items[i - 1].location) {
        // eslint-disable-next-line no-await-in-loop
        const [fromGeo, toGeo] = await Promise.all([geocode(items[i - 1].location), geocode(it.location)]);
        if (fromGeo && toGeo) {
          // eslint-disable-next-line no-await-in-loop
          const route = await trafficBetween(fromGeo, toGeo);
          if (route && route.isCongested) {
            reason = `Traffic to "${it.label}" is running ~${route.extraMinutes} min over usual right now.`;
          }
        }
      }

      if (!reason) continue;

      // eslint-disable-next-line no-await-in-loop
      await alertRef.set({ itemId: it.id, label: it.label, reason, createdAt: new Date() });

      const memberIds = Array.isArray(trip.memberIds) ? trip.memberIds.slice(0, 10) : [];
      if (!memberIds.length) continue;

      // eslint-disable-next-line no-await-in-loop
      await Promise.all(memberIds.map((uid) =>
        db.collection("users").doc(uid).collection("notifications").add({
          type: "condition_alert",
          title: "Conditions have changed",
          body: reason,
          tripId: tripDoc.id,
          read: false,
          createdAt: new Date(),
        })));

      // eslint-disable-next-line no-await-in-loop
      const usersSnap = await db.collection("users").where("__name__", "in", memberIds).get();
      const tokens = [];
      for (const u of usersSnap.docs) {
        const t2 = u.data().fcmTokens;
        if (Array.isArray(t2)) tokens.push(...t2.filter((x) => typeof x === "string" && x));
      }
      if (tokens.length) {
        // eslint-disable-next-line no-await-in-loop
        await messaging.sendEachForMulticast({
          tokens,
          notification: { title: "Conditions have changed", body: reason },
          data: { type: "condition_alert", tripId: tripDoc.id, itemId: it.id },
        }).catch((err) => console.error("conditionWatch push failed", err));
      }
    }
  }
}

exports.conditionWatch = onSchedule("every 30 minutes", runConditionWatch);
exports.runConditionWatch = runConditionWatch;
