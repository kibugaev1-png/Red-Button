// build.js — строительство в духе Rust: строительный план, сетка, детали,
// тиры материалов (дерево → камень → металл), молоток для апгрейда и ремонта.
// Детали живут как объекты с прочностью, а в породу пишется только материал
// для столкновений — так дешевле и красивее, чем текстурить каждую частицу.
'use strict';

const GRID = 6;                      // модуль сетки в частицах (48 px)

const TIERS = [
  {
    id: 'wood', name: 'Дерево', mat: () => M.BUILD_W, hp: 250,
    res: 'wood', k: 1,
    pal: { base: '#8a6238', dark: '#5c3f22', light: '#b58a55', line: 'rgba(40,26,16,0.45)' }
  },
  {
    id: 'stone', name: 'Камень', mat: () => M.BUILD_S, hp: 700,
    res: 'stone', k: 3,
    pal: { base: '#7c7f84', dark: '#55585d', light: '#a2a6ab', line: 'rgba(20,22,26,0.45)' }
  },
  {
    id: 'metal', name: 'Металл', mat: () => M.BUILD_M, hp: 1600,
    res: 'iron', k: 2,
    pal: { base: '#6e7378', dark: '#454a4f', light: '#9aa1a8', line: 'rgba(16,18,20,0.5)' }
  }
];

// части: w/h в частицах, base — цена в единицах ресурса тира
const PARTS = [
  { id: 'foundation', name: 'Фундамент', w: GRID, h: 2, base: 20, ground: true, desc: 'С него начинается дом. Ставится на землю.' },
  { id: 'floor', name: 'Пол', w: GRID, h: 2, base: 16, desc: 'Перекрытие. Держится на стене или фундаменте.' },
  { id: 'wall', name: 'Стена', w: 2, h: GRID, base: 16, desc: 'Вертикальная стена в полный рост.' },
  { id: 'doorway', name: 'Дверной проём', w: 2, h: GRID, base: 26, hole: 'door', desc: 'Стена с проходом. E — открыть и закрыть дверь.' },
  { id: 'window', name: 'Окно', w: 2, h: GRID, base: 22, hole: 'window', desc: 'Стена с бойницей: стрелять можно, зомби не пролезет.' },
  { id: 'roof', name: 'Крыша', w: GRID, h: 2, base: 18, roof: true, desc: 'Скат сверху. Держит радиацию и дождь.' },
  { id: 'stairs', name: 'Лестница', w: GRID, h: GRID, base: 28, stairs: true, desc: 'Подъём на этаж выше.' },
  { id: 'bed', name: 'Кровать', w: GRID, h: 2, base: 24, bed: true, pass: true, desc: 'Точка возрождения. E — спать до утра.' }
];

function partCost(part, tier) {
  const t = TIERS[tier];
  return { res: t.res, n: Math.round(part.base * t.k) };
}

const Structures = {
  list: [],
  index: new Map(),                  // 'gx,gy' → деталь, чтобы быстро искать

  key(gx, gy) { return gx + ',' + gy; },

  reset() { this.list.length = 0; this.index.clear(); },

  // привязка мировых координат к сетке: детали всегда сходятся ровно
  snap(part, wx, wy) {
    const cx = Math.floor(wx / CELL), cy = Math.floor(wy / CELL);
    let gx, gy;
    if (part.w >= GRID) {            // фундамент, пол, крыша, лестница
      gx = Math.floor(cx / GRID) * GRID;
      gy = part.h >= GRID ? Math.floor(cy / GRID) * GRID : Math.round(cy / 2) * 2;
    } else {                         // стены и проёмы стоят на рёбрах модуля
      gx = Math.round(cx / GRID) * GRID;
      gy = Math.floor(cy / GRID) * GRID;
    }
    return { gx, gy };
  },

  at(cx, cy) {
    for (const s of this.list) {
      if (cx >= s.gx && cx < s.gx + s.w && cy >= s.gy && cy < s.gy + s.h) return s;
    }
    return null;
  },

  nearest(px, py, r) {
    let best = null, bd = r;
    for (const s of this.list) {
      const d = dist(px, py, (s.gx + s.w / 2) * CELL, (s.gy + s.h / 2) * CELL);
      if (d < bd) { bd = d; best = s; }
    }
    return best;
  },

  // можно ли поставить: свободно, есть опора, зона разрешает
  canPlace(part, gx, gy) {
    for (let x = gx; x < gx + part.w; x++) {
      if (!canBuildAtCell(x)) return 'В самой локации строить нельзя';
      if (World.protectedAt(x)) return 'Город трогать нельзя';
    }
    for (let x = gx; x < gx + part.w; x++) {
      for (let y = gy; y < gy + part.h; y++) {
        const m = World.get(x, y);
        if (m !== M.AIR && MATS[m] && (MATS[m].struct || MATS[m].door)) return 'Здесь уже стоит деталь';
      }
    }
    if (Machines.boxBusy(gx, gy + part.h - 1, part.w, part.h)) return 'Мешает верстак или мебель';

    if (part.ground) {
      // фундамент требует земли под собой
      let ground = 0;
      for (let x = gx; x < gx + part.w; x++) if (World.solid(x, gy + part.h)) ground++;
      if (ground < part.w * 0.5) return 'Фундаменту нужна земля под низом';
      return null;
    }
    // остальное держится на другой детали или на породе рядом
    let support = false;
    for (let x = gx - 1; x <= gx + part.w && !support; x++) {
      for (let y = gy - 1; y <= gy + part.h && !support; y++) {
        if (x >= gx && x < gx + part.w && y >= gy && y < gy + part.h) continue;
        const m = World.get(x, y);
        if (m === M.AIR) continue;
        if (MATS[m].struct || MATS[m].solid) support = true;
      }
    }
    if (!support) return 'Деталь висит в воздухе — нужна опора';
    return null;
  },

  place(partId, gx, gy, tier, free) {
    const part = PARTS.find(p => p.id === partId);
    const err = this.canPlace(part, gx, gy);
    if (err) { Player.say(err); return false; }
    const cost = partCost(part, tier);
    if (!free && Player.inv.count(cost.res) < cost.n) {
      Player.say('Нужно ' + cost.n + ' ' + ITEMS[cost.res].name.toLowerCase());
      return false;
    }
    if (!free) Player.inv.remove(cost.res, cost.n);

    const s = {
      kind: partId, part, gx, gy, w: part.w, h: part.h,
      tier, hp: TIERS[tier].hp, maxHp: TIERS[tier].hp,
      open: false, t: 0
    };
    this.list.push(s);
    this.index.set(this.key(gx, gy), s);
    this.stamp(s);
    Particles.burst((gx + s.w / 2) * CELL, (gy + s.h / 2) * CELL, [160, 130, 90], 8);
    return true;
  },

  // записать деталь в породу: сплошняк, кроме проёмов
  stamp(s) {
    const mat = TIERS[s.tier].mat();
    for (let x = s.gx; x < s.gx + s.w; x++) {
      for (let y = s.gy; y < s.gy + s.h; y++) {
        World.set(x, y, this.cellOf(s, x, y) ? mat : M.AIR);
      }
    }
  },

  // сплошная ли частица детали (false — дырка проёма, скос лестницы, мебель)
  cellOf(s, x, y) {
    const lx = x - s.gx, ly = y - s.gy;
    if (s.part.pass) return false;                                  // мебель проходима насквозь
    if (s.part.hole === 'door') return s.open ? (ly < 1) : true;   // открытая дверь пропускает
    if (s.part.hole === 'window') return !(ly >= 2 && ly <= 3);
    if (s.part.stairs) return lx >= (s.h - 1 - ly);                // ступени по диагонали
    return true;
  },

  unstamp(s) {
    for (let x = s.gx; x < s.gx + s.w; x++) {
      for (let y = s.gy; y < s.gy + s.h; y++) World.set(x, y, M.AIR);
    }
  },

  remove(s) {
    this.unstamp(s);
    const i = this.list.indexOf(s);
    if (i >= 0) this.list.splice(i, 1);
    this.index.delete(this.key(s.gx, s.gy));
  },

  toggleDoor(s) {
    if (s.part.hole !== 'door') return;
    // не закрываемся на игроке
    if (s.open) {
      const px = Math.floor(Player.x / CELL);
      if (px >= s.gx - 1 && px <= s.gx + s.w && Math.abs(Player.y - (s.gy + s.h) * CELL) < 70) {
        Player.say('Ты стоишь в проёме'); return;
      }
    }
    s.open = !s.open;
    this.stamp(s);
    Player.say(s.open ? 'Дверь открыта' : 'Дверь закрыта');
  },

  damage(s, dmg) {
    s.hp -= dmg;
    Particles.burst((s.gx + s.w / 2) * CELL, (s.gy + s.h / 2) * CELL, [140, 120, 100], 4);
    if (s.hp <= 0) {
      // при разрушении возвращается половина материала
      const cost = partCost(s.part, s.tier);
      Drops.add((s.gx + s.w / 2) * CELL, (s.gy + s.h / 2) * CELL, cost.res, Math.max(1, Math.round(cost.n * 0.5)));
      this.remove(s);
      Player.say(s.part.name + ' разрушен');
      return true;
    }
    return false;
  },

  upgrade(s) {
    if (s.tier >= TIERS.length - 1) { Player.say('Дальше улучшать некуда — это металл'); return false; }
    const next = s.tier + 1;
    const cost = partCost(s.part, next);
    if (Player.inv.count(cost.res) < cost.n) {
      Player.say('Нужно ' + cost.n + ' ' + ITEMS[cost.res].name.toLowerCase());
      return false;
    }
    Player.inv.remove(cost.res, cost.n);
    const frac = s.hp / s.maxHp;
    s.tier = next;
    s.maxHp = TIERS[next].hp;
    s.hp = Math.max(1, Math.round(s.maxHp * frac));
    this.stamp(s);
    Particles.spark((s.gx + s.w / 2) * CELL, (s.gy + s.h / 2) * CELL);
    Player.say(s.part.name + ' → ' + TIERS[next].name);
    return true;
  },

  repair(s) {
    if (s.hp >= s.maxHp) { Player.say('Деталь целая'); return false; }
    const cost = partCost(s.part, s.tier);
    const need = Math.max(1, Math.round(cost.n * 0.25));
    if (Player.inv.count(cost.res) < need) { Player.say('Нужно ' + need + ' ' + ITEMS[cost.res].name.toLowerCase()); return false; }
    Player.inv.remove(cost.res, need);
    s.hp = Math.min(s.maxHp, s.hp + s.maxHp * 0.35);
    Particles.spark((s.gx + s.w / 2) * CELL, (s.gy + s.h / 2) * CELL);
    Player.say('Починил: ' + Math.round(s.hp) + '/' + s.maxHp);
    return true;
  },

  bed() { return this.list.find(s => s.part.bed); },

  update(dt) { for (const s of this.list) s.t += dt; },

  // ---- отрисовка ----
  draw(ctx) {
    for (const s of this.list) this.drawPart(ctx, s, 1);
  },

  drawPart(ctx, s, alpha) {
    const p = TIERS[s.tier].pal;
    const x0 = s.gx * CELL, y0 = s.gy * CELL;
    const w = s.w * CELL, h = s.h * CELL;
    ctx.save();
    ctx.globalAlpha = alpha;

    if (s.part.bed) {
      const p2 = TIERS[s.tier].pal;
      // рама
      ctx.fillStyle = p2.dark;
      ctx.beginPath(); ctx.roundRect(x0, y0 + h - 5, w, 5, 1.5); ctx.fill();
      ctx.fillStyle = shade(p2.dark, 0.8);
      ctx.fillRect(x0 + 1, y0 + h, 3.5, 4);
      ctx.fillRect(x0 + w - 4.5, y0 + h, 3.5, 4);
      // спинки
      ctx.fillStyle = p2.base;
      ctx.beginPath(); ctx.roundRect(x0 - 1, y0 - 6, 4, h + 1, 1.5); ctx.fill();
      ctx.beginPath(); ctx.roundRect(x0 + w - 3, y0 - 2, 4, h - 3, 1.5); ctx.fill();
      // матрас
      const mg = ctx.createLinearGradient(x0, y0, x0, y0 + h - 4);
      mg.addColorStop(0, '#9d8b78'); mg.addColorStop(1, '#6d5f52');
      ctx.fillStyle = mg;
      ctx.beginPath(); ctx.roundRect(x0 + 2, y0, w - 5, h - 4, 2.5); ctx.fill();
      // одеяло и подушка
      ctx.fillStyle = '#8a4a3c';
      ctx.beginPath(); ctx.roundRect(x0 + w * 0.36, y0 - 1, w * 0.6, h - 3, 2.5); ctx.fill();
      ctx.fillStyle = 'rgba(255,255,255,0.14)';
      ctx.fillRect(x0 + w * 0.36, y0 - 1, w * 0.6, 1.4);
      ctx.fillStyle = '#d5cfbc';
      ctx.beginPath(); ctx.roundRect(x0 + 3, y0 - 2.5, w * 0.26, h - 3, 2.5); ctx.fill();
      ctx.fillStyle = 'rgba(0,0,0,0.12)';
      ctx.fillRect(x0 + 3, y0 + h - 6, w * 0.26, 1.2);
      this.hpBar(ctx, s, x0, y0, w);
      ctx.restore(); return;
    }

    if (s.part.stairs) {
      // ступени: рисуем каждую проступь
      const n = s.h / 2;
      for (let i = 0; i < n; i++) {
        const sw = w * (i + 1) / n;
        const sy = y0 + h - (i + 1) * (h / n);
        this.slab(ctx, x0 + w - sw, sy, sw, h / n, p, s.tier);
      }
      ctx.restore(); return;
    }

    if (s.part.hole === 'door') {
      // рама и полотно
      this.slab(ctx, x0, y0, w, CELL * 1, p, s.tier);
      const openW = s.open ? w * 0.25 : w;
      const dh = h - CELL;
      const g = ctx.createLinearGradient(x0, 0, x0 + openW, 0);
      g.addColorStop(0, p.dark); g.addColorStop(0.5, p.base); g.addColorStop(1, p.dark);
      ctx.fillStyle = g;
      ctx.fillRect(x0, y0 + CELL, openW, dh);
      ctx.fillStyle = p.line;
      for (let i = 1; i < 4; i++) ctx.fillRect(x0, y0 + CELL + dh * i / 4, openW, 1.2);
      ctx.fillStyle = 'rgba(255,240,210,0.10)';
      for (let i = 1; i < 4; i++) ctx.fillRect(x0, y0 + CELL + dh * i / 4 + 1.2, openW, 0.8);
      // петли и ручка
      ctx.fillStyle = '#4a4d52';
      ctx.fillRect(x0 - 1, y0 + CELL + 4, 3, 4);
      ctx.fillRect(x0 - 1, y0 + dh - 2, 3, 4);
      if (!s.open) { ctx.fillStyle = '#c9a94a'; ctx.beginPath(); ctx.arc(x0 + w - 3.5, y0 + CELL + dh * 0.5, 1.8, 0, 7); ctx.fill(); }
      this.hpBar(ctx, s, x0, y0, w);
      ctx.restore(); return;
    }

    if (s.part.hole === 'window') {
      this.slab(ctx, x0, y0, w, CELL * 2, p, s.tier);
      this.slab(ctx, x0, y0 + CELL * 4, w, h - CELL * 4, p, s.tier);
      // рама бойницы
      ctx.strokeStyle = p.dark; ctx.lineWidth = 1.4;
      ctx.strokeRect(x0 + 0.5, y0 + CELL * 2 + 0.5, w - 1, CELL * 2 - 1);
      ctx.fillStyle = 'rgba(120,150,160,0.14)';
      ctx.fillRect(x0 + 1, y0 + CELL * 2 + 1, w - 2, CELL * 2 - 2);
      this.hpBar(ctx, s, x0, y0, w);
      ctx.restore(); return;
    }

    if (s.part.roof) {
      // скат с нахлёстом
      const rows = 2;
      for (let r = 0; r < rows; r++) {
        const ry = y0 + r * (h / rows);
        for (let i = 0; i < s.w; i++) {
          const tx = x0 + i * CELL + (r ? CELL * 0.5 : 0);
          const g = ctx.createLinearGradient(tx, ry, tx, ry + h / rows);
          g.addColorStop(0, p.light); g.addColorStop(1, p.dark);
          ctx.fillStyle = g;
          ctx.beginPath(); ctx.roundRect(tx, ry, CELL * 0.92, h / rows * 0.95, [0, 0, 2, 2]); ctx.fill();
          ctx.strokeStyle = p.line; ctx.lineWidth = 0.7;
          ctx.beginPath(); ctx.roundRect(tx, ry, CELL * 0.92, h / rows * 0.95, [0, 0, 2, 2]); ctx.stroke();
        }
      }
      this.hpBar(ctx, s, x0, y0, w);
      ctx.restore(); return;
    }

    // фундамент, пол, стена
    this.slab(ctx, x0, y0, w, h, p, s.tier, s.part.id);
    this.hpBar(ctx, s, x0, y0, w);
    ctx.restore();
  },

  // общая «плита» с фактурой тира
  slab(ctx, x, y, w, h, p, tier, kind) {
    const g = ctx.createLinearGradient(x, y, x, y + h);
    g.addColorStop(0, p.light); g.addColorStop(0.35, p.base); g.addColorStop(1, p.dark);
    ctx.fillStyle = g;
    ctx.fillRect(x, y, w, h);

    if (tier === 0) {
      // доски: вдоль длинной стороны
      ctx.fillStyle = p.line;
      if (w >= h) { for (let i = 1; i < Math.round(h / 8) + 1; i++) ctx.fillRect(x, y + i * 8 - 1, w, 1.2); }
      else { for (let i = 1; i < Math.round(w / 8) + 1; i++) ctx.fillRect(x + i * 8 - 1, y, 1.2, h); }
      ctx.fillStyle = 'rgba(255,240,210,0.10)';
      if (w >= h) { for (let i = 1; i < Math.round(h / 8) + 1; i++) ctx.fillRect(x, y + i * 8, w, 0.8); }
      else { for (let i = 1; i < Math.round(w / 8) + 1; i++) ctx.fillRect(x + i * 8, y, 0.8, h); }
      // гвозди по краям
      ctx.fillStyle = 'rgba(70,72,76,0.8)';
      ctx.fillRect(x + 2, y + 2, 1.4, 1.4);
      ctx.fillRect(x + w - 3.4, y + 2, 1.4, 1.4);
    } else if (tier === 1) {
      // каменная кладка со швами вразбежку
      const bw = 12, bh = 8;
      ctx.strokeStyle = p.line; ctx.lineWidth = 1;
      for (let ry = 0; ry < h; ry += bh) {
        const off = ((ry / bh) % 2) * bw * 0.5;
        for (let rx = -bw; rx < w; rx += bw) {
          ctx.strokeRect(x + rx + off + 0.5, y + ry + 0.5, bw - 1, bh - 1);
        }
        ctx.fillStyle = 'rgba(255,255,255,0.05)';
        ctx.fillRect(x, y + ry, w, 1);
      }
    } else {
      // металл: гофра и заклёпки
      for (let i = 0; i < w; i += 10) {
        const gg = ctx.createLinearGradient(x + i, 0, x + i + 10, 0);
        gg.addColorStop(0, 'rgba(0,0,0,0.18)');
        gg.addColorStop(0.45, 'rgba(255,255,255,0.12)');
        gg.addColorStop(1, 'rgba(0,0,0,0.18)');
        ctx.fillStyle = gg; ctx.fillRect(x + i, y, 10, h);
      }
      ctx.fillStyle = 'rgba(30,32,34,0.8)';
      for (let rx = 4; rx < w - 2; rx += 14) {
        ctx.beginPath(); ctx.arc(x + rx, y + 3, 1.3, 0, 7); ctx.fill();
        ctx.beginPath(); ctx.arc(x + rx, y + h - 3, 1.3, 0, 7); ctx.fill();
      }
    }
    // кромки: сверху светлее, снизу темнее — объём
    ctx.fillStyle = 'rgba(255,248,226,0.16)'; ctx.fillRect(x, y, w, 1.4);
    ctx.fillStyle = 'rgba(0,0,0,0.24)'; ctx.fillRect(x, y + h - 1.6, w, 1.6);
    ctx.strokeStyle = 'rgba(0,0,0,0.28)'; ctx.lineWidth = 1;
    ctx.strokeRect(x + 0.5, y + 0.5, w - 1, h - 1);
  },

  hpBar(ctx, s, x, y, w) {
    if (s.hp >= s.maxHp) return;
    const f = clamp(s.hp / s.maxHp, 0, 1);
    ctx.fillStyle = 'rgba(0,0,0,0.6)'; ctx.fillRect(x, y - 4, w, 2.4);
    ctx.fillStyle = f > 0.5 ? '#6aa86a' : f > 0.25 ? '#d0a038' : '#c04a3a';
    ctx.fillRect(x, y - 4, w * f, 2.4);
  },

  // ---- призрак под курсором ----
  drawGhost(ctx, partId, tier) {
    const part = PARTS.find(p => p.id === partId);
    const { gx, gy } = this.snap(part, Input.wx, Input.wy);
    const err = this.canPlace(part, gx, gy);
    const cost = partCost(part, tier);
    const enough = Player.inv.count(cost.res) >= cost.n;
    const ok = !err && enough;

    ctx.save();
    ctx.globalAlpha = 0.55;
    this.drawPart(ctx, { kind: partId, part, gx, gy, w: part.w, h: part.h, tier, hp: 1, maxHp: 1, open: false, t: 0 }, 0.5);
    ctx.restore();

    const x0 = gx * CELL, y0 = gy * CELL, w = part.w * CELL, h = part.h * CELL;
    ctx.save();
    ctx.strokeStyle = ok ? 'rgba(120,220,140,0.95)' : 'rgba(230,90,70,0.95)';
    ctx.lineWidth = 1.4;
    ctx.setLineDash([5, 4]);
    ctx.strokeRect(x0 + 0.5, y0 + 0.5, w - 1, h - 1);
    ctx.setLineDash([]);
    ctx.fillStyle = ok ? 'rgba(120,220,140,0.12)' : 'rgba(230,90,70,0.16)';
    ctx.fillRect(x0, y0, w, h);
    ctx.restore();
    return { gx, gy, ok, err: err || (!enough ? 'Не хватает материала' : null), cost };
  }
};


// ---- ноды руды: валуны на поверхности, как в Rust ----
const NODE_KINDS = {
  metal: { name: 'Металлическая нода', res: 'iron_ore', hits: 8, col: ['#7a6a58', '#a2865c'], spark: '#c88a4a' },
  sulfur: { name: 'Серная нода', res: 'sulfur_ore', hits: 8, col: ['#7a7440', '#c0b048'], spark: '#e0d060' },
  stone: { name: 'Каменная нода', res: 'stone', hits: 6, col: ['#6f7378', '#9aa0a6'], spark: '#c0c6cc' },
  hqm: { name: 'Нода HQM', res: 'hqm_ore', hits: 14, col: ['#4e5a66', '#8fa6bc'], spark: '#c2d6e8' }
};

const Nodes = {
  list: [],

  seed() {
    this.list.length = 0;
    const rand = mulberry32(20260805);
    for (const z of ZONES.concat([{ id: 'gap', x0: 0, x1: WW - 1 }])) {
      if (z.id === 'city') continue;
      const density = z.id === 'mine' ? 26 : z.id === 'gap' ? 190 : 90;
      for (let x = z.x0 + 10; x < z.x1 - 10; x += density + Math.floor(rand() * 40)) {
        if (zoneAtCell(x).id === 'city') continue;
        let kind = 'stone';
        const r = rand();
        if (z.id === 'mine') kind = r < 0.42 ? 'metal' : r < 0.68 ? 'sulfur' : r < 0.78 ? 'hqm' : 'stone';
        else kind = r < 0.3 ? 'metal' : r < 0.5 ? 'sulfur' : r < 0.55 ? 'hqm' : 'stone';
        this.list.push({ kind, x, y: World.surface[x], left: NODE_KINDS[kind].hits, max: NODE_KINDS[kind].hits, t: rand() * 6, respawn: 0 });
      }
    }
  },

  at(px, py, r) {
    for (const n of this.list) {
      if (n.respawn > 0) continue;
      if (dist(px, py, n.x * CELL + 8, n.y * CELL - 8) < (r || 26)) return n;
    }
    return null;
  },

  // удар киркой: ресурс капает с каждого удара, нода тратится и потом восстанавливается
  hit(n, power) {
    const k = NODE_KINDS[n.kind];
    const yield_ = Math.max(1, Math.round(power * 0.6));
    Player.inv.add(k.res, yield_);
    Floaters.push(n.x * CELL + 8, n.y * CELL - 18, '+' + yield_ + ' ' + ITEMS[k.res].name.toLowerCase(), '#e0c88a');
    Particles.burst(n.x * CELL + 8, n.y * CELL - 8, [150, 130, 100], 5);
    Particles.spark(n.x * CELL + 8, n.y * CELL - 10);
    n.left--;
    if (n.left <= 0) {
      n.respawn = 150;                       // через 2.5 минуты вырастет заново
      Player.say(k.name + ' выработана');
    }
  },

  update(dt) {
    for (const n of this.list) {
      n.t += dt;
      if (n.respawn > 0) {
        n.respawn -= dt;
        if (n.respawn <= 0) n.left = n.max;
      }
    }
  },

  draw(ctx) {
    for (const n of this.list) {
      if (n.respawn > 0) continue;
      const k = NODE_KINDS[n.kind];
      const px = n.x * CELL + 8, py = n.y * CELL;
      const worn = n.left / n.max;
      const r = 9 + worn * 7;
      // валун
      const g = ctx.createRadialGradient(px - r * 0.3, py - r * 1.1, r * 0.2, px, py - r * 0.6, r * 1.5);
      g.addColorStop(0, k.col[1]); g.addColorStop(1, k.col[0]);
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.moveTo(px - r, py);
      ctx.quadraticCurveTo(px - r * 1.05, py - r * 0.9, px - r * 0.4, py - r * 1.25);
      ctx.quadraticCurveTo(px + r * 0.2, py - r * 1.5, px + r * 0.75, py - r * 1.05);
      ctx.quadraticCurveTo(px + r * 1.15, py - r * 0.5, px + r, py);
      ctx.closePath(); ctx.fill();
      // жила: блики цвета ресурса
      ctx.fillStyle = k.spark;
      for (let i = 0; i < 4; i++) {
        const h = hash2(n.x * 7 + i, n.y * 13 - i);
        ctx.globalAlpha = 0.85;
        ctx.beginPath();
        ctx.ellipse(px + (h - 0.5) * r * 1.2, py - r * (0.3 + h * 0.8), r * 0.16, r * 0.11, h * 3, 0, 7);
        ctx.fill();
      }
      ctx.globalAlpha = 1;
      // тень под валуном
      ctx.fillStyle = 'rgba(0,0,0,0.3)';
      ctx.beginPath(); ctx.ellipse(px, py + 1, r * 0.9, r * 0.2, 0, 0, 7); ctx.fill();
      // сколько осталось
      if (worn < 1) {
        ctx.fillStyle = 'rgba(0,0,0,0.55)'; ctx.fillRect(px - r, py - r * 1.8, r * 2, 2);
        ctx.fillStyle = k.spark; ctx.fillRect(px - r, py - r * 1.8, r * 2 * worn, 2);
      }
    }
  }
};
