// DOT DROP バランス確認用のシミュレーション
//
// 使い方: node balance.js （2分ほどかかる）
//
// index.html の /*ENGINE*/ 〜 /*END*/ だけを画面なしで動かして、次の3つを測る
//   1. ステージ別の玉の増減 … 1回打つと持ち玉がいくつ増える／減るか
//   2. 一番得な打ち方     … 角度と強さを総当たりして、一番増える打ち方を探す
//   3. 1ゲームの長さ       … 「適当に打つ人」と「うまい人」が何回で終わるか
//   4. チュートリアル      … 8つとも本当にクリアできるか
//
// 受け皿・玉数・ステージ・フィーバーなど、玉の増減に関わる数字を変えたら必ず実行する。
// 目標（CLAUDE.md のバランスの方針）
//   ・1ゲームは25〜35回くらいで終わる
//   ・ステージ1は気持ちよく増える
//   ・ステージ2以降は、平均すると1回あたり少しマイナス
//   ・同じ角度と強さを繰り返す「うまい人」でも、最後はちゃんと終わる

const fs = require('fs');
const html = fs.readFileSync(__dirname + '/index.html', 'utf8');
const from = html.indexOf('/*ENGINE*/'), to = html.indexOf('/*END*/');
if (from < 0 || to < 0) { console.error('index.html に /*ENGINE*/ 〜 /*END*/ が見つからない'); process.exit(1); }
const engine = html.slice(from, to);

// 引っ張りの強さは画面側の数字なので、index.html から読む
const num = (name, fallback) => {
  const m = html.match(new RegExp('\\b' + name + '\\s*=\\s*(\\d+)'));
  return m ? +m[1] : fallback;
};
const MAX_PULL = num('MAX_PULL', 130), LEVELS = num('LEVELS', 5);
const TRI_BONUS = 3;  // ▲を3つとも当てると +3玉

// エンジンは画面に触らないので、そのまま関数として読み込める。玉数やフィーバーの数字もここから取る
const {E, applyConf, START, COST, LAYOUTS, TRIS, MAX_BALLS, CONV_LEN, STAGE_B, SHOTS_PER_BOARD: PER_STAGE,
       FEVER_AT, FEVER_SHOTS, setLayout, pickGold, launch, launchVelocity, stepPhysics} =
  new Function(engine + '\nreturn {E, applyConf, START, COST, LAYOUTS, TRIS, MAX_BALLS, CONV_LEN, STAGE_B, SHOTS_PER_BOARD, FEVER_AT, FEVER_SHOTS, setLayout, pickGold, launch, launchVelocity, stepPhysics};')();

const LAYOUT_NAMES = ['千鳥', '同心円', '波', 'ランダム'];
const STAGES = STAGE_B.length;

// ---------- 1回打つ ----------
// angle は飛ぶ方向（0=左へ水平 / 90=真上 / 180=右へ水平）、level は引きの強さ 1〜5
function shoot(angle, level) {
  let done = false;
  const pays = [];                                   // 受け皿ごとの玉の増減（当たった順）
  const hits = {}, mults = [];
  E.hooks.hit = (p, b, n, force, kind) => { hits[kind] = (hits[kind] || 0) + 1; };
  E.hooks.land = (b, v) => { pays.push(v); if (b.pts > 0) mults.push(b.mult); };
  E.hooks.shotEnd = () => { done = true; };
  const a = angle * Math.PI / 180, p = level / LEVELS * MAX_PULL;
  launch(...launchVelocity(Math.cos(a) * p, Math.sin(a) * p));
  let t = 0, maxBalls = 1;
  const step = 1 / 360;                              // 画面と同じ刻み（1フレームを6回に分けている）
  while (!done && t < 40) { stepPhysics(step); t += step; maxBalls = Math.max(maxBalls, E.balls.length); }
  const tris = E.pegs.filter(q => q.kind === 'tri');
  const bonus = TRIS > 0 && tris.length === TRIS && tris.every(q => q.triHit) ? TRI_BONUS : 0;
  if (bonus) pays.push(bonus);
  return {pays, balls: E.shotPay + bonus, score: E.shotScore || 0, hits: E.hitCount, kinds: hits, pot: E.pot,
          maxMult: mults.length ? Math.max(...mults) : 0, maxBalls, stuck: !done};
}
const randomShot = () => [5 + Math.random() * 170, 1 + (Math.random() * LEVELS | 0)];
const aim = s => s === 'random' ? randomShot() : [s.angle + (Math.random() - .5) * 6, s.level];

// 何回か打って平均を見る。net は「1回打つごとの持ち玉の増減」（打つのに1玉使う分を引いてある）
function measure(n, {stage = 0, layout = 0, fever = false, strat = 'random'} = {}) {
  E.stage = stage; E.fever = fever;
  setLayout(layout, false);
  let net = 0, score = 0, hits = 0, maxBalls = 0, stuck = 0;
  for (let i = 0; i < n; i++) {
    E.conveyor = Math.random() * CONV_LEN;           // 受け皿は流れているので、打つたびに位置が違う
    pickGold();
    const r = shoot(...aim(strat));
    net += r.balls - COST; score += r.score; hits += r.hits;
    maxBalls = Math.max(maxBalls, r.maxBalls); if (r.stuck) stuck++;
  }
  return {net: net / n, score: score / n, hits: hits / n, maxBalls, stuck};
}

// ---------- 表示のための小物 ----------
const sign = v => (Math.abs(v) < .005 ? '±' : v > 0 ? '+' : '−') + Math.abs(v).toFixed(2);
// 日本語は2文字分の幅で表示されるので、そのぶんを数えて右そろえにする
const wide = c => { const u = c.codePointAt(0); return u >= 0x3000 && u <= 0x9FFF || u >= 0xFF00 && u <= 0xFF60; };
const pad = (s, w) => {
  const width = [...String(s)].reduce((a, c) => a + (wide(c) ? 2 : 1), 0);
  return ' '.repeat(Math.max(0, w - width)) + s;
};
const median = arr => arr.slice().sort((a, b) => a - b)[arr.length >> 1];
const t0 = Date.now();
const elapsed = () => ((Date.now() - t0) / 1000).toFixed(0) + '秒';

console.log(`DOT DROP バランス確認`);
console.log(`持ち玉${START}スタート / ${PER_STAGE}回でステージが上がる / フィーバーは${FEVER_AT}ポイントで${FEVER_SHOTS}回 / 玉は最大${MAX_BALLS}`);

// ================= 1. ステージ別の玉の増減 =================
console.log(`\n1. ステージ別の玉の増減（適当に打った1回あたり。プラスなら持ち玉が増えていく）`);
console.log(`   ${pad('', 12)}${LAYOUT_NAMES.map(n => pad(n, 10)).join('')}${pad('平均', 10)}${pad('フィーバー中', 16)}`);
const stageNet = [];
let stuckTotal = 0;
for (let st = 0; st < STAGES; st++) {
  const row = [];
  for (let k = 0; k < LAYOUTS; k++) { const r = measure(400, {stage: st, layout: k}); row.push(r.net); stuckTotal += r.stuck; }
  const avg = row.reduce((a, b) => a + b) / row.length;
  let fev = 0;
  for (let k = 0; k < LAYOUTS; k++) {
    const r = measure(100, {stage: st, layout: k, fever: true});
    fev += r.net / LAYOUTS; stuckTotal += r.stuck;
  }
  stageNet.push(avg);
  const label = `ステージ${st + 1}` + (st === STAGES - 1 ? '〜' : '');
  console.log(`   ${pad(label, 12)}${row.map(v => pad(sign(v), 10)).join('')}${pad(sign(avg), 10)}${pad(sign(fev), 16)}`);
}
console.log(`   → ステージ1は ${sign(stageNet[0])}、ステージ2以降の平均は ${sign(stageNet.slice(1).reduce((a, b) => a + b) / (STAGES - 1))}`);
console.log(`     ${stageNet[0] > 0 ? 'ステージ1は増える。' : '⚠ ステージ1で増えていない。'}` +
            `${stageNet.slice(1).every(v => v < 0) ? 'ステージ2以降はどこも少しマイナス。' : '⚠ ステージ2以降にプラスのステージがある（終わらなくなる）。'}`);
if (stuckTotal) console.log(`   ⚠ 玉が落ちてこなかった回が ${stuckTotal} 回あった（どこかで挟まっている）`);
console.log(`   （${elapsed()}）`);

// ================= 2. 一番得な打ち方 =================
// 台の形は6回ごとに変わるので、4種類すべてを平均して「どの台でも得な打ち方」を探す
console.log(`\n2. 一番得な打ち方（角度と強さの総当たり。ステージ1、台4種類の平均）`);
const tryStrat = (strat, n) => {
  let net = 0, score = 0;
  for (let k = 0; k < LAYOUTS; k++) {
    const r = measure(n, {stage: 0, layout: k, strat});
    net += r.net / LAYOUTS; score += r.score / LAYOUTS;
  }
  return {...strat, net, score};
};
// 1回の増減はばらつきが大きいので、まず粗く全部試して、上位だけをもう一度多めに打ち直す
let found = [];
for (let lv = 1; lv <= LEVELS; lv++) for (let ang = 5; ang <= 175; ang += 10)
  found.push(tryStrat({angle: ang, level: lv}, 24));
found.sort((a, b) => b.net - a.net);
found = found.slice(0, 8).map(r => tryStrat(r, 200)).sort((a, b) => b.net - a.net);
console.log(`   ${pad('向き', 8)}${pad('強さ', 8)}${pad('玉の増減', 12)}${pad('スコア', 10)}`);
found.slice(0, 5).forEach(r =>
  console.log(`   ${pad(r.angle + '°', 8)}${pad(r.level, 8)}${pad(sign(r.net), 12)}${pad(r.score.toFixed(0), 10)}`));
console.log(`   （0°=左へ水平、90°=真上、180°=右へ水平）`);

// その打ち方をステージ別に見る。うまい人でも後半はマイナスになっていないと、ゲームが終わらない
const best = found[0];
console.log(`\n   一番得な打ち方（${best.angle}° 強さ${best.level}）をステージ別に見ると`);
const bestNet = [];
for (let st = 0; st < STAGES; st++) {
  let net = 0;
  for (let k = 0; k < LAYOUTS; k++) net += measure(100, {stage: st, layout: k, strat: best}).net / LAYOUTS;
  bestNet.push(net);
}
console.log(`   ${pad('', 12)}${bestNet.map((_, i) => pad(`ステージ${i + 1}`, 11)).join('')}`);
console.log(`   ${pad('玉の増減', 12)}${bestNet.map(v => pad(sign(v), 11)).join('')}`);
console.log(`     ${bestNet[STAGES - 1] < 0 ? '後半はマイナス。うまい人でも終わる。' : '⚠ 後半でも増えている。うまい人だと終わらない。'}`);
console.log(`   （${elapsed()}）`);

// ================= 3. 1ゲームの長さ =================
// 実際のゲームと同じ進み方：1回打つと1玉減る、6回でステージが上がる、
// ポイントが貯まるとフィーバー、持ち玉が0になったら終わり
function game(strat) {
  let money = START, gauge = 0, feverLeft = 0, shots = 0, board = 0, score = 0, peak = START;
  E.stage = 0; E.fever = false; E.boardSeed = null; setLayout(0, false);
  while (money >= COST && shots < 500) {
    money -= COST; shots++;
    E.conveyor = Math.random() * CONV_LEN;
    const r = shoot(...aim(strat));
    // 減る受け皿は、持っている以上には減らない（画面と同じ）
    for (const v of r.pays) money = v < 0 ? Math.max(0, money + v) : money + v;
    peak = Math.max(peak, money); score += r.score;
    if (!E.fever) gauge += r.pot;                    // ポイントが貯まるとフィーバー
    if (E.fever) { if (--feverLeft <= 0) { E.fever = false; gauge = 0; } }
    else if (gauge >= FEVER_AT) { E.fever = true; feverLeft = FEVER_SHOTS; }
    if (++board >= PER_STAGE) {
      board = 0; E.stage++;
      let next; do { next = Math.random() * LAYOUTS | 0; } while (next === E.layout);
      setLayout(next, false);
    } else pickGold();
  }
  return {shots, stage: E.stage + 1, score, peak, endless: shots >= 500};
}
const GAMES = 250;   // 60回では同じ設定でも中央値が34〜39にブレたので増やした

console.log(`\n3. 1ゲームの長さ（${START}玉スタート、${GAMES}ゲームずつ。目標は25〜35回）`);
console.log(`   ${pad('', 14)}${pad('回数(中央)', 14)}${pad('最短', 8)}${pad('最長', 8)}${pad('ステージ', 12)}${pad('スコア(中央)', 16)}${pad('持ち玉の最高', 16)}`);
const summary = [];
for (const [label, strat] of [['適当に打つ人', 'random'], ['うまい人', best]]) {
  const g = Array.from({length: GAMES}, () => game(strat));
  const shots = g.map(x => x.shots), mid = median(shots);
  summary.push({label, mid, max: Math.max(...shots), endless: g.filter(x => x.endless).length});
  console.log(`   ${pad(label, 14)}${pad(mid, 14)}${pad(Math.min(...shots), 8)}${pad(Math.max(...shots), 8)}` +
              `${pad(median(g.map(x => x.stage)), 12)}${pad(median(g.map(x => x.score)), 16)}${pad(Math.max(...g.map(x => x.peak)), 16)}`);
}
console.log(`   （${elapsed()}）`);

// ================= 4. チュートリアルがクリアできるか =================
// index.html のチュートリアルのデータをそのまま読んで、適当に打つ人で何%クリアできるか測る
const mSrc = html.slice(html.indexOf('const M_SLOT_EASY'), html.indexOf('const MAX_SHOTS'));
const STEPS = mSrc ? new Function(mSrc + '\nreturn STEPS;')() : [];
if (STEPS.length) {
  console.log(`\n4. チュートリアルがクリアできるか（適当に打つ人で100回ずつ）`);
  console.log(`   ${pad('', 4)}${pad('やること', 26)}${pad('クリア率', 10)}${pad('かかった回数(中央)', 20)}`);
  for (let i = 0; i < STEPS.length; i++) {
    const m = STEPS[i];
    let ok = 0; const used = [];
    for (let t = 0; t < 100; t++) {
      applyConf(m.conf);
      E.stage = 0; E.fever = false; E.boardSeed = m.seed;
      setLayout(m.layout || 0, false);
      let money = START, gauge = 0, feverLeft = 0, n = 0, score = 0;
      const prog = {hits: {}, maxMult: 0, gained: 0, maxBalls: 1, bestShot: 0, fever: false};
      let done = false;
      while (!done && money >= COST && n < 25) {
        money -= COST; n++;
        E.conveyor = Math.random() * CONV_LEN;
        const r = shoot(...randomShot());
        for (const v of r.pays) money = v < 0 ? Math.max(0, money + v) : money + v;
        for (const k in r.kinds) prog.hits[k] = (prog.hits[k] || 0) + r.kinds[k];
        prog.maxMult = Math.max(prog.maxMult, r.maxMult);
        prog.gained += r.pays.filter(v => v > 0).reduce((a, b) => a + b, 0);
        prog.maxBalls = Math.max(prog.maxBalls, r.maxBalls);
        prog.bestShot = Math.max(prog.bestShot, r.score);
        score += r.score;
        if (!E.fever) gauge += r.pot;
        if (E.fever) { if (--feverLeft <= 0) { E.fever = false; gauge = 0; } }
        else if (gauge >= FEVER_AT) { E.fever = true; feverLeft = FEVER_SHOTS; prog.fever = true; }
        const c = m.clear;
        done = c.type === 'shots' ? n >= c.n
          : c.type === 'hit' ? (prog.hits[c.kind] || 0) >= c.n
          : c.type === 'mult' ? prog.maxMult >= c.m
          : c.type === 'gain' ? prog.gained >= c.n
          : c.type === 'balls' ? prog.maxBalls >= c.n
          : c.type === 'shotScore' ? prog.bestShot >= c.n
          : c.type === 'score' ? score >= c.n
          : c.type === 'fever' ? prog.fever
          : c.type === 'survive' ? n >= c.n : false;
      }
      if (done) { ok++; used.push(n); }
    }
    const rate = ok + '%';
    const warn = ok < 60 ? '  ⚠ むずかしすぎるかも' : ok === 100 && median(used) <= 1 ? '  （すぐ終わる）' : '';
    const name = m.title.replace(/<[^>]*>/g, '');   // 見出しの色つけは外して表示する
    console.log(`   ${pad(i + 1, 4)}${pad(name, 26)}${pad(rate, 10)}${pad(used.length ? median(used) : '—', 20)}${warn}`);
  }
  applyConf();
  E.boardSeed = null;
  console.log(`   （${elapsed()}）`);
}

console.log(`\nまとめ`);
for (const s of summary) {
  const judge = s.endless ? `⚠ 終わらないゲームがあった（${s.endless}件）` :
    s.mid < 25 ? '⚠ 短い。もう少し玉が戻る受け皿を増やしたい' :
    s.mid > 35 ? '⚠ 長い。受け皿を厳しくしたい' : '目標どおり';
  console.log(`  ${s.label}：中央値${s.mid}回（最長${s.max}回） … ${judge}`);
}
console.log('');
