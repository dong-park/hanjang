const pw=require("/Users/donghwan/.npm/_npx/705bc6b22212b352/node_modules/playwright");const sleep=m=>new Promise(r=>setTimeout(r,m));
(async()=>{const br=await pw.webkit.launch();const ctx=await br.newContext({...pw.devices["iPhone 13 landscape"]});const page=await ctx.newPage();
await page.goto("http://127.0.0.1:8061/");await page.waitForSelector("canvas");await sleep(5000);
const r=await page.evaluate(()=>{const b=document.querySelector("canvas").getBoundingClientRect();return [b.x,b.y,b.width,b.height]});
const tap=async(gx,gy)=>{await page.bringToFront();await page.touchscreen.tap(r[0]+gx*r[2]/1152,r[1]+gy*r[3]/648);await sleep(800)};
for(let i=0;i<4;i++){await tap(576,71);if(await page.evaluate(()=>document.activeElement.tagName)==="INPUT")break}
await page.keyboard.type("가나",{delay:60});await sleep(300);await tap(670,147);await sleep(2500);
await page.screenshot({path:process.argv[2]});await br.close()})()
