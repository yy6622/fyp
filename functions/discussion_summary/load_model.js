// Loads model.json once per server instance (shared by summariseDiscussion and generateItinerary).
const fs = require("fs");
const path = require("path");

let cached = null;
function loadModel() {
  if (!cached) {
    const { TextModel } = require("./runtime");
    const params = JSON.parse(fs.readFileSync(path.join(__dirname, "model.json"), "utf8"));
    cached = { model: new TextModel(params), name: params.name || "" };
  }
  return cached;
}
module.exports = { loadModel };
