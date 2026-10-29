// usage: node shot.js out.png "eye" "at" [w h fov]
const http = require('http'), fs = require('fs'), path = require('path');
const { chromium } = require('playwright');
const root = __dirname; // serves index.html, scene.json and node_modules/three
const srv = http.createServer((req, res) => { const f = path.join(root, decodeURIComponent(req.url.split('?')[0])); 
  if (!fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, {'Content-Type': f.endsWith('.js')?'text/javascript':f.endsWith('.html')?'text/html':'application/json'}); fs.createReadStream(f).pipe(res); });
srv.listen(0, async () => {
  const port = srv.address().port; const shots = JSON.parse(process.argv[2]);
  const b = await chromium.launch({args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']}); 
  const page = await b.newPage({viewport:{width:1200,height:800}});
  page.on('console', m => { if (m.type()==='error') console.log('page:', m.text()); });
  page.on('pageerror', e => console.log('pageerror', e.message));
  for (const s of shots) {
    const w = s.w||1200, h=s.h||800; await page.setViewportSize({width:w,height:h});
    await page.goto(`http://localhost:${port}/index.html?eye=${s.eye}&at=${s.at}&w=${w}&h=${h}&fov=${s.fov||40}`);
    await page.waitForFunction('window.done===true', null, {timeout: 60000});
    await page.screenshot({path: s.out}); console.log('wrote', s.out);
  }
  await b.close(); srv.close();
});
