const { chromium } = require('playwright');
const fs = require('fs');
const icons = require('./shared.js') // tool/vehicles: fuente de assets/vehicles (node render.js);
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' }).catch(() => chromium.launch());
  const p = await b.newPage({ deviceScaleFactor: 3, viewport: { width: 240, height: 160 } });
  for (const [name, svg] of Object.entries(icons)) {
    await p.setContent(`<html><body style="margin:0;background:transparent">${svg}</body></html>`);
    await p.locator('svg').screenshot({ path: `out/${name}.png`, omitBackground: true });
  }
  // hoja de contacto para revisar
  await p.setViewportSize({ width: 1240, height: 200 });
  await p.setContent(`<html><body style="margin:0;background:#E8F0FE;display:flex;gap:8px;padding:20px">${Object.values(icons).join('')}</body></html>`);
  await p.screenshot({ path: 'out/sheet.png' });
  await b.close();
})();
