const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1280, height: 820 } });
  const errs = []; p.on('pageerror', e => errs.push(e.message)); p.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
  await p.goto('file://' + process.cwd() + '/voodoocombo-teaser.html');
  for (const [ms, name] of [[3400, 'a'], [5300, 'b'], [6300, 'c'], [8200, 'd']]) {
    await p.waitForTimeout(ms - (name === 'a' ? 0 : [3400, 5300, 6300, 8200][['a','b','c','d'].indexOf(name) - 1]));
    await p.screenshot({ path: `shot-${name}.jpg`, type: 'jpeg', quality: 80 });
  }
  console.log(errs.length ? errs.join('\n') : 'no errors'); await b.close();
})();
