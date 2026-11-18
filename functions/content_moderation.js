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
