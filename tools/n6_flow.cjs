// n6 터널 경유 폰(WebKit iPhone 13 가로 에뮬레이션) 흐름 캡처. 사용: node n6_flow.cjs 터널주소 출력폴더
const fs = require("fs"), path = require("path"), cp = require("child_process");
const pw = require("/Users/donghwan/.npm/_npx/705bc6b22212b352/node_modules/playwright");
const B = process.argv[2], out = process.argv[3]; fs.mkdirSync(out, { recursive: true });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const log = (m) => console.log(m);
async function phone(browser, url, name) {
  const ctx = await browser.newContext({ ...pw.devices["iPhone 13 landscape"], ignoreHTTPSErrors: true });
  const page = await ctx.newPage();
  page.on("pageerror", (e) => log(name + " PAGEERROR " + e.message));
  page.on("console", (m) => { if (m.type() === "error") log(name + " console.error " + m.text()); });
  await page.goto(url, { waitUntil: "load" });
  await page.waitForSelector("canvas", { timeout: 90000 });
  await sleep(6000);
  const p = { page, ctx, name,
    async tap(gx, gy) { await page.bringToFront(); const r = await page.evaluate(() => { const b = document.querySelector("canvas").getBoundingClientRect(); return [b.x, b.y, b.width, b.height]; });
      await page.touchscreen.tap(r[0] + gx * r[2] / 1152, r[1] + gy * r[3] / 648); await sleep(700); },
    async tapInput(gx, gy) { for (let i = 0; i < 4; i++) { await this.tap(gx, gy); if (await page.evaluate(() => document.activeElement.tagName) === "INPUT") return; } log(name + " 입력칸 포커스 실패"); },
    async shot(l) { await page.screenshot({ path: path.join(out, name + "-" + l + ".png") }); },
    async type(t) { await page.keyboard.type(t, { delay: 60 }); await sleep(300); } };
  return p;
}
async function api(p, body) { const r = await fetch(B + p, body ? { method: "POST", body: JSON.stringify(body) } : {}); return r.json(); }
(async () => {
  const br = await pw.webkit.launch();
  const A = await phone(br, B + "/", "A");
  await A.tapInput(396 + 180, 44 + 27); await A.type("가나"); await A.shot("02-title-name");
  await A.tap(396 + 86, 116 + 31);                    // 방 만들기
  await sleep(1500); await A.shot("03-rooms-empty");
  await A.tapInput(44 + 150, 126 + 28); await A.type("0000"); await A.tap(358 + 92, 126 + 28); await sleep(1000);
  await A.shot("04-fail-notfound");                   // 틀린 코드
  const before = await api("/api/rooms");
  await A.tap(358 + 92, 252 + 28);                    // 만들기 (이름은 "가나의 방")
  await sleep(1500); await A.shot("05-created");
  const rooms = await api("/api/rooms"); const mine = rooms.find((r) => r.name === "가나의 방");
  log("created code=" + (mine && mine.code) + " before=" + before.length);
  await A.tap(486 + 95, 396 + 31); await sleep(2500); await A.shot("06-lobby-owner");
  // 두 번째 폰: 공유 링크로 입장
  const Bp = await phone(br, B + "/?room=" + mine.code, "B");
  await Bp.tapInput(396 + 180, 44 + 27); await Bp.type("다라"); await Bp.tap(584 + 86, 116 + 31);
  await sleep(3000); await Bp.shot("07-lobby-by-link"); await A.shot("08-lobby-owner-two");
  // 세 번째 폰: 목록에서 고르기 + 비공개 방
  const priv = await api("/api/rooms", { name: "비밀방", public: false });
  const C = await phone(br, B + "/", "C");
  await C.tapInput(396 + 180, 44 + 27); await C.type("마바"); await C.tap(584 + 86, 116 + 31);
  await sleep(2500); await C.shot("09-list-two-rooms");   // 공개 방(가나의 방)만, 비밀방 없음
  log("list=" + JSON.stringify((await api("/api/rooms")).map((r) => r.name)));
  // A가 시작 -> 판 중
  await A.tap(476 + 100, 470 + 32); await sleep(4000); await A.shot("10-table");
  await C.page.waitForTimeout(3500); await C.shot("11-list-playing-disabled");
  log("list after start=" + JSON.stringify(await api("/api/rooms")));
  // 비공개 방은 코드로
  await C.tapInput(44 + 150, 126 + 28); await C.type(priv.code); await C.tap(358 + 92, 126 + 28); await sleep(3500); await C.shot("12-lobby-private-by-code");
  // 재접속 토큰이 브라우저에 저장됐는가 (user:// = IndexedDB /userfs)
  const tok = await A.page.evaluate(() => new Promise((res) => { const rq = indexedDB.open("/userfs"); rq.onerror = () => res("no-db");
    rq.onsuccess = () => { const db = rq.result; if (!db.objectStoreNames.contains("FILE_DATA")) return res("no-store"); const tx = db.transaction("FILE_DATA").objectStore("FILE_DATA").getAllKeys(); tx.onsuccess = () => res(JSON.stringify(tx.result)); }; }));
  log("A indexeddb keys=" + tok);
  // 서버 재시작 -> 대기실에 있던 B 가 첫 화면과 문구를 본다
  cp.execSync(path.join(__dirname, "../relay/deploy/hanjang.sh") + " restart");
  await sleep(9000); await Bp.shot("13-after-restart"); await A.shot("14-after-restart-A");
  await br.close(); log("DONE");
})().catch((e) => { console.error("ERR", e); process.exit(1); });
