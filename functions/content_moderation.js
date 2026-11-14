// Server-side content moderation (FR: auto-flag harmful community posts/reviews).
//
// Calls OpenAI's Moderation API from the Cloud Function, not from the client.
// Two reasons this has to run server-side rather than the app calling OpenAI
// directly: (1) OpenAI's /v1/moderations endpoint sends no CORS headers, so a
// browser (Flutter web) request to it is blocked outright by the browser
// before it even leaves the page; (2) it keeps the OpenAI key out of the
// client bundle instead of embedding it in compiled app code.
//
// The app's local word-list pre-check still runs on-device first (zero
// network, catches obvious profanity instantly); this function is the
// fallback classifier for everything that list doesn't catch. Like the
// client-side version it replaces, this fails open: any error, timeout, or
// missing key returns "not flagged" rather than blocking the user's post.
const { onCall } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const openAiApiKey = defineSecret("OPENAI_API_KEY");

const ENDPOINT = "https://api.openai.com/v1/moderations";
const MODEL = "omni-moderation-latest";

exports.moderateText = onCall({ secrets: [openAiApiKey] }, async (request) => {
  const text = typeof request.data?.text === "string" ? request.data.text.trim() : "";
  if (!text) return { flagged: false, reason: "" };

  const key = openAiApiKey.value();
  if (!key) {
    console.warn("[moderateText] no OPENAI_API_KEY secret configured — skipping remote check");
    return { flagged: false, reason: "" };
  }

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);
    let res;
    try {
      res = await fetch(ENDPOINT, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${key}`,
        },
        body: JSON.stringify({ model: MODEL, input: text }),
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timeout);
    }

    if (!res.ok) {
      console.warn(`[moderateText] OpenAI HTTP ${res.status}: ${await res.text()}`);
      return { flagged: false, reason: "" };
    }

    const decoded = await res.json();
    const result = (decoded.results || [])[0];
    if (!result || !result.flagged) return { flagged: false, reason: "" };

    const categories = result.categories || {};
    const hitCategories = Object.entries(categories)
      .filter(([, v]) => v === true)
      .map(([k]) => k.replace(/\//g, " / ").replace(/_/g, " "));
    const reason = hitCategories.length ? hitCategories.join(", ") : "Possible inappropriate content";
    return { flagged: true, reason };
  } catch (err) {
    console.warn(`[moderateText] error checking text: ${err}`);
    return { flagged: false, reason: "" };
  }
});
