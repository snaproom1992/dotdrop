// デモ動画用の打ち方を、エンジンを回して探す。
//
//   node ios/tools/find-demo-shots.js        … 台の種を24通り試して、良いものを並べる
//   node ios/tools/find-demo-shots.js 12     … その種で角度と強さを細かく試す
//
// **実機（iPhone 16 Pro Max）と同じ寸法で回すこと。**
// 本家の台は高さ700・発射140 だが、アプリは HUD のぶん発射位置が下がり、
// 画面も縦に長いので、釘の行数も位置も違う。ここを合わせないと当たらない。
const fs = require('fs');
const html = fs.readFileSync('/home/user/dotdrop/index.html', 'utf8');
let engine = html.slice(html.indexOf('/*ENGINE*/'), html.indexOf('/*END*/'));
const LAUNCH_Y = 161.5, FIELD_TOP = 221.5, LH = 754.4;
const before = engine;
engine = engine.replace('const LAUNCH = {x: LW / 2, y: 140};', `const LAUNCH = {x: LW / 2, y: ${LAUNCH_Y}};`)
               .replace('const field = () => ({top: 200, bottom: E.LH - 135});',
                        `const field = () => ({top: ${FIELD_TOP}, bottom: E.LH - 135});`);
if (engine === before) { console.error('置き換えに失敗'); process.exit(1); }

const {E, setLayout, pickGold, launch, launchVelocity, stepPhysics} =
  new Function(engine + '\nreturn {E, setLayout, pickGold, launch, launchVelocity, stepPhysics};')();
E.LH = LH;

function shoot(angle, level) {
  let done = false; E.hooks.shotEnd = () => { done = true; };
  const a = angle * Math.PI / 180, p = level * 26 - 0.5;
  launch(...launchVelocity(Math.cos(a) * p, Math.sin(a) * p));
  let t = 0, mb = 1;
  while (!done && t < 40) { stepPhysics(1/360); t += 1/360; mb = Math.max(mb, E.balls.length); }
  return {pot: E.pot, mb, secs: t};
}
const med = a => a.slice().sort((x,y)=>x-y)[a.length>>1];
function eval_(angle, level, n) {
  const pots=[], bs=[], ss=[];
  for (let i=0;i<n;i++){ E.conveyor=Math.random()*1000; pickGold(); const r=shoot(angle,level);
                         pots.push(r.pot); bs.push(r.mb); ss.push(r.secs); }
  return {angle, level, pot: med(pots), balls: med(bs), secs: +med(ss).toFixed(1),
          over100: pots.filter(v=>v>=100).length/n, six: bs.filter(v=>v>=6).length/n};
}

const mode = process.argv[2] || 'seeds';
if (mode === 'seeds') {
  const out = [];
  for (let seed = 1; seed <= 24; seed++) {
    E.boardSeed = seed; E.stage = 0; E.fever = false; setLayout(0, false);
    let best = null;
    for (let angle = 35; angle <= 145; angle += 10)
      for (let level = 3; level <= 5; level++) {
        const r = eval_(angle, level, 12);
        const v = r.pot + r.balls * 18;
        if (!best || v > best.v) best = {...r, v};
      }
    out.push({seed, ...best}); process.stderr.write('.');
  }
  process.stderr.write('\n');
  out.sort((a,b)=>b.v-a.v);
  console.log('実機と同じ寸法（LH754 / 発射161.5 / 釘の上端221.5）');
  for (const s of out.slice(0,8))
    console.log(`種${String(s.seed).padStart(2)}  ${s.angle}° 強さ${s.level}  ポイント${s.pot}  最大玉${s.balls}  100点超え${(s.over100*100)|0}%  6個以上${(s.six*100)|0}%`);
} else {
  const seed = +mode;
  E.boardSeed = seed; E.stage = 0; E.fever = false; setLayout(0, false);
  const rows = [];
  for (let angle = 55; angle <= 135; angle += 4)
    for (let level = 3; level <= 5; level++) rows.push(eval_(angle, level, 40));
  rows.sort((a,b)=>(b.pot+b.balls*18)-(a.pot+a.balls*18));
  console.log(`種${seed}`);
  console.log('角度 強さ ポイント 最大玉 100点超え 6個以上  秒');
  for (const r of rows.slice(0,12))
    console.log(String(r.angle).padStart(3), String(r.level).padStart(4), String(r.pot).padStart(7),
                String(r.balls).padStart(6), String(((r.over100*100)|0)+'%').padStart(9),
                String(((r.six*100)|0)+'%').padStart(7), String(r.secs).padStart(5));
}
