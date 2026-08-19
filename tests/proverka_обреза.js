// Проверка обреза без браузера.
//
// Модули игры объявляют свои таблицы через const на верхнем уровне, поэтому
// снаружи их не видно: чтобы проверять настоящие данные игры, а не свои
// ожидания, собираем боевые файлы и проверки в один скрипт и запускаем его в
// песочнице с заглушкой вместо канваса.
//
// Запуск:  node tests/proverka_obreza.js
'use strict';
const fs = require('fs'), vm = require('vm'), path = require('path');
const ROOT = path.resolve(__dirname, '..');

const calls = [];
const ctxStub = new Proxy({}, {
  get(t, k) {
    if (k === 'canvas') return { width: 64, height: 64 };
    if (['fillStyle','strokeStyle','lineWidth','globalAlpha','font','textAlign','lineCap','lineJoin','filter'].includes(k)) return '';
    return (...a) => {
      calls.push(k);
      return (k === 'createLinearGradient' || k === 'createRadialGradient') ? { addColorStop() {} } : undefined;
    };
  },
  set() { return true; },
});

const bad = [];
const sandbox = {
  console, Math, Date, JSON, performance: { now: () => 0 },
  requestAnimationFrame: () => {}, addEventListener: () => {}, removeEventListener: () => {},
  localStorage: { getItem: () => null, setItem() {}, removeItem() {} }, devicePixelRatio: 1,
  document: {
    getElementById: () => null,
    createElement: () => ({ getContext: () => ctxStub, style: {}, width: 0, height: 0,
      appendChild() {}, addEventListener() {}, classList: { add() {}, remove() {} } }),
    body: { appendChild() {}, style: {} }, addEventListener() {}, documentElement: { style: {} },
  },
  __ctx: ctxStub, __calls: calls, __bad: bad, __log: s => console.log(s),
};
sandbox.window = sandbox;

const sources = ['core.js', 'world.js', 'human.js', 'items.js']
  .map(f => `\n//---- ${f} ----\n` + fs.readFileSync(path.join(ROOT, 'js', f), 'utf8'))
  .join('');

const checks = `
const R = (n, ok, ex) => { if (!ok) __bad.push(n); __log((ok ? '  ок      ' : '  ПРОВАЛ  ') + n + (ex ? ' — ' + ex : '')); };
const g = ITEMS.sawnoff, sh = ITEMS.shotgun;
R('обрез есть в справочнике предметов', !!g, g && g.name);
R('оружие под картечь', g.type === 'gun' && g.ammo === 'buckshot', g.ammo);
R('два патрона в стволах', g.mag === 2, 'mag=' + g.mag);
R('девять картечин за выстрел', g.pellets === 9, 'pellets=' + g.pellets);
R('в упор бьёт сильнее дробовика', g.dmg * g.pellets > sh.dmg * sh.pellets, g.dmg * g.pellets + ' против ' + sh.dmg * sh.pellets);
R('разброс шире дробовика', g.spread > sh.spread, g.spread + ' против ' + sh.spread);
R('отдача сильнее дробовика', g.rec > sh.rec, g.rec + ' против ' + sh.rec);
const rec = RECIPES.filter(r => r.out[0] === 'sawnoff');
R('два рецепта', rec.length === 2, rec.map(r => Object.keys(r.in).join('+')).join(' | '));
const shRec = RECIPES.find(r => r.out[0] === 'shotgun');
const cheap = rec.find(r => r.in.iron);
R('дешевле дробовика по железу', !!cheap && cheap.in.iron < shRec.in.iron, cheap.in.iron + ' против ' + shRec.in.iron);
R('можно отпилить ствол дробовику', !!rec.find(r => r.in.shotgun));

// У drawWeapon есть общая ветка на всё неизвестное, поэтому важно не число
// вызовов, а что рисунок обреза отличается и от неё, и от дробовика.
const seq = k => { __calls.length = 0; drawWeapon(__ctx, 0, 0, 0, k, 0); return __calls.join(','); };
const sawSeq = seq('sawnoff'), fallback = seq('nosuchgun'), shotSeq = seq('shotgun');
R('обрез рисуется', sawSeq.split(',').length > 10, sawSeq.split(',').length + ' вызовов канваса');
R('обрез рисуется своей веткой, а не общей', sawSeq !== fallback);
R('обрез нарисован иначе, чем дробовик', sawSeq !== shotSeq);
__calls.length = 0; ITEMS.sawnoff.icon(__ctx, 32);
R('иконка в инвентаре рисуется', __calls.length > 10, __calls.length + ' вызовов');
`;

vm.runInContext(sources + checks, vm.createContext(sandbox), { filename: 'proverka_obreza.js' });
console.log(bad.length ? '\nПРОВАЛИЛОСЬ: ' + bad.length : '\nВСЁ ПРОШЛО');
process.exit(bad.length ? 1 : 0);
