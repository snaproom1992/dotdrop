#!/usr/bin/env node
// Web の /*ENGINE*/ から、物理突き合わせ用の正解 JSON を出す。
// 使い方: リポジトリルートで  node ios/tools/dump-fixtures.js
//
// 台の種（boardSeed）とはなす瞬間のブレなし（exact）に加え、
// Math.random を一時的にシード付きに差し替えて、結果を再現可能にする。
// 釘配置も JSON に含め、Swift 側が同じ台で物理だけを比較できるようにする。

const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '../..');
const htmlPath = path.join(root, 'index.html');
const outPath = path.join(root, 'ios/DotDropEngine/Tests/Fixtures/shots.json');

const html = fs.readFileSync(htmlPath, 'utf8');
const from = html.indexOf('/*ENGINE*/'), to = html.indexOf('/*END*/');
if (from < 0 || to < 0) {
  console.error('index.html に /*ENGINE*/ 〜 /*END*/ が見つからない');
  process.exit(1);
}
const engineSrc = html.slice(from, to);

const num = (name, fallback) => {
  const m = html.match(new RegExp('\\b' + name + '\\s*=\\s*(\\d+)'));
  return m ? +m[1] : fallback;
};
const MAX_PULL = num('MAX_PULL', 130), LEVELS = num('LEVELS', 5);

const {
  E, applyConf, setLayout, pickGold, launch, launchVelocity, stepPhysics, seeded
} = new Function(
  engineSrc +
  '\nreturn {E, applyConf, setLayout, pickGold, launch, launchVelocity, stepPhysics, seeded};'
)();

function withPlaySeed(seed, fn) {
  const rng = seeded(seed | 0);
  const orig = Math.random;
  Math.random = rng;
  try { return fn(); } finally { Math.random = orig; }
}

function shootExact({ boardSeed, layout, stage, fever, angleDeg, level, playSeed }) {
  return withPlaySeed(playSeed, () => {
    applyConf();
    E.boardSeed = boardSeed;
    E.stage = stage;
    E.fever = fever;
    E.convHold = false;
    E.conveyor = 0;
    E.time = 0;
    setLayout(layout, false);
    pickGold();

    const pegs = E.pegs.map(p => ({
      x: p.x, y: p.y, kind: p.kind
    }));

    const a = angleDeg * Math.PI / 180;
    const pull = level / LEVELS * MAX_PULL;
    const [vx, vy] = launchVelocity(Math.cos(a) * pull, Math.sin(a) * pull, true);
    launch(vx, vy);

    const step = 1 / 360;
    let t = 0, done = false;
    const kinds = {};
    E.hooks.shotEnd = () => { done = true; };
    E.hooks.hit = (p, b, n, force, kind) => { kinds[kind] = (kinds[kind] || 0) + 1; };
    E.hooks.land = () => {};
    E.hooks.release = () => {};
    E.hooks.perfect = () => {};

    while (!done && t < 40) {
      stepPhysics(step);
      t += step;
    }
    return {
      pegs,
      hitCount: E.hitCount,
      shotPay: E.shotPay,
      shotScore: E.shotScore || 0,
      kinds,
      stuck: !done,
      vx, vy,
      duration: t
    };
  });
}

const cases = [
  { id: 's1-layout0-up-lv3', boardSeed: 1, layout: 0, stage: 0, fever: false, angleDeg: 90, level: 3, playSeed: 1001 },
  { id: 's1-layout0-left-lv5', boardSeed: 1, layout: 0, stage: 0, fever: false, angleDeg: 50, level: 5, playSeed: 1002 },
  { id: 's1-layout1-up-lv4', boardSeed: 7, layout: 1, stage: 0, fever: false, angleDeg: 90, level: 4, playSeed: 1003 },
  { id: 's3-layout0-up-lv3', boardSeed: 3, layout: 0, stage: 2, fever: false, angleDeg: 90, level: 3, playSeed: 1004 },
  { id: 'fever-layout0-up-lv3', boardSeed: 1, layout: 0, stage: 0, fever: true, angleDeg: 90, level: 3, playSeed: 1005 },
];

const shots = cases.map(c => {
  const r = shootExact(c);
  return {
    id: c.id,
    boardSeed: c.boardSeed,
    layout: c.layout,
    stage: c.stage,
    fever: c.fever,
    angleDeg: c.angleDeg,
    level: c.level,
    playSeed: c.playSeed,
    exact: true,
    step: 1 / 360,
    maxTime: 40,
    launch: { vx: r.vx, vy: r.vy },
    pegs: r.pegs,
    expected: {
      hitCount: r.hitCount,
      shotPay: r.shotPay,
      shotScore: r.shotScore,
      kinds: r.kinds,
      stuck: r.stuck
    },
    meta: { duration: Number(r.duration.toFixed(4)), pegCount: r.pegs.length }
  };
});

const seq = seeded(42);
const seededSample42 = Array.from({ length: 8 }, () => seq());

const out = {
  version: 2,
  note: 'Generated from index.html ENGINE by ios/tools/dump-fixtures.js. Math.random replaced with seeded(playSeed). Pegs snapshotted after setLayout+pickGold.',
  generatedAt: new Date().toISOString(),
  maxPull: MAX_PULL,
  levels: LEVELS,
  seededSample42,
  shots
};

fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, JSON.stringify(out, null, 2) + '\n');
console.log('wrote', path.relative(root, outPath));
for (const s of shots) {
  console.log(`  ${s.id} pegs=${s.meta.pegCount} hits=${s.expected.hitCount} pay=${s.expected.shotPay} score=${s.expected.shotScore}`);
}
