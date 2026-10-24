// Runs the JavaScript summariser (the one deployed in the Cloud Function) on
// chats from a .jsonl file and prints the summaries as JSON lines.
// Used by test_parity.py:  node parity_runner.js <chats.jsonl>
const fs = require("fs");
const path = require("path");
const fnDir = path.join(__dirname, "..", "..", "functions", "discussion_summary");
const { TextModel } = require(path.join(fnDir, "runtime.js"));
const { summarise } = require(path.join(fnDir, "summariser.js"));

const model = new TextModel(JSON.parse(fs.readFileSync(path.join(fnDir, "model.json"), "utf8")));
const lines = fs.readFileSync(process.argv[2], "utf8").split("\n").filter((l) => l.trim());
for (const line of lines) {
  const c = JSON.parse(line);
  const msgs = c.messages.map((m) => ({ id: m.id, speaker: m.speaker, text: m.text }));
  process.stdout.write(JSON.stringify(summarise(msgs, model, c.members)) + "\n");
}
