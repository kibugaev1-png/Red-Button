// game.js — цикл, камера, фон, свет, взаимодействие
'use strict';

const Game = {
  canvas: null, ctx: null, lightCanvas: null, lctx: null,
  cam: { x: 0, y: 0 }, zoom: 2.1,
  time: DAY_LEN * 0.32, day: 1,
  shake: 0, hint: '',
  introT: 0, introDone: false,
  last: 0, acc: 0,

  init() {
    this.canvas = document.getElementById('game');
    this.canvas.width = UI.W; this.canvas.height = UI.H;
    this.ctx = this.canvas.getContext('2d');
    this.lightCanvas = document.createElement('canvas');
    // свет рисуем в половинном разрешении и растягиваем: вдвое меньше заливки
    this.lightCanvas.width = UI.W / 2; this.lightCanvas.height = UI.H / 2;
    this.lctx = this.lightCanvas.getContext('2d');
    bindInput(this.canvas);
    this.resize();
    addEventListener('resize', () => this.resize());
    requestAnimationFrame(t => this.frame(t));
  },

  resize() {
    const s = Math.min(innerWidth / UI.W, innerHeight / UI.H);
    this.canvas.style.width = (UI.W * s) + 'px';
    this.canvas.style.height = (UI.H * s) + 'px';
  },

  start() {
    World.generate(Math.floor(Math.random() * 1e9));
    Particles.list.length = 0; Floaters.list.length = 0; Bullets.list.length = 0;
    Zombies.list.length = 0; Drops.list.length = 0;
    Machines.list.length = 0; Machines.torches.length = 0;
    Player.dead = false;
    Player.hp = 100; Player.food = 240; Player.water = 220; Player.rad = 6;
    Player.mask = false; Player.filterWear = 100;
    Player.init();
    this.time = DAY_LEN * 0.34; this.day = 1;
    this.introT = 0; this.introDone = false;
    UI.screen = null;
    UI.held = null;

    City.build();
    Home.flag = null;
    Doors.list.length = 0;
    Structures.reset();
    Nodes.seed();

    // стартовый набор строителя: план, молоток и материал на первый дом
    Player.inv.add('plan', 1);
    Player.inv.add('hammer', 1);
    Player.inv.add('wood', 300);
    Player.inv.add('stone', 60);
    Player.inv.add('ladder', 12);
    Player.inv.add('home_flag', 1);
    for (const m of Missions.list) { m.state = 0; m.from = 0; }

    // стартовый лут в пустоши: противогаз рядом и два ящика без повторов
    const sx = World.spawnX, sy = World.surface[sx];
    Drops.add((sx + 3) * CELL, (sy - 6) * CELL, 'gasmask', 1);
    Drops.addCrate(sx - 7, sy, [['axe', 1], ['pick', 1], ['bandage', 3]], false);
    Drops.addCrate(sx + 9, sy, [['pistol', 1], ['ammo9', 10], ['filter', 2], ['canteen', 1], ['can', 1]], false);

    // мёртвая зона: военные ящики со стволами и картой пещер
    const dz = ZONES.find(z => z.id === 'dead');
    const armyLoot = [
      [['shotgun', 1], ['buckshot', 24]],
      [['smg', 1], ['zinc9', 1]],
      [['medkit', 2], ['splint', 2], ['antirad', 3]],
      [['filter', 4], ['scrap', 14], ['iron', 10]],
      [['map_caves', 1], ['zinc9', 1], ['medkit', 1]],
      [['ammo545', 90], ['ammo762', 60], ['bandage', 4]]
    ];
    for (let i = 0; i < armyLoot.length; i++) {
      const ax = dz.x0 + 60 + i * 74;
      Drops.addCrate(ax, World.surface[ax], armyLoot[i], true);
    }
    // руины небоскрёбов: оружие по этажам, на самом верху — пулемёт с цинком
    const towerLoot = [
      [['rifle', 1], ['ammo545', 60]],
      [['sniper', 1], ['ammo762', 24]],
      [['revolver', 1], ['ammo9', 30]],
      [['pistol', 1], ['ammo9', 40], ['bandage', 2]],
      [['ammo545', 90], ['scrap', 12]],
      [['club', 1], ['ammo762', 40], ['medkit', 1]],
      [['zinc9', 1], ['filter', 2]],
      [['ammo762', 80], ['splint', 1]]
    ];
    let ti = 0;
    for (const s of World.lootSpots) {
      if (s.kind === 'tower_top') {
        Drops.addCrate(s.x, s.y + 1, [['mg', 1], ['zinc762', 1], ['ammo762', 100]], true);
      } else if (s.kind === 'tower') {
        Drops.addCrate(s.x, s.y + 1, towerLoot[ti++ % towerLoot.length], true);
      }
    }

    // шахта: ящик горняка
    const mz = ZONES.find(z => z.id === 'mine');
    const mx = mz.x0 + 40;
    Drops.addCrate(mx, World.surface[mx], [['drill', 1], ['coal', 20], ['torch', 8]], false);

    this.cam.x = Player.x - UI.W / (2 * this.zoom);
    this.cam.y = Player.y - UI.H / (2 * this.zoom);
  },

  // переход в другую локацию: не мгновенно — дорога отнимает время, еду и воду
  travel(zone) {
    const from = Player.x;
    const cx = Math.floor((zone.x0 + zone.x1) / 2);
    const km = Math.abs(cx * CELL - from) / CELL / 420;
    Player.x = cx * CELL + 4;
    Player.y = (World.surface[cx] - 2) * CELL;
    Player.vx = 0; Player.vy = 0; Player.fallStart = null;
    Player.food = clamp(Player.food - km * 6, 1, FOOD_MAX);
    Player.water = clamp(Player.water - km * 8, 1, WATER_MAX);
    this.time += km * 6;
    if (this.time > DAY_LEN) { this.time -= DAY_LEN; this.day++; }
    Zombies.list.length = 0;
    this.cam.x = Player.x - UI.W / (2 * this.zoom);
    this.cam.y = Player.y - UI.H / (2 * this.zoom);
    UI.screen = null;
    Player.say('Переход: ' + zone.name);
    this.travelFade = 1;
  },

  sleep() {
    this.time = DAY_LEN * 0.3; this.day++;
    Player.hp = clamp(Player.hp + 14, 0, 100);
    Player.food = clamp(Player.food - 40, 1, FOOD_MAX);
    Player.water = clamp(Player.water - 46, 1, WATER_MAX);
    Zombies.list.length = 0;
    Player.say('Утро. Ты спал в своей кровати');
  },

  // возрождение на своей кровати: мир и вещи остаются, тело подлечено
  respawnAtBed() {
    const bed = Structures.bed() || Machines.bed();
    if (!bed) return false;
    Player.dead = false;
    const bx = bed.gx !== undefined ? bed.gx : bed.x;
    const by = bed.gy !== undefined ? bed.gy + bed.h : bed.y;
    Player.x = (bx + bed.w / 2) * CELL;
    Player.y = (by - 1) * CELL;
    Player.vx = 0; Player.vy = 0; Player.fallStart = null;
    Player.hp = 45; Player.food = Math.max(Player.food, 110); Player.water = Math.max(Player.water, 110);
    Player.rad = 0;
    for (const l of LIMBS) { const b = Player.body[l.id]; b.w = Math.min(b.w, 1); b.bleed = false; }
    Zombies.list.length = 0;
    this.time = DAY_LEN * 0.3; this.day++;
    this.cam.x = Player.x - UI.W / (2 * this.zoom);
    this.cam.y = Player.y - UI.H / (2 * this.zoom);
    UI.screen = null;
    Player.say('Ты очнулся в своей кровати');
    return true;
  },

  nightAmount() {
    const t = this.time / DAY_LEN;               // 0 — полночь, 0.5 — полдень
    const d = Math.cos((t - 0.5) * Math.PI * 2); // 1 в полдень, −1 в полночь
    return clamp((0.3 - d) / 1.05, 0, 1);        // 1 — глубокая ночь
  },

  toScreen(wx, wy) {
    return { x: (wx - this.cam.x) * this.zoom, y: (wy - this.cam.y) * this.zoom };
  },

  fps: 60, frameAcc: 0, frameN: 0, quality: 'high', autoQuality: true, qCooldown: 3,

  // если кадры стали дорогими — сами снижаем качество текстур, чтобы не жгло машину
  trackPerf(dt) {
    this.frameAcc += dt; this.frameN++;
    if (this.frameAcc >= 0.5) {
      this.fps = this.frameN / this.frameAcc;
      this.frameAcc = 0; this.frameN = 0;
      if (this.qCooldown > 0) { this.qCooldown -= 0.5; return; }
      if (!this.autoQuality) return;
      if (this.fps < 42 && this.quality !== 'low') {
        this.quality = this.quality === 'high' ? 'mid' : 'low';
        World.setQuality(this.quality);
        this.qCooldown = 4;
        Player.say('Качество текстур снижено — так плавнее');
      } else if (this.fps > 57 && this.quality === 'mid') {
        this.quality = 'high'; World.setQuality('high'); this.qCooldown = 8;
      }
    }
  },

  frame(t) {
    const dt = Math.min(0.05, (t - this.last) / 1000 || 0.016);
    this.last = t;
    this.trackPerf(dt);
    this.update(dt);
    this.draw();
    Input.endFrame();
    requestAnimationFrame(tt => this.frame(tt));
  },

  update(dt) {
    // смена экрана даёт короткую защиту от клика, прилетевшего вместе с открытием
    if (UI.screen !== this.lastScreen) { UI.guard = 0.2; this.lastScreen = UI.screen; }
    if (UI.guard > 0) UI.guard -= dt;

    // экраны
    if (UI.screen === 'menu' || UI.screen === 'custom') return;
    if (Input.once('Escape')) {
      if (UI.screen) { UI.screen = null; UI.fromMenu = false; }
      else UI.screen = 'options';
    }
    if (Input.once('KeyI') || Input.once('Tab')) UI.screen = UI.screen === 'inv' ? null : 'inv';
    if (Input.once('KeyB')) UI.screen = UI.screen === 'body' ? null : 'body';
    if (Input.once('KeyC')) UI.screen = UI.screen === 'craft' ? null : 'craft';
    if (Input.once('KeyM')) UI.screen = UI.screen === 'map' ? null : 'map';
    if (Input.once('KeyF')) UI.screen = UI.screen === 'skills' ? null : 'skills';
    for (let i = 0; i < 6; i++) if (Input.once('Digit' + (i + 1))) Player.hotbar = i;
    if (Input.wheel) Player.hotbar = (Player.hotbar + (Input.wheel > 0 ? 1 : 5)) % 6;

    if (Player.dead) { UI.screen = 'dead'; }
    const paused = UI.screen !== null;

    // мировые координаты мыши
    Input.wx = this.cam.x + Input.mx / this.zoom;
    Input.wy = this.cam.y + Input.my / this.zoom;

    if (!paused) {
      this.time += dt;
      if (this.time > DAY_LEN) { this.time -= DAY_LEN; this.day++; }
      if (!this.introDone) this.introT += dt;

      Player.update(dt);
      Zombies.update(dt);
      Bullets.update(dt);
      Machines.update(dt);
      Drops.update(dt);
      City.update(dt);
      Home.update(dt);
      Doors.update(dt);
      Structures.update(dt);
      Nodes.update(dt);

      // взаимодействие
      this.hint = '';
      const d = Drops.nearest(Player.x, Player.y - 20, 60);
      const m = Machines.nearest(Player.x, Player.y - 20, 70);
      const c = City.nearest(Player.x, Player.y - 20, 60);
      const sdoor = Structures.list.find(st => st.part.hole === 'door' &&
        dist(Player.x, Player.y - 20, (st.gx + st.w / 2) * CELL, (st.gy + st.h / 2) * CELL) < 46);
      const door = Doors.nearest(Player.x, Player.y - 20, 46);
      if (sdoor) {
        this.hint = sdoor.open ? 'E — закрыть дверь' : 'E — открыть дверь';
        if (Input.once('KeyE')) Structures.toggleDoor(sdoor);
      } else if (door) {
        this.hint = door.open ? 'E — закрыть дверь' : 'E — открыть дверь';
        if (Input.once('KeyE')) Doors.toggle(door);
      } else if (c) {
        this.hint = c.kind === 'trader' ? 'E — торговать' : 'E — доска заданий';
        if (Input.once('KeyE')) UI.screen = c.kind === 'trader' ? 'shop' : 'board';
      } else if (d) {
        this.hint = d.crate ? 'E — вскрыть ' + (d.military ? 'военный ящик' : 'ящик') : 'E — взять ' + ITEMS[d.id].name + (d.n > 1 ? ' ×' + d.n : '');
        if (Input.once('KeyE')) {
          Drops.take(d);
          if (!d.crate && d.id === 'gasmask' && !Player.mask) Player.wearMask();
        }
      } else if (m) {
        const names = { workbench: 'верстак (крафт)', workbench2: 'верстак 2 ур. (крафт)', workbench3: 'верстак 3 ур. (крафт)',
          furnace: 'печь (затопить)', campfire: 'костёр (готовка)', drill: 'автобур', farm: 'грядка', bed: 'кровать (спать)' };
        this.hint = 'E — ' + (names[m.type] || m.type);
        if (Input.once('KeyE')) Machines.interact(m);
      } else if (Structures.bed() && dist(Player.x, Player.y - 20,
          (Structures.bed().gx + Structures.bed().w / 2) * CELL, (Structures.bed().gy + 1) * CELL) < 52) {
        this.hint = 'E — спать до утра';
        if (Input.once('KeyE')) this.sleep();
      } else if (Home.nearFlag(Player.x, Player.y - 20, 44)) {
        // снятие дома — только с Shift, чтобы не сорвать флажок случайно
        this.hint = 'Shift + E — снять флажок дома';
        if (Input.isDown('ShiftLeft') && Input.once('KeyE')) Home.take();
      } else {
        // рядом трогать нечего — тогда E просто применяет то, что в руке
        const hi = Player.handItem();
        if (hi && ['food', 'drink', 'med', 'mask', 'filter', 'zinc'].includes(hi.type)) {
          this.hint = 'E — ' + (hi.type === 'drink' ? 'выпить' : hi.type === 'food' ? 'съесть' : 'применить') + ': ' + hi.name;
          if (Input.once('KeyE')) Player.useRight(hi);
        }
      }
    }

    Particles.update(dt);
    Floaters.update(dt);
    if (this.shake > 0) this.shake = Math.max(0, this.shake - dt * 14);

    // камера с плавным следованием и лёгким опережением от курсора
    const tx = Player.x + (Input.wx - Player.x) * 0.12 - UI.W / (2 * this.zoom);
    const ty = (Player.y - 26) + (Input.wy - Player.y) * 0.1 - UI.H / (2 * this.zoom);
    this.cam.x += (tx - this.cam.x) * Math.min(1, dt * 7);
    this.cam.y += (ty - this.cam.y) * Math.min(1, dt * 7);
    this.cam.x = clamp(this.cam.x, 0, WW * CELL - UI.W / this.zoom);
    this.cam.y = clamp(this.cam.y, -200, WH * CELL - UI.H / this.zoom);
  },

  // ---- фон: небо, солнце, пыль, силуэты города ----
  drawBackground(g) {
    const night = this.nightAmount();
    const top = [lerp(96, 12, night), lerp(120, 14, night), lerp(140, 22, night)];
    const bot = [lerp(196, 26, night), lerp(160, 24, night), lerp(112, 30, night)];
    const mid = [lerp(206, 20, night), lerp(168, 20, night), lerp(120, 28, night)];
    const gr = g.createLinearGradient(0, 0, 0, UI.H);
    gr.addColorStop(0, rgb(top[0], top[1], top[2]));
    gr.addColorStop(0.46, rgb(lerp(top[0], mid[0], 0.7), lerp(top[1], mid[1], 0.7), lerp(top[2], mid[2], 0.7)));
    gr.addColorStop(0.72, rgb(mid[0], mid[1], mid[2]));          // золотая полоса у горизонта
    gr.addColorStop(1, rgb(bot[0], bot[1], bot[2]));
    g.fillStyle = gr; g.fillRect(0, 0, UI.W, UI.H);

    // светило: восход слева в 6:00, зенит в полдень, закат справа в 18:00
    const tt = this.time / DAY_LEN;
    const sunA = (tt - 0.25) * Math.PI * 2;
    const sx = UI.W * (0.5 - 0.58 * Math.cos(sunA));
    const sy = UI.H * 0.78 - UI.H * 0.72 * Math.sin(sunA);
    const sr = 110;
    const sg = g.createRadialGradient(sx, sy, 0, sx, sy, sr);
    if (night < 0.6) { sg.addColorStop(0, 'rgba(255,232,180,0.55)'); sg.addColorStop(1, 'rgba(255,200,120,0)'); }
    else { sg.addColorStop(0, 'rgba(200,220,255,0.35)'); sg.addColorStop(1, 'rgba(150,180,255,0)'); }
    g.fillStyle = sg; g.beginPath(); g.arc(sx, sy, sr, 0, 7); g.fill();
    // диск и объёмные лучи — то самое «солнце сквозь пыль»
    if (night < 0.55) {
      const daylight = 1 - night / 0.55;
      g.fillStyle = 'rgba(255,244,214,' + (0.5 * daylight) + ')';
      g.beginPath(); g.arc(sx, sy, 26, 0, 7); g.fill();
      g.save();
      g.globalCompositeOperation = 'lighter';
      g.translate(sx, sy);
      const rot = this.time * 0.02;
      for (let i = 0; i < 9; i++) {
        const a = rot + i * (Math.PI * 2 / 9);
        const wdt = 0.05 + hash2(i, 3) * 0.09;
        const len = 620 + hash2(i, 9) * 420;
        const rg = g.createLinearGradient(0, 0, Math.cos(a) * len, Math.sin(a) * len);
        rg.addColorStop(0, 'rgba(255,226,164,' + (0.16 * daylight) + ')');
        rg.addColorStop(1, 'rgba(255,200,120,0)');
        g.fillStyle = rg;
        g.beginPath();
        g.moveTo(0, 0);
        g.lineTo(Math.cos(a - wdt) * len, Math.sin(a - wdt) * len);
        g.lineTo(Math.cos(a + wdt) * len, Math.sin(a + wdt) * len);
        g.fill();
      }
      g.restore();
    }

    // звёзды
    if (night > 0.35) {
      g.globalAlpha = (night - 0.35) * 1.2;
      for (let i = 0; i < 90; i++) {
        const h = hash2(i * 13, 7), h2 = hash2(i * 7, 31);
        g.fillStyle = 'rgba(220,230,255,' + (0.3 + h * 0.7) + ')';
        g.fillRect((h * UI.W + this.cam.x * 0.02) % UI.W, h2 * UI.H * 0.55, 1.6, 1.6);
      }
      g.globalAlpha = 1;
    }

    // облака радиоактивной хмари
    g.globalAlpha = 0.2;
    for (let l = 0; l < 3; l++) {
      const off = (this.cam.x * (0.03 + l * 0.02)) % (UI.W + 400);
      for (let i = 0; i < 5; i++) {
        const h = hash2(l * 31 + i, 5);
        const cx = (i * 320 + h * 200 - off + UI.W + 400) % (UI.W + 400) - 200;
        const cy = 40 + l * 60 + h * 40;
        const cg = g.createRadialGradient(cx, cy, 0, cx, cy, 160);
        cg.addColorStop(0, 'rgba(' + (night > 0.5 ? '40,44,52' : '180,170,140') + ',0.5)');
        cg.addColorStop(1, 'rgba(0,0,0,0)');
        g.fillStyle = cg;
        g.beginPath(); g.ellipse(cx, cy, 170, 44, 0, 0, 7); g.fill();
      }
    }
    g.globalAlpha = 1;

    // дальние силуэты города (параллакс)
    const horizon = UI.H * 0.72;
    for (let layer = 0; layer < 2; layer++) {
      const par = 0.08 + layer * 0.12;
      const off = (this.cam.x * par) % 600;
      g.fillStyle = layer === 0
        ? 'rgba(' + (night > 0.5 ? '18,20,26' : '86,84,80') + ',0.55)'
        : 'rgba(' + (night > 0.5 ? '10,11,14' : '58,54,50') + ',0.75)';
      for (let seg = -1; seg < Math.ceil(UI.W / 600) + 1; seg++) {
        const bx = seg * 600 - off;
        const rand = mulberry32(1000 + layer * 77 + seg * 13);
        let x = bx;
        while (x < bx + 600) {
          const w = 22 + rand() * 60, h = 40 + rand() * (layer ? 150 : 90);
          const y = horizon - h + layer * 30;
          g.fillRect(x, y, w, h + 200);
          if (rand() < 0.3) g.fillRect(x + w * 0.4, y - 26, 4, 26);
          x += w + 6 + rand() * 24;
        }
      }
    }
    // пыльная дымка у горизонта
    const hz = g.createLinearGradient(0, horizon - 120, 0, horizon + 80);
    hz.addColorStop(0, 'rgba(0,0,0,0)');
    hz.addColorStop(1, night > 0.5 ? 'rgba(18,20,26,0.6)' : 'rgba(168,142,104,0.28)');
    g.fillStyle = hz; g.fillRect(0, horizon - 120, UI.W, 200);
  },

  // ---- свет: ночь + подземная тьма + источники ----
  drawLight(g) {
    const l = this.lctx;
    const night = this.nightAmount();
    // холст света вдвое меньше экрана — рисуем в тех же координатах через масштаб
    l.setTransform(0.5, 0, 0, 0.5, 0, 0);
    l.clearRect(0, 0, UI.W, UI.H);
    l.globalCompositeOperation = 'source-over';

    // базовая тьма ночи
    const nAlpha = night * 0.6;   // ночью темно, но силуэты читаются — лунный свет
    if (nAlpha > 0.01) { l.fillStyle = 'rgba(8,11,22,' + nAlpha + ')'; l.fillRect(0, 0, UI.W, UI.H); }

    // подземная тьма: три слоя, повторяющие рельеф — без вертикальных швов
    const step = 6;
    for (const [off, alpha] of [[10, 0.34], [70, 0.34], [150, 0.42]]) {
      l.fillStyle = 'rgba(4,4,7,' + alpha + ')';
      l.beginPath();
      let started = false;
      for (let sxp = 0; sxp <= UI.W + step; sxp += step) {
        const wx = this.cam.x + sxp / this.zoom;
        const cx = clamp(Math.floor(wx / CELL), 0, WW - 1);
        const sy = ((World.surface[cx] + 3) * CELL - this.cam.y) * this.zoom + off;
        if (!started) { l.moveTo(0, sy); started = true; }
        else l.lineTo(sxp, sy);
      }
      l.lineTo(UI.W, UI.H); l.lineTo(0, UI.H); l.closePath();
      l.fill();
    }

    // источники света вырезают тьму
    l.globalCompositeOperation = 'destination-out';
    const lights = Machines.lights().concat(City.lights());
    lights.push({ x: Player.x, y: Player.y - 26, r: 165, i: 0.85 });  // фонарь на поясе
    for (const s of lights) {
      const p = this.toScreen(s.x, s.y);
      const r = s.r * this.zoom * 0.5;
      if (p.x < -r || p.x > UI.W + r || p.y < -r || p.y > UI.H + r) continue;
      const gr = l.createRadialGradient(p.x, p.y, 0, p.x, p.y, r);
      gr.addColorStop(0, 'rgba(0,0,0,' + s.i + ')');
      gr.addColorStop(0.55, 'rgba(0,0,0,' + s.i * 0.45 + ')');
      gr.addColorStop(1, 'rgba(0,0,0,0)');
      l.fillStyle = gr;
      l.beginPath(); l.arc(p.x, p.y, r, 0, 7); l.fill();
    }
    l.globalCompositeOperation = 'source-over';

    // тёплая подсветка от огня
    for (const s of lights) {
      if (s.r < 100) continue;
      const p = this.toScreen(s.x, s.y);
      const r = s.r * this.zoom * 0.55;
      const gr = l.createRadialGradient(p.x, p.y, 0, p.x, p.y, r);
      gr.addColorStop(0, 'rgba(255,178,80,0.20)');
      gr.addColorStop(1, 'rgba(255,150,60,0)');
      l.fillStyle = gr; l.beginPath(); l.arc(p.x, p.y, r, 0, 7); l.fill();
    }

    g.drawImage(this.lightCanvas, 0, 0, UI.W / 2, UI.H / 2, 0, 0, UI.W, UI.H);
  },

  draw() {
    const g = this.ctx;
    g.setTransform(1, 0, 0, 1, 0, 0);
    g.imageSmoothingEnabled = true;

    if (UI.screen === 'menu') { UI.drawMenu(g); return; }
    if (UI.screen === 'custom') { UI.drawCustom(g); return; }

    this.drawBackground(g);

    // мир
    const shx = this.shake ? rnd(-this.shake, this.shake) : 0;
    const shy = this.shake ? rnd(-this.shake, this.shake) : 0;
    g.save();
    g.translate(shx, shy);
    g.scale(this.zoom, this.zoom);
    g.translate(-this.cam.x, -this.cam.y);
    const view = { x: this.cam.x, y: this.cam.y, w: UI.W / this.zoom, h: UI.H / this.zoom };

    World.draw(g, view);
    City.draw(g);
    Home.draw(g);
    Machines.draw(g);
    Nodes.draw(g);
    Structures.draw(g);
    Doors.draw(g);
    // призрак детали под курсором, когда в руке план
    const handIt = Player.handItem();
    if (handIt && handIt.type === 'plan' && !Player.dead) {
      this.ghost = Structures.drawGhost(g, PARTS[Player.planPart].id, Player.planTier);
    } else this.ghost = null;
    Drops.draw(g);
    Zombies.draw(g);

    // игрок
    if (!Player.dead) {
      const it = Player.handItem();
      g.fillStyle = 'rgba(0,0,0,0.3)';
      g.beginPath(); g.ellipse(Player.x, Player.y, 9, 2.4, 0, 0, 7); g.fill();
      drawHuman(g, Player.x, Player.y, Player.look, {
        face: Player.face, phase: Player.phase, moving: Math.abs(Player.vx) > 0.1,
        air: !Player.onGround, mask: Player.mask,
        dig: Player.digAnim,
        item: it ? (it.type === 'tool' ? (it.wood ? 'axe' : 'pick') : it.type === 'melee' ? 'club' : null) : null,
        aim: it && it.type === 'gun' ? it.kind : null,
        aimAng: Player.aimAng, recoil: Player.recoil
      });
    }

    Bullets.draw(g);
    Particles.draw(g);
    Floaters.draw(g);

    // рамка цели копания
    const it2 = Player.handItem();
    if (!Player.dead && (!it2 || it2.type !== 'gun')) {
      const cx = Math.floor(Input.wx / CELL), cy = Math.floor(Input.wy / CELL);
      if (dist(Player.x, Player.y - 28, Input.wx, Input.wy) < Player.reach()) {
        g.strokeStyle = 'rgba(240,232,200,0.55)'; g.lineWidth = 0.6;
        g.strokeRect(cx * CELL - CELL, cy * CELL - CELL, CELL * 3, CELL * 3);
      }
    }
    g.restore();

    this.drawLight(g);

    // прицел
    if (!Player.dead && UI.screen === null) {
      const it = Player.handItem();
      if (it && it.type === 'gun') {
        g.strokeStyle = 'rgba(255,230,180,0.8)'; g.lineWidth = 1.4;
        const sp = 6 + Player.recoil * 5;
        g.beginPath();
        g.moveTo(Input.mx - sp - 5, Input.my); g.lineTo(Input.mx - sp, Input.my);
        g.moveTo(Input.mx + sp, Input.my); g.lineTo(Input.mx + sp + 5, Input.my);
        g.moveTo(Input.mx, Input.my - sp - 5); g.lineTo(Input.mx, Input.my - sp);
        g.moveTo(Input.mx, Input.my + sp); g.lineTo(Input.mx, Input.my + sp + 5);
        g.stroke();
      }
    }

    // виньетка и «стекло противогаза»
    const vg = g.createRadialGradient(UI.W / 2, UI.H / 2, UI.H * 0.45, UI.W / 2, UI.H / 2, UI.H * 1.0);
    vg.addColorStop(0, 'rgba(0,0,0,0)');
    vg.addColorStop(1, 'rgba(0,0,0,0.34)');
    g.fillStyle = vg; g.fillRect(0, 0, UI.W, UI.H);
    if (Player.mask) {
      g.strokeStyle = 'rgba(18,22,18,0.30)'; g.lineWidth = 26;
      g.beginPath(); g.ellipse(UI.W / 2, UI.H / 2, UI.W * 0.505, UI.H * 0.55, 0, 0, 7); g.stroke();
      g.fillStyle = 'rgba(130,160,140,0.028)'; g.fillRect(0, 0, UI.W, UI.H);
    }
    // красный пульс при низком здоровье
    if (Player.hp < 35 && !Player.dead) {
      g.fillStyle = 'rgba(140,20,16,' + (0.10 + Math.sin(performance.now() / 220) * 0.05) * (1 - Player.hp / 35) + ')';
      g.fillRect(0, 0, UI.W, UI.H);
    }
    // радиационные помехи
    if (Player.rad > 40) {
      g.globalAlpha = (Player.rad - 40) / 200;
      for (let i = 0; i < 40; i++) {
        g.fillStyle = Math.random() < 0.5 ? '#b8d84a' : '#000';
        g.fillRect(Math.random() * UI.W, Math.random() * UI.H, rnd(2, 40), 1);
      }
      g.globalAlpha = 1;
    }

    if (!Player.dead) UI.drawHUD(g);
    if (!this.introDone && UI.screen === null) UI.drawIntro(g);

    if (UI.screen === 'map') UI.drawMap(g);
    else if (UI.screen === 'skills') UI.drawSkills(g);
    else if (UI.screen === 'shop') UI.drawShop(g);
    else if (UI.screen === 'board') UI.drawBoard(g);
    else if (UI.screen === 'inv') UI.drawInv(g);
    else if (UI.screen === 'body') UI.drawBody(g);
    else if (UI.screen === 'craft') UI.drawCraft(g);
    else if (UI.screen === 'options') UI.drawOptions(g);
    else if (UI.screen === 'dead') UI.drawDead(g);
  }
};

addEventListener('load', () => Game.init());
