// Minimal static file server for admin_web/ (no extra dependencies).
// Used by playwright.config.js; serves http://127.0.0.1:5500/admin/... and /partner/...
const http = require("http");
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..", "..", "admin_web");
const port = Number(process.env.WEB_PORT || 5500);
const types = {
  ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".css": "text/css",
  ".png": "image/png", ".jpg": "image/jpeg", ".svg": "image/svg+xml", ".json": "application/json", ".ico": "image/x-icon",
};

http.createServer((req, res) => {
  const urlPath = decodeURIComponent(new URL(req.url, "http://x").pathname);
  let file = path.normalize(path.join(root, urlPath));
  if (!file.startsWith(root)) { res.writeHead(403); res.end(); return; }
  if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, "index.html");
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end("Not found"); return; }
    res.writeHead(200, { "Content-Type": types[path.extname(file)] || "application/octet-stream", "Cache-Control": "no-store" });
    res.end(data);
  });
}).listen(port, "127.0.0.1", () => console.log(`admin_web served on http://127.0.0.1:${port}`));
