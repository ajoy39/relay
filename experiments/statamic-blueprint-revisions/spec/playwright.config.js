// testDir is this file's own directory: gate.sh passes --config "$S/playwright.config.js".
// The browser is the sandbox's preinstalled Chromium only if PW_CHROMIUM_PATH names it;
// otherwise Playwright's managed browser is used (`npx playwright install chromium`).
const chromium = process.env.PW_CHROMIUM_PATH;
module.exports = {
  testDir: __dirname,
  testMatch: 'gate.spec.js',
  timeout: 60000,
  workers: 1,
  outputDir: process.env.GATE_OUTPUT || '/tmp/gate-artifacts',
  use: { headless: true, ...(chromium ? { launchOptions: { executablePath: chromium } } : {}) },
  reporter: [['list'], ['json', { outputFile: process.env.GATE_RESULT || '/tmp/gate-result.json' }]],
};
