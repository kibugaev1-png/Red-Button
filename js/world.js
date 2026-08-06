// world.js — порода, генерация мира, копание, отрисовка
'use strict';

const M = {
  AIR: 0, GRASS: 1, DIRT: 2, CLAY: 3, STONE: 4, COAL: 5, IRON: 6, COPPER: 7,
  TRUNK: 8, LEAF: 9, CONCRETE: 10, PLANK: 11, WATER: 12, FARM: 13, REBAR: 14, ASH: 15,
  LADDER: 16, WALL_W: 17, FLOOR_W: 18, ROOF_W: 19,
  DOOR: 20, DOOR_OPEN: 21, METAL: 22, BG_WOOD: 23, BG_METAL: 24,
  BUILD_W: 25, BUILD_S: 26, BUILD_M: 27
};

// hard — сколько секунд копать кайлом; drop — id предмета; var — разброс тона
const MATS = [
  null,
  { name: 'Трава', c: [82, 90, 48], var: 22, hard: 0.35, drop: 'dirt', solid: true, grass: true },
  { name: 'Земля', c: [66, 48, 32], var: 18, hard: 0.4, drop: 'dirt', solid: true },
  { name: 'Глина', c: [100, 66, 46], var: 15, hard: 0.6, drop: 'clay', solid: true },
  { name: 'Камень', c: [76, 78, 84], var: 17, hard: 1.1, drop: 'stone', solid: true, crack: true },
  { name: 'Уголь', c: [74, 74, 78], var: 16, hard: 1.3, drop: 'coal', solid: true, ore: [34, 32, 36] },
  { name: 'Железная руда', c: [98, 92, 92], var: 16, hard: 1.7, drop: 'iron_ore', solid: true, ore: [162, 104, 66] },
  { name: 'Медная руда', c: [94, 96, 94], var: 16, hard: 1.6, drop: 'copper_ore', solid: true, ore: [92, 148, 120] },
  // ствол проходим насквозь: иначе в лесу не пройти шагу, как и в Terraria
  { name: 'Ствол', c: [78, 58, 42], var: 18, hard: 0.7, drop: 'wood', solid: false, bark: true },
  { name: 'Листва', c: [74, 88, 52], var: 30, hard: 0.2, drop: 'stick', solid: false, leaf: true },
  { name: 'Бетон', c: [124, 122, 116], var: 14, hard: 2.2, drop: 'concrete', solid: true, crack: true },
  { name: 'Доски', c: [126, 96, 62], var: 14, hard: 0.5, drop: 'plank', solid: true, plank: true },
  { name: 'Вода', c: [58, 96, 82], var: 10, hard: 0, drop: null, solid: false, water: true },
  { name: 'Грядка', c: [62, 44, 30], var: 16, hard: 0.3, drop: 'dirt', solid: true, tilled: true },
  { name: 'Арматура', c: [104, 74, 58], var: 12, hard: 2.6, drop: 'scrap', solid: true },
  { name: 'Пепел', c: [96, 92, 88], var: 24, hard: 0.25, drop: null, solid: true, ash: true },
  { name: 'Лестница', c: [122, 92, 58], var: 12, hard: 0.3, drop: 'ladder', solid: false, ladder: true },
  { name: 'Деревянная стена', c: [124, 92, 56], var: 13, hard: 0.55, drop: 'wood', solid: true, woody: true, build: 'wall' },
  { name: 'Деревянный пол', c: [132, 100, 62], var: 13, hard: 0.5, drop: 'wood', solid: true, woody: true, build: 'floor' },
  { name: 'Деревянная крыша', c: [110, 80, 50], var: 14, hard: 0.55, drop: 'wood', solid: true, woody: true, build: 'roof' },
  { name: 'Дверь', c: [118, 86, 52], var: 10, hard: 0.7, drop: null, solid: true, woody: true, door: true },
  { name: 'Открытая дверь', c: [118, 86, 52], var: 10, hard: 0.7, drop: null, solid: false, woody: true, door: true },
  { name: 'Профлист', c: [126, 128, 130], var: 14, hard: 2.0, drop: 'scrap', solid: true, metal: true },
  // фоновые стены: сквозь них ходишь, но помещение выглядит помещением
  { name: 'Обшивка', c: [64, 47, 30], var: 10, hard: 0.4, drop: null, solid: false, bg: 'wood' },
  { name: 'Обшивка железом', c: [62, 64, 68], var: 10, hard: 0.4, drop: null, solid: false, bg: 'metal' },
  // постройки игрока: рисует их build.js, в породе они только для столкновений
  { name: 'Деревянная постройка', c: [138, 98, 56], var: 0, hard: 0.9, drop: null, solid: true, struct: 0 },
  { name: 'Каменная постройка', c: [124, 127, 132], var: 0, hard: 1.8, drop: null, solid: true, struct: 1 },
  { name: 'Металлическая постройка', c: [110, 116, 122], var: 0, hard: 3.0, drop: null, solid: true, struct: 2 }
];

const World = {
  cells: new Uint8Array(WW * WH),
  surface: new Int16Array(WW),
  chunks: new Map(),
  spawnX: 0, spawnY: 0,

  idx(x, y) { return y * WW + x; },
  inside(x, y) { return x >= 0 && y >= 0 && x < WW && y < WH; },
  get(x, y) { return this.inside(x, y) ? this.cells[y * WW + x] : M.STONE; },
  info(x, y) { return MATS[this.get(x, y)]; },
  solid(x, y) { const m = this.get(x, y); return m !== M.AIR && MATS[m].solid; },
  set(x, y, m) {
    if (!this.inside(x, y)) return;
    this.cells[y * WW + x] = m;
    this.dirty(x, y);
  },
  // Соседние чанки сбрасываем только если частица на границе чанка.
  // Раньше любой изменённый пиксель убивал 9 чанков — на кирке 9×9 это
  // выходило в сотни перерисовок за один замах и роняло FPS
  dirty(x, y) {
    const cx = Math.floor(x / CHUNK), cy = Math.floor(y / CHUNK);
    this.chunks.delete(cx + ',' + cy);
    const lx = x - cx * CHUNK, ly = y - cy * CHUNK;
    const left = lx === 0, right = lx === CHUNK - 1, top = ly === 0, bot = ly === CHUNK - 1;
    if (left) this.chunks.delete((cx - 1) + ',' + cy);
    if (right) this.chunks.delete((cx + 1) + ',' + cy);
    if (top) this.chunks.delete(cx + ',' + (cy - 1));
    if (bot) this.chunks.delete(cx + ',' + (cy + 1));
    if (left && top) this.chunks.delete((cx - 1) + ',' + (cy - 1));
    if (right && top) this.chunks.delete((cx + 1) + ',' + (cy - 1));
    if (left && bot) this.chunks.delete((cx - 1) + ',' + (cy + 1));
    if (right && bot) this.chunks.delete((cx + 1) + ',' + (cy + 1));
  },
  setQuality(name) {
    const v = QUALITY[name] || 3;
    if (v === SS) return;
    SS = v;
    this.chunks.clear();
  },

  // ---- генерация ----
  lootSpots: [],

  generate(seed) {
    this.lootSpots = [];
    const n1 = makeNoise1(seed), n2 = makeNoise1(seed + 7), n3 = makeNoise1(seed + 31);
    const nc = makeNoise2(seed + 99);
    this.tex = makeNoise2(seed + 555);
    const rand = mulberry32(seed + 5);
    this.cells.fill(M.AIR);

    for (let x = 0; x < WW; x++) {
      const z = zoneAtCell(x);
      // у каждой локации свой характер рельефа
      const amp = z.id === 'waste' ? 0.35 : z.id === 'mine' ? 0.8 : z.id === 'city' ? 0 : 0.9;
      let h = 78 + (n1(x / 90) * 16 + n2(x / 28) * 5 + n3(x / 9) * 1.6) * amp;
      this.surface[x] = Math.round(h);
    }
    // сглаживание, чтобы не было пилы и ступеней, на которых цепляешься
    for (let pass = 0; pass < 5; pass++) {
      const cp = this.surface.slice();
      for (let x = 1; x < WW - 1; x++) this.surface[x] = Math.round((cp[x - 1] + cp[x] * 2 + cp[x + 1]) / 4);
    }

    for (let x = 0; x < WW; x++) {
      const s = this.surface[x];
      for (let y = s; y < WH; y++) {
        const d = y - s;
        let m;
        if (d === 0) m = M.GRASS;
        else if (d < 4 + Math.floor(n2(x / 14) * 2)) m = M.DIRT;
        else if (d < 14 + Math.floor(n1(x / 40) * 5)) m = M.CLAY;
        else m = M.STONE;
        this.cells[this.idx(x, y)] = m;
      }
    }

    // пещерные системы глубоко — их не выкопать, они уже есть
    for (let x = 0; x < WW; x++) {
      for (let y = 150; y < WH - 4; y++) {
        const v = nc(x / 46, y / 30) + nc(x / 17, y / 13) * 0.4;
        if (v > 0.34) this.cells[this.idx(x, y)] = M.AIR;
      }
    }

    // рудные жилы
    const veins = [
      { m: M.COAL, count: 220, minY: 16, len: 26 },
      { m: M.IRON, count: 150, minY: 34, len: 20 },
      { m: M.COPPER, count: 120, minY: 26, len: 18 }
    ];
    for (const v of veins) {
      for (let i = 0; i < v.count; i++) {
        let x = Math.floor(rand() * WW);
        let y = this.surface[x] + v.minY + Math.floor(rand() * (WH - this.surface[x] - v.minY - 6));
        let ang = rand() * Math.PI * 2;
        const len = 6 + rand() * v.len;
        for (let s = 0; s < len; s++) {
          ang += (rand() - 0.5) * 0.8;
          x += Math.cos(ang); y += Math.sin(ang);
          const r = 1 + rand() * 1.6;
          for (let dx = -2; dx <= 2; dx++) for (let dy = -2; dy <= 2; dy++) {
            if (dx * dx + dy * dy > r * r) continue;
            const px = Math.round(x) + dx, py = Math.round(y) + dy;
            if (this.get(px, py) === M.STONE) this.cells[this.idx(px, py)] = v.m;
          }
        }
      }
    }

    // лужи в низинах
    for (let x = 6; x < WW - 6; x++) {
      const s = this.surface[x];
      if (s > this.surface[x - 5] + 2 && s > this.surface[x + 5] + 2) {
        const depth = 2 + Math.floor(rand() * 2);
        for (let dx = -4; dx <= 4; dx++) {
          const px = x + dx;
          if (Math.abs(this.surface[px] - s) > 2) continue;
          for (let dy = 0; dy < depth; dy++) this.cells[this.idx(px, s - dy)] = M.WATER;
        }
        x += 8;
      }
    }

    const waste = ZONES.find(z => z.id === 'waste');
    this.spawnX = Math.floor((waste.x0 + waste.x1) / 2);
    this.buildRuin(this.spawnX);
    this.spawnY = this.surface[this.spawnX] - 1;

    this.dressZones(rand);
    this.chunks.clear();
  },

  // наполнение локаций: у каждой свой характер
  dressZones(rand) {
    for (const z of ZONES) {
      if (z.id === 'forest') {
        for (let x = z.x0 + 6; x < z.x1 - 6; x++) {
          if (rand() < 0.16 && Math.abs(this.surface[x] - this.surface[x + 3]) < 3) { this.tree(x, this.surface[x] - 1, rand); x += 5; }
          else if (rand() < 0.05) this.bush(x, this.surface[x] - 1, rand);
        }
      } else if (z.id === 'waste') {
        // ни одного дерева: только обломки и сухие кусты
        for (let x = z.x0 + 6; x < z.x1 - 6; x++) {
          if (Math.abs(x - this.spawnX) < 28) continue;
          if (rand() < 0.035) this.debris(x, this.surface[x] - 1, rand);
          else if (rand() < 0.03) this.bush(x, this.surface[x] - 1, rand);
        }
        this.buildRuin(z.x0 + 90, true);
        this.buildRuin(z.x1 - 80, true);
      } else if (z.id === 'dead') {
        for (let x = z.x0 + 4; x < z.x1 - 4; x++) {
          const s = this.surface[x];
          if (rand() < 0.35) this.cells[this.idx(x, s)] = M.ASH;
          if (rand() < 0.07) this.debris(x, s - 1, rand);
        }
        // руины ставим с запасом, чтобы стены не налезали и не запирали проходы
        for (let i = 0; i < 5; i++) this.buildRuin(z.x0 + 60 + i * 96, i % 2 === 1);
      } else if (z.id === 'mine') {
        for (let x = z.x0 + 4; x < z.x1 - 4; x++) {
          const s = this.surface[x];
          // камень выходит на поверхность, руда видна сразу
          for (let y = s; y < s + 6; y++) this.cells[this.idx(x, y)] = M.STONE;
          if (rand() < 0.02) this.cells[this.idx(x, s + 1 + Math.floor(rand() * 3))] = rand() < 0.5 ? M.IRON : M.COAL;
          if (rand() < 0.05) this.debris(x, s - 1, rand);
        }
        this.buildShaft(Math.floor((z.x0 + z.x1) / 2));
      } else if (z.id === 'city') {
        this.buildCity(z);
      } else if (z.id === 'towers') {
        // пять высоток разной высоты, между ними — битый бетон
        const gapW = Math.floor((z.x1 - z.x0) / 5);
        for (let i = 0; i < 5; i++) {
          const tx = z.x0 + Math.floor(gapW * (i + 0.5));
          this.buildSkyscraper(tx, 5 + i % 4, 9001 + i * 137);
        }
        for (let x = z.x0 + 2; x < z.x1 - 2; x++) {
          if (rand() < 0.12) this.debris(x, this.surface[x] - 1, rand);
          if (rand() < 0.2) this.cells[this.idx(x, this.surface[x])] = M.ASH;
        }
      }
    }
    // одна высотка-ориентир в мёртвой зоне
    const dz = ZONES.find(z => z.id === 'dead');
    this.buildSkyscraper(dz.x1 - 120, 6, 4242);
    // ничейные полосы между локациями — редкий сухостой и обломки
    for (let x = 8; x < WW - 8; x++) {
      if (zoneAtCell(x).id !== 'gap') continue;
      if (rand() < 0.02) this.bush(x, this.surface[x] - 1, rand);
      else if (rand() < 0.008) this.debris(x, this.surface[x] - 1, rand);
    }
  },

  bush(x, y, rand) {
    const h = 3 + Math.floor(rand() * 3);
    for (let i = 0; i < h; i++) {
      const w = rand() < 0.5 ? 1 : 2;
      for (let dx = 0; dx <= w; dx++) if (this.get(x + dx, y - i) === M.AIR && rand() < 0.7) this.cells[this.idx(x + dx, y - i)] = M.LEAF;
    }
  },

  // руины небоскрёба: этажи через 8 частиц, сквозная лестничная шахта,
  // обрушенная верхушка. Ящики с оружием на этажах, пулемёт — на верхнем
  buildSkyscraper(cx, floors, seed) {
    const rand = mulberry32(seed);
    const base = this.surface[cx];
    const w = 24 + Math.floor(rand() * 12);
    const x0 = cx - Math.floor(w / 2), x1 = x0 + w;
    const FH = 12;              // высота этажа: под потолком должно быть просторно
    for (let x = x0 - 3; x <= x1 + 3; x++) {
      if (!this.inside(x, 0)) continue;
      for (let y = base - 1; y > 8; y--) if (this.get(x, y) !== M.AIR) this.cells[this.idx(x, y)] = M.AIR;
      this.surface[x] = base;
      this.cells[this.idx(x, base)] = M.CONCRETE;
    }
    const shaftX = x0 + 2;
    let topFloorY = base;
    for (let f = 0; f < floors; f++) {
      const fy = base - f * FH;
      if (fy < 16) break;
      topFloorY = fy;
      const ruin = f / floors;
      // плита этажа с провалами — чем выше, тем хуже
      for (let x = x0; x < x1; x++) {
        if (f > 0 && rand() < ruin * 0.45) continue;
        this.cells[this.idx(x, fy)] = M.CONCRETE;
        if (rand() < 0.28) this.cells[this.idx(x, fy + 1)] = M.REBAR;
      }
      for (let y = fy - 1; y > fy - FH; y--) {
        for (const wxx of [x0, x1 - 1]) {
          if (rand() < 0.12 + ruin * 0.4) continue;
          this.cells[this.idx(wxx, y)] = M.CONCRETE;
        }
        // внутренние колонны — фоновые: видно, но ходить не мешают
        for (let x = x0 + 9; x < x1 - 2; x += 9) {
          if (rand() < 0.25 + ruin * 0.3) continue;
          this.cells[this.idx(x, y)] = M.BG_METAL;
        }
        this.cells[this.idx(shaftX, y)] = M.LADDER;
        this.cells[this.idx(shaftX - 1, y)] = M.AIR;
        this.cells[this.idx(shaftX + 1, y)] = M.AIR;
      }
      // сквозной проём под лестницу
      for (const dx of [-1, 0, 1]) this.cells[this.idx(shaftX + dx, fy)] = dx === 0 ? M.LADDER : M.AIR;
      for (let i = 0; i < w * 0.3; i++) {
        const x = x0 + 1 + Math.floor(rand() * (w - 2));
        if (rand() < 0.45 && World.get(x, fy - 2) === M.AIR) this.cells[this.idx(x, fy - 1)] = rand() < 0.6 ? M.CONCRETE : M.BG_METAL;
      }
      if (f > 0 && f % 2 === 0) this.lootSpots.push({ x: x0 + 5 + Math.floor(rand() * (w - 10)), y: fy - 1, kind: 'tower' });
    }
    this.lootSpots.push({ x: x0 + Math.floor(w / 2), y: topFloorY - 1, kind: 'tower_top' });
    // торчащая арматура на срезе
    for (let x = x0; x < x1; x++) {
      if (rand() < 0.6) continue;
      if (Math.abs(x - shaftX) <= 1) continue;                 // шахту не перекрываем
      const h = 1 + Math.floor(rand() * 4);
      for (let i = 0; i < h; i++) this.cells[this.idx(x, topFloorY - 1 - i)] = M.REBAR;
    }
    // финальная зачистка шахты: непрерывная лестница от земли до верха,
    // иначе подъём упирается в арматуру под перекрытием
    for (let y = base - 1; y >= topFloorY - 1; y--) {
      this.cells[this.idx(shaftX, y)] = M.LADDER;
      this.cells[this.idx(shaftX - 1, y)] = M.AIR;
      this.cells[this.idx(shaftX + 1, y)] = M.AIR;
    }
  },

  // старый шахтный ствол: широкий, с лестницей на всю глубину
  buildShaft(cx) {
    const top = this.surface[cx];
    for (let y = top; y < 150; y++) {
      for (let dx = -2; dx <= 2; dx++) this.cells[this.idx(cx + dx, y)] = M.AIR;
      this.cells[this.idx(cx, y)] = M.LADDER;
      this.cells[this.idx(cx + 1, y)] = M.LADDER;
      if (y % 12 === 0) for (let dx = -3; dx <= 3; dx++) if (dx < 0 || dx > 1) this.cells[this.idx(cx + dx, y)] = M.PLANK;
    }
    // мостки над стволом: в дыру не проваливаешься случайно, спуск — по лестнице
    for (const dx of [-1, 1]) this.cells[this.idx(cx + dx, top)] = M.PLANK;
    // рама над входом
    for (let dx = -3; dx <= 3; dx++) this.cells[this.idx(cx + dx, top - 6)] = M.PLANK;
    for (const dx of [-3, 3]) for (let y = top - 6; y < top; y++) this.cells[this.idx(cx + dx, y)] = M.PLANK;
  },

  // мирный город в духе Rust: постройки из дерева и профлиста, вышка, склад,
  // рынок под навесами. Ломать нельзя — зона защищена
  buildCity(z) {
    const rand = mulberry32(777);
    const base = this.surface[Math.floor((z.x0 + z.x1) / 2)];
    this.flatten(z.x0, z.x1, base, 12);
    for (let x = z.x0; x <= z.x1; x++) {
      for (let y = base; y < base + 3; y++) this.cells[this.idx(x, y)] = M.CONCRETE;
      this.surface[x] = base;
    }
    const set = (x, y, m) => { if (this.inside(x, y)) this.cells[this.idx(x, y)] = m; };

    // ---- внешний периметр: профлист на деревянном каркасе ----
    for (const wx of [z.x0 + 3, z.x1 - 4]) {
      for (let y = base - 1; y > base - 20; y--) {
        set(wx, y, M.METAL); set(wx + 1, y, M.METAL);
        if ((base - y) % 5 === 0) { set(wx - 1, y, M.WALL_W); set(wx + 2, y, M.WALL_W); }
      }
      // зубцы наверху
      for (let dx = -1; dx <= 2; dx++) set(wx + dx, base - 20, M.WALL_W);
      set(wx, base - 22, M.METAL); set(wx + 1, base - 22, M.METAL);
      // ворота: из города можно выйти пешком
      for (let dx = -1; dx <= 2; dx++) for (let y = base - 1; y > base - 15; y--) set(wx + dx, y, M.AIR);
      for (let dx = -2; dx <= 3; dx++) set(wx + dx, base - 15, M.WALL_W);
    }

    // ---- жилые постройки: стоят на земле, внутрь входишь не пригибаясь ----
    // проём 4 частицы в ширину и 12 в высоту — застрять негде
    const shack = (bx, bw, bh, floors) => {
      let fy = base;                                   // пол первого этажа — сама земля
      for (let f = 0; f < floors; f++) {
        // обшивка внутри: помещение выглядит помещением, но ходить не мешает
        for (let x = bx + 2; x < bx + bw - 2; x++) {
          for (let y = fy - 1; y > fy - bh; y--) if (this.get(x, y) === M.AIR) set(x, y, M.BG_WOOD);
        }
        for (let y = fy - 1; y > fy - bh; y--) {
          set(bx, y, M.WALL_W); set(bx + 1, y, M.WALL_W);
          set(bx + bw - 2, y, M.WALL_W); set(bx + bw - 1, y, M.WALL_W);
          if ((fy - y) % 5 === 0) { set(bx + 2, y, M.METAL); set(bx + bw - 3, y, M.METAL); }
        }
        // перекрытие между этажами с широким люком под лестницу
        if (f < floors - 1) {
          for (let x = bx; x < bx + bw; x++) {
            if (x >= bx + bw - 8 && x <= bx + bw - 5) continue;   // люк
            set(x, fy - bh, M.FLOOR_W);
          }
          for (let y = fy - bh; y < fy; y++) set(bx + bw - 7, y, M.LADDER);
        }
        fy -= bh;
      }
      // крыша с широким свесом
      for (let x = bx - 3; x < bx + bw + 3; x++) { set(x, fy, M.ROOF_W); set(x, fy + 1, M.ROOF_W); }
      // сквозные проёмы с двух сторон: дом можно пройти насквозь, не застревая
      for (let y = base - 1; y > base - 13; y--) {
        for (let dx = 0; dx < 4; dx++) set(bx + dx, y, M.AIR);
        for (let dx = bw - 4; dx < bw; dx++) set(bx + dx, y, M.AIR);
      }
      // окна
      for (let x = bx + 6; x < bx + bw - 5; x += 6) {
        for (let dy = 0; dy < 3; dy++) { set(x, base - 8 - dy, M.AIR); set(x + 1, base - 8 - dy, M.AIR); }
        set(x, base - 11, M.PLANK); set(x + 1, base - 11, M.PLANK);
      }
    };

    shack(z.x0 + 26, 34, 21, 2);
    shack(z.x0 + 96, 26, 20, 1);
    shack(z.x0 + 176, 38, 22, 2);
    shack(z.x1 - 76, 30, 20, 1);

    // ---- склад из профлиста: высокий, с воротами ----
    const wx0 = z.x0 + 136, ww = 36;
    for (let x = wx0; x < wx0 + ww; x++) {
      for (let y = base - 1; y > base - 18; y--) {
        if (x === wx0 || x === wx0 + ww - 1) set(x, y, M.METAL);
        else if (this.get(x, y) === M.AIR) set(x, y, M.BG_METAL);
      }
    }
    for (let i = 0; i < ww / 2; i++) {
      const ry = base - 18 - Math.floor(i * 0.45);
      set(wx0 + i, ry, M.METAL); set(wx0 + ww - 1 - i, ry, M.METAL);
    }
    // ворота с двух сторон: склад проходится насквозь
    for (let y = base - 1; y > base - 14; y--) {
      for (let dx = 0; dx < 5; dx++) set(wx0 + dx, y, M.AIR);
      for (let dx = ww - 5; dx < ww; dx++) set(wx0 + dx, y, M.AIR);
    }

    // ---- смотровая вышка: лестница по центру, площадки по краям ----
    // опоры — брёвна: сквозь них можно пройти, они не запирают
    const tx = z.x1 - 30;
    for (let y = base - 1; y > base - 34; y--) {
      set(tx, y, M.TRUNK); set(tx + 7, y, M.TRUNK);
      set(tx + 3, y, M.LADDER); set(tx + 4, y, M.LADDER);
      if ((base - y) % 8 === 0) { set(tx + 1, y, M.PLANK); set(tx + 2, y, M.PLANK); set(tx + 5, y, M.PLANK); set(tx + 6, y, M.PLANK); }
    }
    for (let dx = -3; dx <= 10; dx++) { set(tx + dx, base - 34, M.ROOF_W); set(tx + dx, base - 33, M.ROOF_W); }
    for (let dx = 3; dx <= 4; dx++) { set(tx + dx, base - 34, M.LADDER); set(tx + dx, base - 33, M.LADDER); }

    // ---- рынок: навесы высоко над головой, ничего не задеваешь ----
    const mx0 = Math.floor((z.x0 + z.x1) / 2) - 30;
    for (let i = 0; i < 4; i++) {
      const sx = mx0 + 8 + i * 16;
      // столбы навеса — брёвна от земли, проходимые насквозь
      for (let y = base - 1; y > base - 16; y--) { set(sx, y, M.TRUNK); set(sx + 10, y, M.TRUNK); }
      for (let dx = -2; dx <= 12; dx++) { set(sx + dx, base - 16, M.ROOF_W); set(sx + dx, base - 17, M.ROOF_W); }
      // прилавок под навесом
      for (let dx = 2; dx <= 8; dx++) set(sx + dx, base - 4, M.PLANK);
    }
    // низкий палисад: перешагивается, не запирает
    for (const fx of [mx0 - 8, mx0 + 68]) for (let y = base - 1; y > base - 4; y--) set(fx, y, M.TRUNK);
  },

  tree(x, y, rand) {
    const h = 12 + Math.floor(rand() * 10);
    const lean = (rand() - 0.5) * 0.35;
    let fx = x;
    for (let i = 0; i < h; i++) {
      fx += lean * 0.25;
      const w = i < h * 0.7 ? 2 : 1;
      for (let dx = 0; dx <= w; dx++) this.cells[this.idx(Math.round(fx) + dx, y - i)] = M.TRUNK;
      // сухие ветки
      if (i > h * 0.45 && rand() < 0.35) {
        const dir = rand() < 0.5 ? -1 : 1;
        const bl = 2 + Math.floor(rand() * 4);
        for (let b = 1; b <= bl; b++) {
          const bx = Math.round(fx) + dir * b, by = y - i - Math.floor(b * 0.5);
          if (this.get(bx, by) === M.AIR) this.cells[this.idx(bx, by)] = M.TRUNK;
        }
      }
    }
    // редкая мёртвая листва шапкой
    const cy = y - h, cr = 4 + Math.floor(rand() * 3);
    for (let dx = -cr - 2; dx <= cr + 2; dx++) for (let dy = -cr; dy <= cr - 1; dy++) {
      const d = Math.hypot(dx * 0.75, dy);
      if (d < cr && rand() < 0.62 - d / (cr * 2.2)) {
        const px = Math.round(fx) + dx, py = cy + dy;
        if (this.get(px, py) === M.AIR) this.cells[this.idx(px, py)] = M.LEAF;
      }
    }
  },

  debris(x, y, rand) {
    // не выше двух частиц, чтобы обломки перешагивались
    const w = 2 + Math.floor(rand() * 4), h = 1 + Math.floor(rand() * 2);
    for (let dx = 0; dx < w; dx++) for (let dy = 0; dy < h; dy++) {
      if (rand() < 0.25) continue;
      if (this.get(x + dx, y - dy) === M.AIR) this.cells[this.idx(x + dx, y - dy)] = rand() < 0.7 ? M.CONCRETE : M.REBAR;
    }
  },

  // ровная площадка с пологими подходами: провалы засыпаются, обрывов не остаётся
  flatten(x0, x1, base, ramp) {
    for (let x = x0 - ramp; x <= x1 + ramp; x++) {
      if (!this.inside(x, 0)) continue;
      const outside = x < x0 ? (x0 - x) : x > x1 ? (x - x1) : 0;
      const t = outside === 0 ? 1 : 1 - outside / (ramp + 1);
      const target = Math.round(lerp(this.surface[x], base, t));
      // срезаем всё выше новой поверхности
      for (let y = target - 1; y > target - 24; y--) if (this.get(x, y) !== M.AIR) this.cells[this.idx(x, y)] = M.AIR;
      // засыпаем всё ниже, чтобы не было ям
      for (let y = target; y < target + 6; y++) {
        const m = this.get(x, y);
        if (m === M.AIR || m === M.WATER) this.cells[this.idx(x, y)] = y === target ? M.DIRT : M.CLAY;
      }
      this.cells[this.idx(x, target)] = M.DIRT;
      this.surface[x] = target;
    }
  },

  // разрушенный дом: пол, две стены-огрызка, часть крыши
  buildRuin(cx, small) {
    // крыша поднята выше роста человека, чтобы не биться в неё головой
    const w = small ? 16 : 24, h = small ? 12 : 15;
    const base = this.surface[cx];
    this.flatten(Math.round(cx - w / 2 - 2), Math.round(cx + w / 2 + 2), base, 7);
    const rand = mulberry32(cx * 7919);
    const x0 = Math.round(cx - w / 2), x1 = Math.round(cx + w / 2);
    // пол
    for (let x = x0; x <= x1; x++) this.cells[this.idx(x, base)] = M.PLANK;
    // стены с провалами
    for (let y = base - 1; y > base - h; y--) {
      const frac = (base - y) / h;
      if (rand() < 0.15 + frac * 0.5) continue;
      this.cells[this.idx(x0, y)] = M.CONCRETE;
      if (rand() > 0.25 + frac * 0.4) this.cells[this.idx(x0 - 1, y)] = M.CONCRETE;
      if (rand() < 0.8 - frac * 0.5) this.cells[this.idx(x1, y)] = M.CONCRETE;
    }
    // остатки крыши слева
    for (let x = x0; x < x0 + w * 0.55; x++) {
      if (rand() < 0.2) continue;
      this.cells[this.idx(x, base - h)] = M.CONCRETE;
      if (rand() < 0.5) this.cells[this.idx(x, base - h + 1)] = M.REBAR;
    }
    // мусор на полу
    for (let i = 0; i < w; i++) {
      const x = x0 + 1 + Math.floor(rand() * (w - 2));
      if (rand() < 0.5) this.cells[this.idx(x, base - 1)] = rand() < 0.6 ? M.CONCRETE : M.PLANK;
    }
    if (!small) {
      // кровать-каркас: место пробуждения слева внутри
      for (let x = x0 + 2; x <= x0 + 5; x++) this.cells[this.idx(x, base - 1)] = M.PLANK;
    }
    // проломы в обеих стенах: из руин всегда можно выйти в полный рост
    for (const wx of [x0 - 1, x1]) {
      for (let dx = 0; dx < 3; dx++) for (let y = base - 1; y > base - 13; y--) {
        this.cells[this.idx(wx + dx, y)] = M.AIR;
      }
    }
    // внутри и вокруг вычищаем всё, что висит на высоте роста: пройти можно везде
    for (let x = x0 - 4; x <= x1 + 4; x++) {
      const isWall = x === x0 || x === x0 - 1 || x === x1 || x === x1 + 1;
      for (let y = base - 1; y > base - 11; y--) {
        const m = this.get(x, y);
        if (m === M.AIR) continue;
        if (isWall && y < base - 2) continue;                       // стены оставляем
        if (m === M.CONCRETE || m === M.REBAR) this.cells[this.idx(x, y)] = M.AIR;
      }
    }
  },

  // ---- отрисовка ----
  // порода рисуется со сглаженными краями: там, где две стороны частицы открыты,
  // угол скругляется — массив выглядит породой, а не сеткой кубов
  chunkCanvas(cx, cy) {
    const key = cx + ',' + cy;
    let c = this.chunks.get(key);
    if (c) return c;
    c = document.createElement('canvas');
    const S = CELL * SS;
    c.width = CHUNK * S; c.height = CHUNK * S;
    const g = c.getContext('2d');
    const bx = cx * CHUNK, by = cy * CHUNK;
    const tex = this.tex;

    for (let ly = 0; ly < CHUNK; ly++) {
      for (let lx = 0; lx < CHUNK; lx++) {
        const x = bx + lx, y = by + ly;
        const m = this.get(x, y);
        if (m === M.AIR) continue;
        const mi = MATS[m];
        const hv = hash2(x, y), hv2 = hash2(x * 3 + 1, y * 5 + 2);
        if (mi.door || mi.struct !== undefined) continue;   // двери и постройки рисует свой слой
        if (mi.bg) {
          const S0 = CELL * SS, px0 = lx * S0, py0 = ly * S0;
          const sh0 = this.tex(x / 8, y / 8) * mi.var;
          g.fillStyle = rgb(mi.c[0] + sh0, mi.c[1] + sh0, mi.c[2] + sh0);
          g.fillRect(px0, py0, S0, S0);
          if (mi.bg === 'wood') {
            g.fillStyle = 'rgba(20,12,6,0.45)';
            g.fillRect(px0, py0 + ((y % 3 === 0) ? 0 : S0 - SS), S0, SS * 0.7);
            if (hv > 0.7) { g.fillStyle = 'rgba(120,92,60,0.12)'; g.fillRect(px0 + S0 * 0.4, py0, SS * 0.7, S0); }
          } else {
            g.fillStyle = 'rgba(255,255,255,0.05)';
            g.fillRect(px0 + S0 * 0.25, py0, SS * 0.8, S0);
            g.fillStyle = 'rgba(0,0,0,0.25)';
            g.fillRect(px0 + S0 * 0.65, py0, SS * 0.8, S0);
          }
          // затемнение по краю помещения
          g.fillStyle = 'rgba(0,0,0,0.22)';
          if (!this.solid(x, y - 1) && this.get(x, y - 1) !== m) g.fillRect(px0, py0, S0, SS);
          continue;
        }
        if (mi.build) { this.drawBuildCell(g, lx, ly, x, y, m, mi, hv, hv2); continue; }
        if (mi.metal) { this.drawMetalCell(g, lx, ly, x, y, mi, hv, hv2); continue; }
        if (mi.ladder) {
          const px0 = lx * CELL * SS, py0 = ly * CELL * SS, S0 = CELL * SS;
          g.strokeStyle = '#7a5a34'; g.lineWidth = SS * 1.3;
          g.beginPath();
          g.moveTo(px0 + S0 * 0.22, py0); g.lineTo(px0 + S0 * 0.22, py0 + S0);
          g.moveTo(px0 + S0 * 0.78, py0); g.lineTo(px0 + S0 * 0.78, py0 + S0);
          g.stroke();
          g.strokeStyle = '#a07a44'; g.lineWidth = SS * 1.1;
          g.beginPath(); g.moveTo(px0 + S0 * 0.16, py0 + S0 * 0.5); g.lineTo(px0 + S0 * 0.84, py0 + S0 * 0.5); g.stroke();
          continue;
        }
        // многослойный шум: крупные пятна породы + средняя зернистость + мелкое зерно
        let sh = tex(x / 30, y / 24) * mi.var * 1.5
               + tex(x / 9, y / 7) * mi.var * 0.9
               + tex(x / 3.2, y / 3.2) * mi.var * 0.45
               + (hv - 0.5) * mi.var * 0.3;
        // слоистость: осадочные полосы читаются на глубине
        if (mi.crack || mi.ore || m === M.DIRT || m === M.CLAY) {
          sh += Math.sin(y * 0.42 + tex(x / 60, y / 60) * 5) * mi.var * 0.28;
        }

        const up = this.solid(x, y - 1) || this.get(x, y - 1) === m;
        const dn = this.solid(x, y + 1) || this.get(x, y + 1) === m;
        const lf = this.solid(x - 1, y) || this.get(x - 1, y) === m;
        const rt = this.solid(x + 1, y) || this.get(x + 1, y) === m;
        // мягкое затенение по глубине массива (окружение 3×3)
        let nb8 = 0;
        for (let ddy = -1; ddy <= 1; ddy++) for (let ddx = -1; ddx <= 1; ddx++) {
          if (!ddx && !ddy) continue;
          if (this.solid(x + ddx, y + ddy)) nb8++;
        }
        sh -= (nb8 - 5) * 1.6;
        // направленный свет: сверху-слева светлее, снизу-справа темнее
        if (!up) sh += 9; if (!lf) sh += 4; if (!dn) sh -= 7; if (!rt) sh -= 3;

        const px = lx * S, py = ly * S;
        const R = S * 0.55;
        const rTL = (!up && !lf) ? R : 0, rTR = (!up && !rt) ? R : 0;
        const rBR = (!dn && !rt) ? R : 0, rBL = (!dn && !lf) ? R : 0;

        const cr = mi.c[0] + sh, cg = mi.c[1] + sh, cb = mi.c[2] + sh;
        g.fillStyle = rgb(cr, cg, cb);
        g.beginPath();
        g.roundRect(px, py, S, S, [rTL, rTR, rBR, rBL]);
        g.fill();

        if (!mi.water && !mi.leaf) {
          if (!up) {
            g.fillStyle = 'rgba(255,248,226,0.14)';
            g.beginPath(); g.roundRect(px, py, S, S * 0.2, [rTL, rTR, 0, 0]); g.fill();
          }
          if (!dn) {
            g.fillStyle = 'rgba(0,0,0,0.18)';
            g.beginPath(); g.roundRect(px, py + S * 0.78, S, S * 0.22, [0, 0, rBR, rBL]); g.fill();
          }
        }

        // мелкие камешки и зерно — есть у всех минеральных материалов
        if (mi.crack || m === M.DIRT || m === M.CLAY || mi.ore || mi.ash) {
          const pebbles = 2 + Math.floor(hv2 * 3);
          for (let i = 0; i < pebbles; i++) {
            const h3 = hash2(x * 7 + i * 31, y * 13 - i * 17), h4 = hash2(y * 11 + i * 7, x * 19 + i);
            if (h3 < 0.42) continue;
            const r = S * (0.04 + h4 * 0.07);
            const l = (h3 - 0.5) * 26;
            g.fillStyle = rgb(cr + l + 8, cg + l + 6, cb + l + 4);
            g.beginPath(); g.ellipse(px + h4 * S, py + h3 * S, r, r * 0.82, h3 * 4, 0, 7); g.fill();
            g.fillStyle = 'rgba(0,0,0,0.16)';
            g.beginPath(); g.ellipse(px + h4 * S + r * 0.3, py + h3 * S + r * 0.5, r * 0.8, r * 0.5, h3 * 4, 0, 7); g.fill();
          }
        }
        // корешки в земле
        if (m === M.DIRT && hv2 > 0.7) {
          g.strokeStyle = 'rgba(52,38,24,0.4)'; g.lineWidth = SS * 0.55; g.lineCap = 'round';
          g.beginPath();
          g.moveTo(px + hv * S, py);
          g.quadraticCurveTo(px + hv * S + (hv2 - 0.5) * S, py + S * 0.5, px + hv2 * S, py + S);
          g.stroke();
        }
        if (mi.grass && !up) {
          const gtop = g.createLinearGradient(px, py, px, py + S * 0.5);
          gtop.addColorStop(0, rgb(112 + hv * 32, 126 + hv * 26, 62));
          gtop.addColorStop(1, rgb(76 + hv * 20, 88 + hv * 18, 44));
          g.fillStyle = gtop;
          g.beginPath(); g.roundRect(px, py, S, S * 0.46, [rTL, rTR, 0, 0]); g.fill();
          // травинки: разной высоты и наклона, часть сухая
          g.lineCap = 'round';
          for (let i = 0; i < 5; i++) {
            const h3 = hash2(x * 17 + i * 13, y * 5 - i * 7), h4 = hash2(y * 23 + i, x * 3 + i * 11);
            if (h3 < 0.3) continue;
            const dry = h4 > 0.72;
            g.strokeStyle = dry ? rgb(126 + h4 * 30, 112 + h4 * 20, 62) : rgb(78 + h3 * 44, 98 + h3 * 36, 44);
            g.lineWidth = SS * (0.5 + h4 * 0.5);
            const gx = px + (0.1 + i * 0.2) * S + h3 * SS;
            const hh = S * (0.4 + h3 * 0.75);
            g.beginPath();
            g.moveTo(gx, py + S * 0.3);
            g.quadraticCurveTo(gx + (h3 - 0.5) * S * 0.4, py - hh * 0.5, gx + (h3 - 0.5) * S * 0.9, py - hh);
            g.stroke();
          }
        }
        if (mi.ore) {
          const n = 2 + Math.floor(hv2 * 3);
          for (let i = 0; i < n; i++) {
            const h3 = hash2(x * 11 + i, y * 17 - i), h4 = hash2(y * 13 + i, x * 7 - i);
            const r = S * (0.1 + h3 * 0.14);
            const ox = px + h3 * S, oy = py + h4 * S;
            const gr = g.createRadialGradient(ox - r * 0.3, oy - r * 0.3, 0, ox, oy, r);
            gr.addColorStop(0, rgb(mi.ore[0] + 46, mi.ore[1] + 46, mi.ore[2] + 46));
            gr.addColorStop(0.6, rgb(mi.ore[0] + 6, mi.ore[1] + 6, mi.ore[2] + 6));
            gr.addColorStop(1, rgb(mi.ore[0] - 22, mi.ore[1] - 22, mi.ore[2] - 22));
            g.fillStyle = gr;
            g.beginPath(); g.ellipse(ox, oy, r, r * 0.76, h4 * 3, 0, 7); g.fill();
            // блик на грани кристалла
            g.fillStyle = 'rgba(255,255,255,0.34)';
            g.beginPath(); g.ellipse(ox - r * 0.32, oy - r * 0.3, r * 0.26, r * 0.16, h4 * 3, 0, 7); g.fill();
          }
        }
        if (mi.crack) {
          // ветвящиеся трещины
          if (hv2 > 0.55) {
            g.strokeStyle = 'rgba(16,16,20,0.32)'; g.lineWidth = SS * 0.55;
            const sx0 = px + hv * S, sy0 = py + hv2 * S * 0.3;
            g.beginPath();
            g.moveTo(sx0, sy0);
            g.lineTo(sx0 + (hv2 - 0.5) * S * 0.6, sy0 + S * 0.45);
            g.lineTo(sx0 + (hv - 0.5) * S * 0.8, sy0 + S * 0.9);
            g.stroke();
          }
          if (hv > 0.8) {
            g.fillStyle = 'rgba(255,255,255,0.07)';
            g.beginPath(); g.ellipse(px + hv2 * S, py + hv * S, S * 0.2, S * 0.1, hv * 3, 0, 7); g.fill();
          }
        }
        if (mi.bark) {
          // продольные волокна и сучки
          for (let i = 0; i < 3; i++) {
            const h3 = hash2(x * 13 + i * 29, y * 7 + i);
            g.strokeStyle = h3 > 0.5 ? 'rgba(28,20,14,0.34)' : 'rgba(168,138,98,0.16)';
            g.lineWidth = SS * (0.4 + h3 * 0.5);
            const bxp = px + (0.15 + i * 0.32 + h3 * 0.1) * S;
            g.beginPath();
            g.moveTo(bxp, py);
            g.quadraticCurveTo(bxp + (h3 - 0.5) * SS * 2, py + S * 0.5, bxp + (h3 - 0.5) * SS * 3, py + S);
            g.stroke();
          }
          if (hv > 0.9) {
            g.fillStyle = 'rgba(40,28,18,0.5)';
            g.beginPath(); g.ellipse(px + S * 0.5, py + S * 0.5, S * 0.2, S * 0.16, 0, 0, 7); g.fill();
            g.fillStyle = 'rgba(110,84,56,0.5)';
            g.beginPath(); g.ellipse(px + S * 0.5, py + S * 0.5, S * 0.1, S * 0.08, 0, 0, 7); g.fill();
          }
        }
        if (mi.plank) {
          g.fillStyle = 'rgba(30,20,12,0.34)';
          g.fillRect(px, py + ((y % 2) === 0 ? 0 : S - SS), S, SS * 0.8);
          g.fillStyle = 'rgba(255,240,210,0.08)';
          g.fillRect(px, py + ((y % 2) === 0 ? SS * 0.8 : S - SS * 1.8), S, SS * 0.7);
          // волокно доски
          g.strokeStyle = 'rgba(60,40,24,0.16)'; g.lineWidth = SS * 0.4;
          g.beginPath();
          g.moveTo(px, py + S * (0.3 + hv * 0.4));
          g.quadraticCurveTo(px + S * 0.5, py + S * (0.3 + hv2 * 0.4), px + S, py + S * (0.3 + hv * 0.4));
          g.stroke();
          if (hv > 0.85) { g.fillStyle = 'rgba(40,28,16,0.4)'; g.beginPath(); g.arc(px + S * 0.5, py + S * 0.5, SS * 0.6, 0, 7); g.fill(); }
        }
        if (mi.tilled) {
          g.fillStyle = 'rgba(0,0,0,0.24)'; g.fillRect(px, py + S * 0.3, S, SS);
          g.fillStyle = 'rgba(136,102,66,0.24)'; g.fillRect(px, py, S, SS);
          for (let i = 0; i < 3; i++) {
            const h3 = hash2(x * 5 + i, y * 3 - i);
            g.fillStyle = 'rgba(90,64,40,0.35)';
            g.beginPath(); g.ellipse(px + h3 * S, py + S * (0.5 + h3 * 0.4), S * 0.08, S * 0.05, 0, 0, 7); g.fill();
          }
        }
        if (mi.ash) {
          g.fillStyle = 'rgba(255,255,255,0.10)';
          for (let i = 0; i < 5; i++) {
            const h3 = hash2(x * 3 + i * 17, y * 5 + i * 7), h4 = hash2(y * 7 + i, x * 11 - i);
            g.fillRect(px + h3 * S, py + h4 * S, SS * 0.8, SS * 0.8);
          }
        }
        if (mi.leaf) {
          // мёртвая листва: пучки листьев с прожилками
          for (let i = 0; i < 4; i++) {
            const h3 = hash2(x * 23 + i * 13, y * 29 - i * 7), h4 = hash2(y * 19 + i, x * 31 - i * 3);
            const lx2 = px + h3 * S, ly2 = py + h4 * S, ang = h3 * 6;
            g.globalAlpha = 0.9;
            g.fillStyle = rgb(mi.c[0] + sh + h3 * 30 - 6, mi.c[1] + sh + h3 * 22, mi.c[2] + sh + h4 * 14);
            g.beginPath(); g.ellipse(lx2, ly2, S * 0.3, S * 0.15, ang, 0, 7); g.fill();
            g.globalAlpha = 0.5;
            g.strokeStyle = 'rgba(40,44,26,0.5)'; g.lineWidth = SS * 0.3;
            g.beginPath();
            g.moveTo(lx2 - Math.cos(ang) * S * 0.28, ly2 - Math.sin(ang) * S * 0.28);
            g.lineTo(lx2 + Math.cos(ang) * S * 0.28, ly2 + Math.sin(ang) * S * 0.28);
            g.stroke();
            g.globalAlpha = 1;
          }
        }
        if (mi.water) {
          g.globalAlpha = 0.8;
          const wg = g.createLinearGradient(px, py, px, py + S);
          wg.addColorStop(0, rgb(cr + 14, cg + 20, cb + 16));
          wg.addColorStop(1, rgb(cr - 10, cg - 6, cb - 8));
          g.fillStyle = wg; g.fillRect(px, py, S, S);
          g.globalAlpha = 1;
          if (!up) {
            g.fillStyle = 'rgba(190,240,214,0.22)'; g.fillRect(px, py, S, SS * 1.2);
            g.fillStyle = 'rgba(255,255,255,0.10)';
            g.beginPath(); g.ellipse(px + hv * S, py + SS * 2, S * 0.24, SS * 0.6, 0, 0, 7); g.fill();
          }
        }
      }
    }
    if (this.chunks.size > 260) this.chunks.clear();
    this.chunks.set(key, c);
    return c;
  },

  // деревянная постройка ставится деталями 2×2 частицы, поэтому рисунок
  // строится с учётом места частицы внутри детали — доски и черепица не рвутся
  drawBuildCell(g, lx, ly, x, y, m, mi, hv, hv2) {
    const S = CELL * SS;
    const px = lx * S, py = ly * S;
    const sub = { x: x & 1, y: y & 1 };            // позиция внутри детали
    const tex = this.tex;
    const sh = tex(x / 6, y / 6) * mi.var + (hv - 0.5) * mi.var * 0.5;
    const c = [mi.c[0] + sh, mi.c[1] + sh, mi.c[2] + sh];

    if (mi.build === 'wall') {
      // вертикальные доски с брусом-обвязкой
      const wg = g.createLinearGradient(px, py, px + S, py);
      wg.addColorStop(0, rgb(c[0] - 8, c[1] - 6, c[2] - 4));
      wg.addColorStop(0.5, rgb(c[0] + 8, c[1] + 6, c[2] + 4));
      wg.addColorStop(1, rgb(c[0] - 10, c[1] - 8, c[2] - 6));
      g.fillStyle = wg; g.fillRect(px, py, S, S);
      // стык между досками
      g.fillStyle = 'rgba(38,26,16,0.4)';
      g.fillRect(px + (sub.x ? S - SS * 0.8 : 0), py, SS * 0.8, S);
      g.fillStyle = 'rgba(255,240,210,0.07)';
      g.fillRect(px + (sub.x ? S - SS * 1.7 : SS * 0.8), py, SS * 0.7, S);
      // волокно
      g.strokeStyle = 'rgba(70,46,26,0.2)'; g.lineWidth = SS * 0.35;
      for (let i = 0; i < 2; i++) {
        const h3 = hash2(x * 7 + i, y * 11 + i);
        g.beginPath();
        g.moveTo(px + (0.3 + i * 0.35 + h3 * 0.1) * S, py);
        g.quadraticCurveTo(px + (0.3 + i * 0.35) * S + (h3 - 0.5) * SS * 2, py + S * 0.5,
          px + (0.3 + i * 0.35 + h3 * 0.1) * S, py + S);
        g.stroke();
      }
      // гвозди по углам детали
      if (!sub.y) {
        g.fillStyle = 'rgba(60,62,66,0.85)';
        g.beginPath(); g.arc(px + (sub.x ? S * 0.7 : S * 0.3), py + S * 0.28, SS * 0.5, 0, 7); g.fill();
        g.fillStyle = 'rgba(200,200,200,0.25)';
        g.beginPath(); g.arc(px + (sub.x ? S * 0.7 : S * 0.3) - SS * 0.15, py + S * 0.28 - SS * 0.15, SS * 0.2, 0, 7); g.fill();
      }
      if (!this.solid(x, y - 1)) { g.fillStyle = 'rgba(255,248,226,0.14)'; g.fillRect(px, py, S, SS * 1.2); }
      if (!this.solid(x, y + 1)) { g.fillStyle = 'rgba(0,0,0,0.2)'; g.fillRect(px, py + S - SS * 1.2, S, SS * 1.2); }
    } else if (mi.build === 'floor') {
      // горизонтальные половицы
      const fg = g.createLinearGradient(px, py, px, py + S);
      fg.addColorStop(0, rgb(c[0] + 12, c[1] + 10, c[2] + 6));
      fg.addColorStop(1, rgb(c[0] - 12, c[1] - 10, c[2] - 8));
      g.fillStyle = fg; g.fillRect(px, py, S, S);
      g.fillStyle = 'rgba(38,26,16,0.42)';
      g.fillRect(px, py + (sub.y ? S - SS * 0.8 : 0), S, SS * 0.8);
      g.fillStyle = 'rgba(255,240,210,0.10)';
      g.fillRect(px, py + (sub.y ? S - SS * 1.7 : SS * 0.8), S, SS * 0.7);
      // поперечный стык половиц через каждые 4 частицы
      if ((x & 3) === (sub.y ? 3 : 0)) { g.fillStyle = 'rgba(38,26,16,0.3)'; g.fillRect(px + S - SS * 0.7, py, SS * 0.7, S); }
      g.strokeStyle = 'rgba(70,46,26,0.18)'; g.lineWidth = SS * 0.35;
      g.beginPath();
      g.moveTo(px, py + S * (0.35 + hv * 0.3));
      g.quadraticCurveTo(px + S * 0.5, py + S * (0.35 + hv2 * 0.3), px + S, py + S * (0.35 + hv * 0.3));
      g.stroke();
      if (hv > 0.88) { g.fillStyle = 'rgba(40,28,16,0.45)'; g.beginPath(); g.arc(px + S * 0.5, py + S * 0.5, SS * 0.6, 0, 7); g.fill(); }
    } else {
      // крыша: черепица с нахлёстом
      g.fillStyle = rgb(c[0] - 6, c[1] - 6, c[2] - 4);
      g.fillRect(px, py, S, S);
      const row = sub.y;
      const off = row ? S * 0.5 : 0;
      for (let i = -1; i <= 1; i++) {
        const tx = px + off + i * S * 0.75;
        const tg = g.createLinearGradient(tx, py, tx, py + S * 0.62);
        tg.addColorStop(0, rgb(c[0] + 16, c[1] + 12, c[2] + 8));
        tg.addColorStop(1, rgb(c[0] - 14, c[1] - 12, c[2] - 8));
        g.fillStyle = tg;
        g.beginPath(); g.roundRect(tx, py, S * 0.72, S * 0.66, [0, 0, SS * 2, SS * 2]); g.fill();
        g.strokeStyle = 'rgba(34,22,14,0.45)'; g.lineWidth = SS * 0.4;
        g.beginPath(); g.roundRect(tx, py, S * 0.72, S * 0.66, [0, 0, SS * 2, SS * 2]); g.stroke();
      }
      g.fillStyle = 'rgba(0,0,0,0.22)';
      g.fillRect(px, py + S * 0.66, S, S * 0.34);
      if (!this.solid(x, y - 1)) { g.fillStyle = 'rgba(255,246,220,0.12)'; g.fillRect(px, py, S, SS); }
    }
  },

  // профлист: гофра с ржавыми потёками — стены построек в городе
  drawMetalCell(g, lx, ly, x, y, mi, hv, hv2) {
    const S = CELL * SS;
    const px = lx * S, py = ly * S;
    const sh = this.tex(x / 10, y / 10) * mi.var + (hv - 0.5) * 6;
    const c = [mi.c[0] + sh, mi.c[1] + sh, mi.c[2] + sh];
    g.fillStyle = rgb(c[0], c[1], c[2]);
    g.fillRect(px, py, S, S);
    // гофра
    for (let i = 0; i < 3; i++) {
      const gx = px + i * S / 3;
      const rg = g.createLinearGradient(gx, 0, gx + S / 3, 0);
      rg.addColorStop(0, 'rgba(0,0,0,0.22)');
      rg.addColorStop(0.45, 'rgba(255,255,255,0.14)');
      rg.addColorStop(1, 'rgba(0,0,0,0.22)');
      g.fillStyle = rg; g.fillRect(gx, py, S / 3, S);
    }
    // ржавчина
    if (hv2 > 0.55) {
      g.fillStyle = 'rgba(150,86,44,' + (0.12 + hv2 * 0.22) + ')';
      g.beginPath(); g.ellipse(px + hv * S, py + hv2 * S, S * 0.3, S * 0.42, 0, 0, 7); g.fill();
    }
    // заклёпки по краю листа
    if ((y & 3) === 0) {
      g.fillStyle = 'rgba(60,62,66,0.8)';
      g.beginPath(); g.arc(px + S * 0.5, py + S * 0.3, SS * 0.5, 0, 7); g.fill();
    }
    if (!this.solid(x, y - 1)) { g.fillStyle = 'rgba(255,250,235,0.16)'; g.fillRect(px, py, S, SS); }
  },

  // город трогать нельзя — ни копать, ни строить
  protectedAt(cx) { return zoneAtCell(cx).id === 'city'; },

  draw(ctx, view) {
    const CS = CHUNK * CELL;
    const c0 = Math.floor(view.x / CS), c1 = Math.floor((view.x + view.w) / CS);
    const r0 = Math.floor(view.y / CS), r1 = Math.floor((view.y + view.h) / CS);
    for (let cy = r0; cy <= r1; cy++) {
      for (let cx = c0; cx <= c1; cx++) {
        if (cx < 0 || cy < 0 || cx * CHUNK >= WW || cy * CHUNK >= WH) continue;
        ctx.drawImage(this.chunkCanvas(cx, cy), 0, 0, CHUNK * CELL * SS, CHUNK * CELL * SS,
          cx * CS, cy * CS, CS, CS);
      }
    }
  },

  // копание: круглая кисть или квадрат (кирка выгрызает сразу 9×9 частиц)
  digAt(cx, cy, radius, square) {
    const drops = {};
    const r2 = radius * radius;
    for (let dy = -radius; dy <= radius; dy++) {
      for (let dx = -radius; dx <= radius; dx++) {
        if (!square && dx * dx + dy * dy > r2) continue;
        const x = cx + dx, y = cy + dy;
        if (this.protectedAt(x)) continue;
        const m = this.get(x, y);
        if (m === M.AIR || m === M.WATER || MATS[m].door) continue;
        const mi = MATS[m];
        if (mi.drop) drops[mi.drop] = (drops[mi.drop] || 0) + 1;
        if (Math.random() < 0.35) Particles.burst(x * CELL + CELL / 2, y * CELL + CELL / 2, mi.c, 2);
        this.set(x, y, M.AIR);
      }
    }
    return drops;
  },

  // самая твёрдая порода под кистью определяет скорость
  hardnessAt(cx, cy, radius) {
    let hardest = 0, any = false;
    for (let dy = -radius; dy <= radius; dy++) for (let dx = -radius; dx <= radius; dx++) {
      if (dx * dx + dy * dy > radius * radius) continue;
      const m = this.get(cx + dx, cy + dy);
      if (m === M.AIR || m === M.WATER) continue;
      any = true;
      hardest = Math.max(hardest, MATS[m].hard);
    }
    return any ? hardest : 0;
  },

  // поддержка: есть ли рядом порода, чтобы поставить блок
  hasNeighbour(x, y) {
    return this.solid(x - 1, y) || this.solid(x + 1, y) || this.solid(x, y - 1) || this.solid(x, y + 1);
  },

  // опора в радиусе: лестницу вешают в прокопанном стволе, где вплотную ничего нет
  hasSupportNear(x, y, range) {
    for (let dy = -range; dy <= range; dy++) for (let dx = -range; dx <= range; dx++) {
      if (this.solid(x + dx, y + dy)) return true;
    }
    return false;
  },

  // лестница продолжается от другой лестницы
  ladderNear(x, y) {
    return this.get(x, y - 1) === M.LADDER || this.get(x, y + 1) === M.LADDER;
  },

  isUnderground(px, py) {
    const x = clamp(Math.floor(px / CELL), 0, WW - 1);
    return py / CELL > this.surface[x] + 3;
  },

  // есть ли крыша над точкой (для защиты от радиации в помещении)
  hasRoof(px, py) {
    const x = clamp(Math.floor(px / CELL), 0, WW - 1);
    const y = Math.floor(py / CELL);
    for (let yy = y - 1; yy > Math.max(0, y - 22); yy--) if (this.solid(x, yy)) return true;
    return false;
  }
};
