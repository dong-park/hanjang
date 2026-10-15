// 휴대폰·맥 브라우저 클라이언트 에뮬레이션(Playwright). 사용: node n5_phones.cjs 설정.json
// 설정: {url, outdir, durationSec, shotEvery, clients:[{id, kind:"webkit"|"chromium", args:[...]}]}
// 제어 파일(outdir/ctl-ID-close | ctl-ID-open | ctl-ID-shot)로 탭을 강제로 닫거나 다시 열거나 캡처한다. outdir/STOP 이 생기면 끝낸다.
const fs = require("fs"), path = require("path");
const pw = require("/Users/donghwan/.npm/_npx/705bc6b22212b352/node_modules/playwright");
const cfg = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const t0 = Date.now();
const rel = () => ((Date.now() - t0) / 1000).toFixed(2);
const out = cfg.outdir; fs.mkdirSync(out, { recursive: true });
const state = {};
const L = (c, m) => fs.appendFileSync(path.join(out, "console-" + c.id + ".log"), (Date.now() / 1000).toFixed(3) + " +" + rel() + " " + m + "\n");
async function openPage(c) {
  const s = state[c.id];
  const dev = c.kind === "webkit" ? pw.devices["iPhone 13 landscape"] : { viewport: { width: 1280, height: 720 } };
  s.ctx = await s.browser.newContext({ ...dev });
  const page = await s.ctx.newPage();
  s.page = page; s.n = (s.n || 0) + 1;
  page.on("console", (m) => L(c, m.type() + " " + m.text()));
  page.on("pageerror", (e) => L(c, "PAGEERROR " + e.message));
  await page.route((u) => u.pathname === "/" || u.pathname.endsWith("/index.html"), async (route) => {
    const r = await route.fetch();
    let body = await r.text();
    body = body.replace('"args":[]', '"args":' + JSON.stringify(["--", ...c.args]));
    await route.fulfill({ response: r, body });
  });
  await page.goto(cfg.url, { waitUntil: "load" });
  L(c, "OPENED #" + s.n);
}
async function shot(c, label) {
  const s = state[c.id];
  if (!s.page || s.page.isClosed()) return;
  try { await s.page.screenshot({ path: path.join(out, c.id + "-" + label + ".png") }); } catch (e) {}
}
(async () => {
  for (const c of cfg.clients) {
    state[c.id] = { browser: await (c.kind === "webkit" ? pw.webkit : pw.chromium).launch() };
    await openPage(c);
  }
  let k = 0, last = 0;
  while ((Date.now() - t0) / 1000 < cfg.durationSec && !fs.existsSync(path.join(out, "STOP"))) {
    await new Promise((r) => setTimeout(r, 400));
    for (const c of cfg.clients) {
      const cl = path.join(out, "ctl-" + c.id + "-close"), op = path.join(out, "ctl-" + c.id + "-open"), sh = path.join(out, "ctl-" + c.id + "-shot");
      if (fs.existsSync(cl)) { fs.unlinkSync(cl); const s = state[c.id]; L(c, "TAB_CLOSE_CMD"); await s.page.close(); await s.ctx.close(); L(c, "TAB_CLOSED"); }
      if (fs.existsSync(op)) { fs.unlinkSync(op); await openPage(c); }
      if (fs.existsSync(sh)) { const lab = fs.readFileSync(sh, "utf8").trim() || "shot"; fs.unlinkSync(sh); await shot(c, lab); }
    }
    if (cfg.shotEvery && (Date.now() - last) / 1000 >= cfg.shotEvery) { last = Date.now(); k++; for (const c of cfg.clients) await shot(c, "auto" + String(k).padStart(2, "0")); }
  }
  for (const c of cfg.clients) { await shot(c, "final"); try { await state[c.id].browser.close(); } catch (e) {} }
  fs.appendFileSync(path.join(out, "phones.done"), "done\n");
  process.exit(0);
})();
