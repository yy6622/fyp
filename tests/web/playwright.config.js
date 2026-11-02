// Playwright config for the admin / insurance-partner console tests.
// Run from the project root (with the Firebase emulators running):
//   npx playwright test -c tests/web
const { defineConfig } = require("@playwright/test");
const path = require("path");

module.exports = defineConfig({
  testDir: __dirname,
  testMatch: /.*\.spec\.js/,
  timeout: 60_000,
  workers: 1,
  reporter: [
    ["list"],
    ["junit", { outputFile: path.join(__dirname, "..", "..", "test_results", "web-junit.xml") }],
  ],
  use: {
    baseURL: "http://127.0.0.1:5500",
    acceptDownloads: true,
    screenshot: "only-on-failure",
  },
  outputDir: path.join(__dirname, "..", "..", "test_results", "web-artifacts"),
  webServer: {
    command: "node tests/web/static-server.js",
    url: "http://127.0.0.1:5500/admin/login.html",
    cwd: path.join(__dirname, "..", ".."),
    reuseExistingServer: true,
  },
});
