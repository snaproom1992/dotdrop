#!/usr/bin/env node
// Independent JS reference for the native field bounds (top だけ差し替え、下端は本家のまま).
// No changes to the Web source or the physics reference fixtures.
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '../..');
const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const start = html.indexOf('/*ENGINE*/'), end = html.indexOf('/*END*/');
if (start < 0 || end <= start) throw new Error('Missing engine markers');
let src = html.slice(start, end);
const original = 'const field = () => ({top: 200, bottom: E.LH - 135});';
if (!src.includes(original)) throw new Error('Review changed Web field bounds');
src = src.replace(original, 'const field = () => ({top: E.nativeTop, bottom: E.LH - 135});');
const { E, applyConf, setLayout } = new Function(src + '\nreturn { E, applyConf, setLayout };')();
const fixtures = [];
for (const height of [700, 748]) for (const top of [200, 226]) for (let layout = 0; layout < 4; layout++) {
  applyConf();
  E.LH = height; E.nativeTop = top; E.boardSeed = 7;
  setLayout(layout, false);
  fixtures.push({ id: `${height}-${top}-${layout}`, boardSeed: 7, layout, height, top,
    pegs: E.pegs.map(({x, y, kind}) => ({x, y, kind})) });
}
fs.writeFileSync(path.join(root, 'ios/DotDropEngine/Tests/Fixtures/native-layouts.json'), JSON.stringify(fixtures, null, 2) + '\n');
console.log(`Generated ${fixtures.length} native layout reference cases`);
