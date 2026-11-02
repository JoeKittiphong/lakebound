// Read-only live CORS probe. Never sends player data or writes to Sheets.
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require(process.env.LAKEBOUND_PLAYWRIGHT || 'playwright');
(async () => {
  const root = path.resolve(__dirname, '..');
  const endpoint = fs.readFileSync(path.join(root, 'online.cfg'), 'utf8').match(/url="([^"]+)"/)[1];
  const browser = await chromium.launchPersistentContext(path.join(root, 'exports/qa-web/install-profile'), {headless: true, channel: 'chrome'});
  try {
    const page = await browser.newPage();
    const failures = [];
    page.on('requestfailed', req => failures.push(req.failure().errorText));
    await page.goto('http://127.0.0.1:8062/index.manifest.json');
    const result = await page.evaluate(async url => {
      try {
        const response = await fetch(url + '?scope=all&limit=10');
        const data = await response.json();
        return {status: response.status, readable: true, schema: data.schema, error: data.error || null};
      } catch (error) { return {readable: false, error: String(error)}; }
    }, endpoint);
    await page.goto('http://127.0.0.1:8062/index.html');
    const cdp = await browser.newCDPSession(page);
    const manifest = await cdp.send('Page.getAppManifest');
    const installability = await cdp.send('Page.getInstallabilityErrors');
    console.log(JSON.stringify({result, failures, manifestErrors: manifest.errors, manifestName: manifest.manifest?.name, ...installability}, null, 2));
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
