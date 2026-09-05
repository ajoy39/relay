module.exports = {
  testDir: '/home/user/lab/spec',
  testMatch: 'gate.spec.js',
  timeout: 60000,
  workers: 1,
  outputDir: process.env.GATE_OUTPUT || '/tmp/gate-artifacts',
  use: { headless: true, launchOptions: { executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' } },
  reporter: [['list'], ['json', { outputFile: process.env.GATE_RESULT || '/tmp/gate-result.json' }]],
};
