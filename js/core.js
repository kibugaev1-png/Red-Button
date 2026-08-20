// core.js — утилиты, генератор шума, ввод
'use strict';

const CELL = 8;               // размер частицы породы в мировых пикселях
const WW = 8000;              // ширина мира в частицах (~64 000 px)
// Высота мира. Небо занимает большую часть: сорокаэтажной высотке с
// просторными этажами нужно 480 частиц над землёй, плюс 200 вниз на породу
const WH = 720;
const CHUNK = 12;             // частиц в чанке
let SS = 3;                   // суперсэмплинг текстур породы: 3 — красиво, 1 — быстро
const QUALITY = { high: 3, mid: 2, low: 1 };
const GRAV = 0.42;
const DAY_LEN = 600;          // секунд в сутках (10 минут)
const FOOD_MAX = 300;         // сытость и вода как в Расте — до 300
const WATER_MAX = 300;
const STAM_MAX = 100;         // выносливость: бег, прыжки, удары, копание
const WARM_MAX = 100;         // тепло тела: ночь, дождь и высота студят

// локации: мир один, но разбит по X на зоны со своим рельефом и правилами
// Локации разнесены широкими ничейными полосами: между ними — свободная земля,
// где можно строить. Внутри самой локации строить нельзя
const ZONES = [
  {
    id: 'dead', name: 'Мёртвая зона', x0: 200, x1: 1000,
    desc: 'Выжженный район. Военные ящики на каждом шагу — и зомби на каждом ящике.',
    danger: 'смертельно', radMul: 1.8, zombies: 2.6, color: '#8a4030'
  },
  {
    id: 'city', name: 'Мирный город', x0: 1500, x1: 2300,
    desc: 'Уцелевший квартал за стеной. Торговец продаёт ресурсы, на доске висят задания. Зомби не заходят.',
    danger: 'безопасно', radMul: 0, zombies: 0, color: '#4a8a6a'
  },
  {
    id: 'waste', name: 'Пустошь', x0: 2800, x1: 3700,
    desc: 'Место, где ты проснулся. Сухая земля, обломки, редкие кусты. Строить можно.',
    danger: 'спокойно', radMul: 1, zombies: 0.7, color: '#a08a4a', build: true
  },
  {
    id: 'forest', name: 'Лес', x0: 4200, x1: 5000,
    desc: 'Мёртвые сосны стоят стеной. Здесь берут древесину — и только здесь.',
    danger: 'опасно', radMul: 1.1, zombies: 1.3, color: '#5a7a3c'
  },
  {
    id: 'mine', name: 'Шахта', x0: 5500, x1: 6300,
    desc: 'Скалы, обнажённая руда у поверхности и старый ствол вниз. Строить здесь можно.',
    danger: 'опасно', radMul: 1.2, zombies: 1.0, color: '#6a6f78', build: true
  },
  {
    id: 'towers', name: 'Руины небоскрёбов', x0: 6800, x1: 7700,
    desc: 'Скелеты высоток. Оружие на каждом этаже, а на самом верху — пулемёт. Лезть высоко и падать больно.',
    danger: 'очень опасно', radMul: 1.5, zombies: 2.0, color: '#7a6a90'
  }
];

const GAP_ZONE = {
  id: 'gap', name: 'Ничейная земля', radMul: 1, zombies: 0.8,
  danger: 'спокойно', color: '#7a7a70', build: true
};
function zoneAtCell(cx) {
  for (const z of ZONES) if (cx >= z.x0 && cx <= z.x1) return z;
  return GAP_ZONE;
}
function zoneAtPx(px) { return zoneAtCell(Math.floor(px / CELL)); }
// строить можно на пустоши и на ничейной земле между локациями
function canBuildAtCell(cx) { return !!zoneAtCell(cx).build; }

function clamp(v, a, b) { return v < a ? a : v > b ? b : v; }
function lerp(a, b, t) { return a + (b - a) * t; }
function rnd(a, b) { return a + Math.random() * (b - a); }
function irnd(a, b) { return Math.floor(rnd(a, b + 1)); }
function pick(arr) { return arr[Math.floor(Math.random() * arr.length)]; }
function dist(x1, y1, x2, y2) { return Math.hypot(x2 - x1, y2 - y1); }

function mulberry32(seed) {
  let a = seed >>> 0;
  return function () {
    a = (a + 0x6D2B79F5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// детерминированный хэш для мелкой текстуры породы
function hash2(x, y) {
  let h = x * 374761393 + y * 668265263;
  h = (h ^ (h >>> 13)) * 1274126177;
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}

// одномерный сглаженный шум для рельефа
function makeNoise1(seed) {
  const rand = mulberry32(seed);
  const grad = new Float32Array(4096);
  for (let i = 0; i < grad.length; i++) grad[i] = rand() * 2 - 1;
  return function (x) {
    const i = Math.floor(x), f = x - i;
    const a = grad[i & 4095], b = grad[(i + 1) & 4095];
    const t = f * f * (3 - 2 * f);
    return lerp(a, b, t);
  };
}

function makeNoise2(seed) {
  const rand = mulberry32(seed);
  const perm = new Uint8Array(512);
  for (let i = 0; i < 256; i++) perm[i] = i;
  for (let i = 255; i > 0; i--) { const j = Math.floor(rand() * (i + 1)); const t = perm[i]; perm[i] = perm[j]; perm[j] = t; }
  for (let i = 0; i < 256; i++) perm[i + 256] = perm[i];
  function g(hx, x, y) {
    switch (hx & 3) {
      case 0: return x + y; case 1: return -x + y; case 2: return x - y; default: return -x - y;
    }
  }
  return function (x, y) {
    const X = Math.floor(x) & 255, Y = Math.floor(y) & 255;
    const xf = x - Math.floor(x), yf = y - Math.floor(y);
    const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
    const aa = perm[perm[X] + Y], ab = perm[perm[X] + Y + 1];
    const ba = perm[perm[X + 1] + Y], bb = perm[perm[X + 1] + Y + 1];
    const x1 = lerp(g(aa, xf, yf), g(ba, xf - 1, yf), u);
    const x2 = lerp(g(ab, xf, yf - 1), g(bb, xf - 1, yf - 1), u);
    return lerp(x1, x2, v) * 0.5;
  };
}

function rgb(r, g, b) { return 'rgb(' + (r | 0) + ',' + (g | 0) + ',' + (b | 0) + ')'; }

// ---- ввод ----
const Input = {
  keys: {}, pressed: {}, mx: 0, my: 0, wx: 0, wy: 0,
  mdown: false, rdown: false, mclick: false, rclick: false, wheel: 0, zoomDelta: 0,
  isDown(code) { return !!this.keys[code]; },
  once(code) { if (this.pressed[code]) { this.pressed[code] = false; return true; } return false; },
  endFrame() { this.mclick = false; this.rclick = false; this.wheel = 0; this.zoomDelta = 0; this.pressed = {}; }
};

function bindInput(canvas) {
  addEventListener('keydown', e => {
    if (!Input.keys[e.code]) Input.pressed[e.code] = true;
    Input.keys[e.code] = true;
    if (['Tab', 'Space', 'ArrowUp', 'ArrowDown', 'F1'].includes(e.code)) e.preventDefault();
  });
  addEventListener('keyup', e => { Input.keys[e.code] = false; });
  addEventListener('blur', () => { Input.keys = {}; Input.mdown = false; });
  canvas.addEventListener('mousemove', e => {
    const r = canvas.getBoundingClientRect();
    Input.mx = (e.clientX - r.left) * (canvas.width / r.width);
    Input.my = (e.clientY - r.top) * (canvas.height / r.height);
  });
  canvas.addEventListener('mousedown', e => {
    // Ctrl+ЛКМ на маке приходит как левая кнопка — считаем это правым кликом
    const asRight = e.button === 2 || (e.button === 0 && (e.ctrlKey || e.metaKey));
    if (asRight) { Input.rdown = true; Input.rclick = true; e.preventDefault(); return; }
    if (e.button === 0) { Input.mdown = true; Input.mclick = true; }
  });
  // на случай средней кнопки и нестандартных мышей
  canvas.addEventListener('auxclick', e => { if (e.button === 2) { Input.rclick = true; e.preventDefault(); } });
  canvas.addEventListener('pointerdown', e => {
    if (e.pointerType === 'touch') { Input.mdown = true; Input.mclick = true; }
  });
  addEventListener('mouseup', e => {
    if (e.button === 0) Input.mdown = false;
    if (e.button === 2) Input.rdown = false;
  });
  canvas.addEventListener('contextmenu', e => e.preventDefault());
  addEventListener('contextmenu', e => { if (e.target === canvas) e.preventDefault(); });
  // Колесо мыши и щипок двумя пальцами на трекпаде — приближение и отдаление.
  // Трекпад присылает щипок как wheel с ctrlKey, поэтому шаг там мельче
  canvas.addEventListener('wheel', e => {
    Input.wheel = Math.sign(e.deltaY);
    Input.zoomDelta += -e.deltaY * (e.ctrlKey ? 0.008 : 0.0012);
    e.preventDefault();
  }, { passive: false });
  // сам жест щипка в Safari приходит отдельными событиями
  canvas.addEventListener('gesturechange', e => {
    Input.zoomDelta += (e.scale - 1) * 0.6;
    e.preventDefault();
  });
  for (const ev of ['gesturestart', 'gestureend']) canvas.addEventListener(ev, e => e.preventDefault());
}
