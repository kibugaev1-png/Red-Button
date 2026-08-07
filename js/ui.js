// ui.js — меню, кастомизация, HUD, инвентарь, тело, крафт
'use strict';

const UI = {
  screen: 'menu',        // menu | custom | null | inv | craft | body | options | dead | intro
  held: null,            // предмет «в руке» при перетаскивании
  hot: [],               // зоны кликов текущего кадра
  tab: 'inv',
  guard: 0,              // пауза на клики после смены экрана
  pickedZone: null,
  W: 1280, H: 720,

  // ---- примитивы ----
  panel(g, x, y, w, h, title) {
    g.fillStyle = 'rgba(14,15,17,0.92)';
    g.beginPath(); g.roundRect(x, y, w, h, 10); g.fill();
    g.strokeStyle = 'rgba(190,180,150,0.22)'; g.lineWidth = 1;
    g.beginPath(); g.roundRect(x + 0.5, y + 0.5, w - 1, h - 1, 10); g.stroke();
    if (title) {
      g.fillStyle = '#cdc6ae'; g.font = '600 15px system-ui, sans-serif';
      g.fillText(title, x + 16, y + 26);
      g.fillStyle = 'rgba(190,180,150,0.16)'; g.fillRect(x + 14, y + 34, w - 28, 1);
    }
  },
  btn(g, x, y, w, h, label, active, danger) {
    // guard — короткая пауза после открытия экрана, чтобы клик «сквозь» не срабатывал
    const over = this.guard <= 0 && Input.mx > x && Input.mx < x + w && Input.my > y && Input.my < y + h;
    g.fillStyle = active ? 'rgba(150,138,90,0.30)' : over ? 'rgba(210,200,170,0.16)' : 'rgba(255,255,255,0.06)';
    g.beginPath(); g.roundRect(x, y, w, h, 7); g.fill();
    g.strokeStyle = danger ? 'rgba(190,70,60,0.7)' : over ? 'rgba(220,210,180,0.55)' : 'rgba(190,180,150,0.25)';
    g.lineWidth = 1; g.beginPath(); g.roundRect(x + 0.5, y + 0.5, w - 1, h - 1, 7); g.stroke();
    g.fillStyle = danger ? '#e0a09a' : over ? '#f2ecd8' : '#c9c2ac';
    g.font = '600 13px system-ui, sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
    g.fillText(label, x + w / 2, y + h / 2 + 1);
    g.textAlign = 'left'; g.textBaseline = 'alphabetic';
    return over && Input.mclick;
  },
  text(g, t, x, y, col, size, weight, align) {
    g.fillStyle = col || '#c9c2ac';
    g.font = (weight || '400') + ' ' + (size || 13) + 'px system-ui, sans-serif';
    g.textAlign = align || 'left';
    g.fillText(t, x, y);
    g.textAlign = 'left';
  },
  bar(g, x, y, w, h, v, col, label, icon, max) {
    const m = max || 100;
    g.fillStyle = 'rgba(0,0,0,0.55)';
    g.beginPath(); g.roundRect(x, y, w, h, h / 2); g.fill();
    const gr = g.createLinearGradient(x, y, x + w, y);
    gr.addColorStop(0, col[0]); gr.addColorStop(1, col[1]);
    g.fillStyle = gr;
    g.beginPath(); g.roundRect(x + 1, y + 1, Math.max(0, (w - 2) * clamp(v / m, 0, 1)), h - 2, (h - 2) / 2); g.fill();
    // деления на длинной шкале, чтобы 300 читались
    if (m > 100) {
      g.fillStyle = 'rgba(0,0,0,0.35)';
      for (let i = 1; i < 3; i++) g.fillRect(x + w * i / 3, y + 2, 1, h - 4);
    }
    g.strokeStyle = 'rgba(255,255,255,0.14)'; g.lineWidth = 1;
    g.beginPath(); g.roundRect(x + 0.5, y + 0.5, w - 1, h - 1, h / 2); g.stroke();
    if (label) this.text(g, label, x + w + 8, y + h - 2, 'rgba(220,214,196,0.8)', 11, '600');
    if (icon) this.text(g, icon, x - 16, y + h - 2, 'rgba(220,214,196,0.9)', 12, '700');
  },

  slotBox(g, x, y, s, slot, sel, dim) {
    g.fillStyle = sel ? 'rgba(170,152,96,0.24)' : 'rgba(255,255,255,0.05)';
    g.beginPath(); g.roundRect(x, y, s, s, 6); g.fill();
    g.strokeStyle = sel ? 'rgba(230,210,140,0.75)' : 'rgba(190,180,150,0.22)';
    g.lineWidth = sel ? 1.6 : 1;
    g.beginPath(); g.roundRect(x + 0.5, y + 0.5, s - 1, s - 1, 6); g.stroke();
    if (slot) {
      g.save(); g.translate(x + s * 0.1, y + s * 0.1);
      if (dim) g.globalAlpha = 0.4;
      ITEMS[slot.id].icon(g, s * 0.8);
      g.restore();
      if (slot.n > 1) {
        this.text(g, String(slot.n), x + s - 4, y + s - 5, '#f0ead6', 11, '700', 'right');
      }
    }
  },

  // ---- главное меню ----
  drawMenu(g) {
    const W = this.W, H = this.H;
    const gr = g.createLinearGradient(0, 0, 0, H);
    gr.addColorStop(0, '#20242a'); gr.addColorStop(0.55, '#3a3428'); gr.addColorStop(1, '#17171a');
    g.fillStyle = gr; g.fillRect(0, 0, W, H);
    // силуэт разрушенного города
    g.fillStyle = 'rgba(10,11,13,0.75)';
    const rand = mulberry32(4242);
    let x = 0;
    while (x < W) {
      const w = 30 + rand() * 70, h = 60 + rand() * 260;
      g.fillRect(x, H - 150 - h, w, h + 150);
      if (rand() < 0.35) g.fillRect(x + w * 0.3, H - 150 - h - 40, 6, 40);
      x += w + rand() * 26;
    }
    g.fillStyle = 'rgba(200,170,110,0.06)';
    g.beginPath(); g.arc(W * 0.72, H * 0.26, 220, 0, 7); g.fill();

    this.text(g, 'КРАСНАЯ КНОПКА', W / 2, 190, '#e8dfc4', 62, '800', 'center');
    this.text(g, 'выживание после того, как её нажали', W / 2, 228, 'rgba(210,200,170,0.6)', 15, '500', 'center');
    this.text(g, 'прототип · вид сбоку · ' + WW + '×' + WH + ' частиц', W / 2, H - 40, 'rgba(200,190,160,0.35)', 12, '400', 'center');

    const bx = W / 2 - 130;
    if (this.btn(g, bx, 300, 260, 46, 'Новая игра')) { this.screen = 'custom'; }
    if (this.btn(g, bx, 356, 260, 46, 'Управление')) { this.screen = 'options'; this.fromMenu = true; }
    this.text(g, 'WASD — идти · ЛКМ — копать/стрелять · ПКМ или Q — применить · E — взять · I — инвентарь · B — тело · C — крафт',
      W / 2, 470, 'rgba(200,190,160,0.45)', 12, '400', 'center');
  },

  // ---- кастомизация ----
  drawCustom(g) {
    const W = this.W, H = this.H;
    g.fillStyle = '#1b1c1f'; g.fillRect(0, 0, W, H);
    this.panel(g, W / 2 - 380, 70, 760, 580, 'Кто ты был до войны');

    const a = Player.look;
    // превью
    g.save();
    g.translate(W / 2 - 210, 470);
    g.scale(3.4, 3.4);
    g.fillStyle = 'rgba(0,0,0,0.35)';
    g.beginPath(); g.ellipse(0, 2, 14, 3, 0, 0, 7); g.fill();
    drawHuman(g, 0, 0, a, { face: 1, phase: performance.now() / 220, moving: true, mask: this.previewMask });
    g.restore();

    const x0 = W / 2 + 20, bw = 300;
    let y = 130;
    this.text(g, 'Тон кожи', x0, y, '#a89e84', 12, '600'); y += 12;
    for (let i = 0; i < SKINS.length; i++) {
      const bx = x0 + i * 44;
      g.fillStyle = SKINS[i];
      g.beginPath(); g.roundRect(bx, y, 36, 30, 6); g.fill();
      if (a.skin === i) { g.strokeStyle = '#e8dfc4'; g.lineWidth = 2; g.beginPath(); g.roundRect(bx, y, 36, 30, 6); g.stroke(); }
      if (Input.mclick && Input.mx > bx && Input.mx < bx + 36 && Input.my > y && Input.my < y + 30) a.skin = i;
    }
    y += 54;
    this.text(g, 'Цвет волос', x0, y, '#a89e84', 12, '600'); y += 12;
    for (let i = 0; i < HAIRS.length; i++) {
      const bx = x0 + i * 44;
      g.fillStyle = HAIRS[i];
      g.beginPath(); g.roundRect(bx, y, 36, 30, 6); g.fill();
      if (a.hair === i) { g.strokeStyle = '#e8dfc4'; g.lineWidth = 2; g.beginPath(); g.roundRect(bx, y, 36, 30, 6); g.stroke(); }
      if (Input.mclick && Input.mx > bx && Input.mx < bx + 36 && Input.my > y && Input.my < y + 30) a.hair = i;
    }
    y += 54;
    this.text(g, 'Причёска', x0, y, '#a89e84', 12, '600'); y += 12;
    for (let i = 0; i < HAIRSTYLES.length; i++) {
      if (this.btn(g, x0 + (i % 3) * 104, y + Math.floor(i / 3) * 38, 98, 32, HAIRSTYLES[i], a.hairStyle === i)) a.hairStyle = i;
    }
    y += 92;
    if (this.btn(g, x0, y, 140, 34, a.beard ? 'Борода: есть' : 'Борода: нет', a.beard)) a.beard = !a.beard;
    if (this.btn(g, x0 + 150, y, 150, 34, this.previewMask ? 'Показ: в маске' : 'Показ: без маски', this.previewMask)) this.previewMask = !this.previewMask;
    y += 60;
    this.text(g, 'Одежда: белая майка, тёмные штаны, армейские ботинки —', x0, y, 'rgba(200,190,160,0.5)', 12);
    this.text(g, 'то, в чём ты лёг спать в ту ночь.', x0, y + 16, 'rgba(200,190,160,0.5)', 12);

    if (this.btn(g, W / 2 - 380 + 24, 590, 200, 42, '← Назад')) this.screen = 'menu';
    if (this.btn(g, W / 2 + 380 - 224, 590, 200, 42, 'Проснуться →')) Game.start();
  },

  // ---- HUD ----
  drawHUD(g) {
    const W = this.W, H = this.H;
    const P = Player;
    // шкалы
    const bx = 22, by = 22, bw = 160;
    this.bar(g, bx, by, bw, 12, P.hp, ['#8c2b26', '#d4574a'], Math.round(P.hp) + ' здоровье');
    this.bar(g, bx, by + 20, bw, 12, P.food, ['#7a5c1e', '#d8a83c'], Math.round(P.food) + ' / ' + FOOD_MAX + ' сытость', null, FOOD_MAX);
    this.bar(g, bx, by + 40, bw, 12, P.water, ['#1e5c72', '#3ca8d0'], Math.round(P.water) + ' / ' + WATER_MAX + ' вода', null, WATER_MAX);

    // радиация и фильтр
    const radW = 120;
    g.fillStyle = 'rgba(0,0,0,0.5)'; g.beginPath(); g.roundRect(bx, by + 86, radW, 8, 4); g.fill();
    g.fillStyle = P.rad > 45 ? '#c8d24a' : '#7d8a3c';
    g.beginPath(); g.roundRect(bx + 1, by + 87, (radW - 2) * clamp(P.rad / 100, 0, 1), 6, 3); g.fill();
    this.text(g, 'радиация ' + Math.round(P.rad) + '%', bx + radW + 8, by + 94, P.rad > 45 ? '#d8e06a' : 'rgba(220,214,196,0.7)', 11, '600');

    if (P.mask) {
      g.fillStyle = 'rgba(0,0,0,0.5)'; g.beginPath(); g.roundRect(bx, by + 100, radW, 8, 4); g.fill();
      g.fillStyle = P.filterWear > 30 ? '#4a8a6a' : '#c07a3c';
      g.beginPath(); g.roundRect(bx + 1, by + 101, (radW - 2) * clamp(P.filterWear / 100, 0, 1), 6, 3); g.fill();
      this.text(g, 'фильтр ' + Math.round(P.filterWear) + '%', bx + radW + 8, by + 108, 'rgba(220,214,196,0.7)', 11, '600');
    } else {
      this.text(g, '⚠ ПРОТИВОГАЗ СНЯТ', bx, by + 108, '#e07a5a', 12, '800');
    }

    // тело: подсветка травм
    let wounds = [];
    for (const l of LIMBS) if (P.body[l.id].w > 0) wounds.push(l);
    if (wounds.length) {
      let wy = by + 130;
      this.text(g, 'ТРАВМЫ (B)', bx, wy, 'rgba(220,140,110,0.8)', 11, '800'); wy += 15;
      for (const l of wounds.slice(0, 4)) {
        const b = P.body[l.id];
        this.text(g, l.name + ' — ' + WOUND_NAMES[b.w].split(' ')[0] + (b.bleed ? ' ⬤' : ''), bx, wy, WOUND_COLORS[b.w], 11, '600');
        wy += 14;
      }
    }

    // часы
    const t = Game.time / DAY_LEN;
    const hh = Math.floor(t * 24), mm = Math.floor((t * 24 % 1) * 60);
    this.text(g, (hh < 10 ? '0' : '') + hh + ':' + (mm < 10 ? '0' : '') + mm, W - 24, 34, '#d8d2bc', 22, '700', 'right');
    this.text(g, 'день ' + Game.day + ' · ' + (Game.nightAmount() > 0.5 ? 'ночь' : 'день'), W - 24, 52, 'rgba(200,190,160,0.6)', 12, '500', 'right');
    const z = zoneAtPx(P.x);
    this.text(g, z.name + ' · M — карта', W - 24, 72, z.color, 13, '700', 'right');
    this.text(g, 'зомби рядом: ' + Zombies.list.length, W - 24, 90, 'rgba(200,190,160,0.4)', 11, '500', 'right');
    // монеты и навыки
    g.fillStyle = '#e8cf72';
    g.beginPath(); g.arc(W - 122, 108, 5.5, 0, 7); g.fill();
    g.fillStyle = 'rgba(90,70,20,0.6)'; g.beginPath(); g.arc(W - 122, 108, 2.4, 0, 7); g.fill();
    this.text(g, P.coins + ' монет · F — навыки', W - 24, 112, '#e8cf72', 13, '700', 'right');
    if (Home.inside(P.x, P.y)) this.text(g, '⌂ ДОМ · радиации нет', W - 24, 132, '#8ac0a0', 12, '700', 'right');

    // панель быстрого доступа
    const s = 52, gap = 6, n = 6;
    const hx = W / 2 - (n * s + (n - 1) * gap) / 2, hy = H - s - 18;
    for (let i = 0; i < n; i++) {
      const x = hx + i * (s + gap);
      this.slotBox(g, x, hy, s, P.inv.slots[i], P.hotbar === i);
      this.text(g, String(i + 1), x + 5, hy + 13, 'rgba(230,224,200,0.45)', 10, '700');
      if (Input.mclick && Input.mx > x && Input.mx < x + s && Input.my > hy && Input.my < hy + s) P.hotbar = i;
    }
    // подпись предмета в руке
    const it = P.handItem();
    if (it) {
      this.text(g, it.name, W / 2, hy - 12, '#e8e2ca', 13, '700', 'center');
      if (it.type === 'gun') {
        const m = P.mag[it.kind] || 0, res = P.inv.count(it.ammo);
        this.text(g, m + ' / ' + res + (P.reload > 0 ? '   перезарядка…' : ''), W / 2, hy - 30, m > 0 ? '#e8d8a0' : '#d07a5a', 15, '800', 'center');
      } else if (it.desc) {
        this.text(g, it.desc, W / 2, hy - 30, 'rgba(200,190,160,0.55)', 11, '500', 'center');
      }
    }

    // прогресс копания
    if (P.digProgress > 0 && P.digTarget) {
      const sc = Game.toScreen(P.digTarget.x * CELL + CELL / 2, P.digTarget.y * CELL - 12);
      g.fillStyle = 'rgba(0,0,0,0.6)'; g.beginPath(); g.roundRect(sc.x - 18, sc.y, 36, 5, 2.5); g.fill();
      g.fillStyle = '#d8c88a'; g.beginPath(); g.roundRect(sc.x - 17, sc.y + 1, 34 * clamp(P.digProgress, 0, 1), 3, 1.5); g.fill();
    }

    // подсказка взаимодействия
    if (Game.hint) {
      g.fillStyle = 'rgba(12,13,15,0.72)';
      const tw = g.measureText(Game.hint).width + 150;
      g.beginPath(); g.roundRect(W / 2 - tw / 2, H - 152, tw, 24, 6); g.fill();
      this.text(g, Game.hint, W / 2, H - 135, '#e8dfb8', 13, '700', 'center');
    }
    // сообщение
    if (P.msgT > 0) {
      g.globalAlpha = clamp(P.msgT, 0, 1);
      this.text(g, P.msg, W / 2, 100, '#f0e8cc', 15, '600', 'center');
      g.globalAlpha = 1;
    }
    // панель строительного плана
    const hi = Player.handItem();
    if (hi && hi.type === 'plan') {
      const pw = 620, px = W / 2 - pw / 2, py = H - 148;
      g.fillStyle = 'rgba(12,13,15,0.82)';
      g.beginPath(); g.roundRect(px, py, pw, 40, 8); g.fill();
      g.strokeStyle = 'rgba(190,180,150,0.2)'; g.lineWidth = 1;
      g.beginPath(); g.roundRect(px + 0.5, py + 0.5, pw - 1, 39, 8); g.stroke();
      const cw = pw / PARTS.length;
      for (let i = 0; i < PARTS.length; i++) {
        const cx2 = px + i * cw;
        const sel = i === Player.planPart;
        if (sel) {
          g.fillStyle = 'rgba(170,152,96,0.26)';
          g.beginPath(); g.roundRect(cx2 + 2, py + 2, cw - 4, 36, 6); g.fill();
        }
        this.text(g, PARTS[i].name, cx2 + cw / 2, py + 25, sel ? '#f2ecd8' : 'rgba(200,190,160,0.55)', 11, sel ? '700' : '500', 'center');
      }
      const cost = partCost(PARTS[Player.planPart], Player.planTier);
      const have = Player.inv.count(cost.res);
      this.text(g, 'колесо — деталь · Z — материал: ' + TIERS[Player.planTier].name +
        ' · цена ' + cost.n + ' ' + ITEMS[cost.res].name.toLowerCase() + ' (есть ' + have + ')',
        W / 2, py - 8, have >= cost.n ? 'rgba(220,214,180,0.8)' : '#e08a6a', 12, '600', 'center');
      if (Game.ghost && Game.ghost.err) this.text(g, Game.ghost.err, W / 2, py - 26, '#e08a6a', 12, '600', 'center');
    }

    // подсказки клавиш
    this.text(g, 'Ю выбросить · Q применить · I инвентарь · B тело · C крафт · M карта · F навыки · E взять · R перезарядка · Esc пауза', W / 2, H - 4, 'rgba(200,190,160,0.3)', 11, '500', 'center');
  },

  // ---- инвентарь ----
  drawInv(g) {
    const W = this.W, H = this.H;
    g.fillStyle = 'rgba(0,0,0,0.6)'; g.fillRect(0, 0, W, H);
    const pw = 560, ph = 470, px = W / 2 - pw - 12, py = H / 2 - ph / 2;
    this.panel(g, px, py, pw, ph, 'Инвентарь — 30 ячеек');
    this.text(g, 'ЛКМ — взять · ПКМ — применить', px + pw - 16, py + 26, 'rgba(200,190,160,0.55)', 12, '600', 'right');

    const s = 56, gap = 8;
    // 24 ячейки основного объёма
    for (let i = 6; i < 30; i++) {
      const k = i - 6;
      const x = px + 22 + (k % 6) * (s + gap), y = py + 56 + Math.floor(k / 6) * (s + gap);
      this.slotBox(g, x, y, s, Player.inv.slots[i], false);
      this.slotClick(i, x, y, s);
    }
    // быстрый доступ
    this.text(g, 'Быстрый доступ (1–6)', px + 22, py + ph - 92, '#a89e84', 12, '600');
    for (let i = 0; i < 6; i++) {
      const x = px + 22 + i * (s + gap), y = py + ph - 82;
      this.slotBox(g, x, y, s, Player.inv.slots[i], Player.hotbar === i);
      this.slotClick(i, x, y, s);
    }

    // Красная полоса сброса: вынес предмет за неё, отпустил кнопку — выбросил.
    // Это самый простой способ выкинуть вещь, без всяких сочетаний клавиш
    const dz = { x: px + pw - 4, y: py + 44, w: 26, h: ph - 56 };
    const overDrop = Input.mx > dz.x && Input.mx < dz.x + dz.w && Input.my > dz.y && Input.my < dz.y + dz.h;
    const hot = this.held && overDrop;
    g.fillStyle = hot ? 'rgba(200,60,44,0.55)' : this.held ? 'rgba(180,54,40,0.3)' : 'rgba(150,50,40,0.16)';
    g.beginPath(); g.roundRect(dz.x, dz.y, dz.w, dz.h, 7); g.fill();
    g.strokeStyle = hot ? '#ff8a70' : 'rgba(210,80,60,0.7)';
    g.lineWidth = hot ? 2 : 1.2;
    g.setLineDash([6, 5]);
    g.beginPath(); g.roundRect(dz.x + 0.5, dz.y + 0.5, dz.w - 1, dz.h - 1, 7); g.stroke();
    g.setLineDash([]);
    // подпись вдоль полосы
    g.save();
    g.translate(dz.x + dz.w / 2, dz.y + dz.h / 2);
    g.rotate(Math.PI / 2);
    this.text(g, hot ? 'ОТПУСТИ — ВЫБРОСИТЬ' : 'ВЫБРОСИТЬ', 0, 4, hot ? '#fff0e6' : 'rgba(240,180,164,0.85)', 12, '800', 'center');
    g.restore();
    // сам сброс: клик по полосе с предметом в руке
    if (this.held && overDrop && (Input.mclick || Input.rclick) && this.guard <= 0) {
      Player.dropStack(this.held.id, this.held.n);
      this.held = null;
    }

    // правая панель: снаряжение и персонаж
    const rw = 400, rx = W / 2 + 12;
    this.panel(g, rx, py, rw, ph, 'Снаряжение');
    g.save();
    g.translate(rx + 110, py + 330);
    g.scale(3.0, 3.0);
    g.fillStyle = 'rgba(0,0,0,0.35)'; g.beginPath(); g.ellipse(0, 2, 14, 3, 0, 0, 7); g.fill();
    drawHuman(g, 0, 0, Player.look, { face: 1, phase: 0, moving: false, mask: Player.mask });
    g.restore();

    // слот противогаза
    const mx = rx + 250, my = py + 70;
    this.text(g, 'Голова', mx, my - 8, '#a89e84', 12, '600');
    this.slotBox(g, mx, my, 64, Player.mask ? { id: 'gasmask', n: 1 } : null, false);
    if (Input.mclick && Input.mx > mx && Input.mx < mx + 64 && Input.my > my && Input.my < my + 64) {
      if (Player.mask) Player.removeMask();
      else if (Player.inv.count('gasmask') > 0) Player.wearMask();
    }
    if (Player.mask) {
      this.text(g, 'Фильтр: ' + Math.round(Player.filterWear) + '%', mx, my + 84, Player.filterWear > 30 ? '#8aa87a' : '#d09a5a', 12, '600');
      this.text(g, 'нажми, чтобы снять', mx, my + 100, 'rgba(200,190,160,0.45)', 11);
    } else {
      this.text(g, 'НЕТ ЗАЩИТЫ', mx, my + 84, '#e07a5a', 12, '800');
      this.text(g, 'на улице ты умираешь', mx, my + 100, 'rgba(220,140,110,0.7)', 11);
    }
    this.text(g, Player.look.name, rx + 24, py + ph - 60, '#d8d2bc', 16, '700');
    this.text(g, 'радиация ' + Math.round(Player.rad) + '% · травм: ' + Player.totalWounds(), rx + 24, py + ph - 40, 'rgba(200,190,160,0.6)', 12);

    this.drawHeld(g);
  },
  slotClick(i, x, y, s) {
    const over = Input.mx > x && Input.mx < x + s && Input.my > y && Input.my < y + s;
    // Shift + ПКМ по ячейке — выбросить всю пачку на землю
    if (over && Input.rclick && this.guard <= 0 && !this.held && Input.isDown('ShiftLeft')) {
      Player.dropSlot(i);
      return;
    }
    // ПКМ по ячейке — сразу принять: таблетки, еду, воду, бинт, цинк, противогаз
    if (over && Input.rclick && this.guard <= 0 && !this.held) {
      Player.consume(i);
      return;
    }
    if (!Input.mclick) return;
    if (!over) return;
    const slots = Player.inv.slots;
    if (this.held) {
      const cur = slots[i];
      if (cur && cur.id === this.held.id) {
        const max = ITEMS[cur.id].max, c = Math.min(max - cur.n, this.held.n);
        cur.n += c; this.held.n -= c;
        if (this.held.n <= 0) this.held = null;
      } else { slots[i] = this.held; this.held = cur; }
    } else if (slots[i]) {
      this.held = slots[i]; slots[i] = null;
    }
  },
  drawHeld(g) {
    if (!this.held) return;
    g.save(); g.translate(Input.mx - 22, Input.my - 22);
    g.globalAlpha = 0.92;
    ITEMS[this.held.id].icon(g, 44);
    if (this.held.n > 1) this.text(g, String(this.held.n), 42, 42, '#f0ead6', 12, '700', 'right');
    g.restore();
  },

  // ---- экран тела ----
  drawBody(g) {
    const W = this.W, H = this.H;
    g.fillStyle = 'rgba(0,0,0,0.62)'; g.fillRect(0, 0, W, H);
    const pw = 860, ph = 500, px = W / 2 - pw / 2, py = H / 2 - ph / 2;
    this.panel(g, px, py, pw, ph, 'Состояние тела');

    // схема тела спереди
    const cx = px + 200, cy = py + 110;
    const parts = {
      head: { x: 0, y: 0, w: 34, h: 38, r: 14 },
      torso: { x: 0, y: 52, w: 62, h: 90, r: 8 },
      armL: { x: -48, y: 56, w: 20, h: 88, r: 9 },
      armR: { x: 48, y: 56, w: 20, h: 88, r: 9 },
      legL: { x: -18, y: 152, w: 24, h: 108, r: 10 },
      legR: { x: 18, y: 152, w: 24, h: 108, r: 10 }
    };
    for (const id in parts) {
      const p = parts[id], b = Player.body[id];
      const x = cx + p.x - p.w / 2, y = cy + p.y;
      const over = Input.mx > x && Input.mx < x + p.w && Input.my > y && Input.my < y + p.h;
      g.fillStyle = b.w === 0 ? 'rgba(120,140,116,0.30)' : 'rgba(' + [190, 70, 55] + ',' + (0.18 + b.w * 0.17) + ')';
      g.beginPath(); g.roundRect(x, y, p.w, p.h, p.r); g.fill();
      g.strokeStyle = over ? '#e8dfc4' : WOUND_COLORS[b.w]; g.lineWidth = b.w ? 2 : 1;
      g.beginPath(); g.roundRect(x, y, p.w, p.h, p.r); g.stroke();
      if (b.w) this.text(g, 'C' + b.w, x + p.w / 2, y + p.h / 2 + 4, '#f2e2d0', 13, '800', 'center');
      if (b.bleed) {
        g.fillStyle = '#a8231f';
        g.beginPath(); g.arc(x + p.w - 4, y + 8, 3.5, 0, 7); g.fill();
      }
    }

    // список конечностей
    let ly = py + 70, lx = px + 420;
    this.text(g, 'Классификация ран: C1 ссадина · C2 лёгкая · C3 средняя · C4 смертельная', lx, ly, 'rgba(200,190,160,0.55)', 12);
    ly += 26;
    for (const l of LIMBS) {
      const b = Player.body[l.id];
      g.fillStyle = 'rgba(255,255,255,0.04)';
      g.beginPath(); g.roundRect(lx, ly, 400, 46, 7); g.fill();
      g.fillStyle = WOUND_COLORS[b.w];
      g.beginPath(); g.roundRect(lx, ly, 4, 46, 2); g.fill();
      this.text(g, l.name, lx + 14, ly + 20, '#d8d2bc', 13, '700');
      this.text(g, WOUND_NAMES[b.w] + (b.bleed ? ' · кровотечение' : ''), lx + 14, ly + 36, WOUND_COLORS[b.w], 12, '500');
      const eff = l.id.startsWith('leg') ? 'скорость' : l.id.startsWith('arm') ? 'копание и точность' : l.id === 'head' ? 'психика' : 'выносливость';
      this.text(g, b.w ? '−' + Math.round(b.w * (l.id === 'torso' ? 8 : 11)) + '% ' + eff : '', lx + 386, ly + 28, 'rgba(220,160,130,0.8)', 12, '600', 'right');
      ly += 52;
    }

    // лечение
    const meds = ['bandage', 'splint', 'medkit', 'antirad'];
    let mx2 = px + 40, my2 = py + ph - 84;
    this.text(g, 'Лечение', mx2, my2 - 10, '#a89e84', 12, '600');
    for (const id of meds) {
      const has = Player.inv.count(id);
      if (this.btn(g, mx2, my2, 116, 40, ITEMS[id].name.slice(0, 12) + ' (' + has + ')', false) && has > 0) {
        const slotIndex = Player.inv.slots.findIndex(s => s && s.id === id);
        const prevHot = Player.hotbar;
        // применяем напрямую
        const it = ITEMS[id];
        let used = false;
        if (it.rad) { Player.rad = clamp(Player.rad - it.rad, 0, 100); used = true; }
        if (it.heals && Player.heal(it)) used = true;
        if (used) {
          Player.hp = clamp(Player.hp + (it.hp || 0), 0, 100);
          Player.inv.remove(id, 1);
        } else Player.say('Нечего лечить');
        Player.hotbar = prevHot;
      }
      mx2 += 126;
    }
    this.text(g, 'Esc / B — закрыть', px + pw - 24, py + ph - 20, 'rgba(200,190,160,0.4)', 12, '500', 'right');
  },

  // ---- крафт ----
  drawCraft(g) {
    const W = this.W, H = this.H;
    g.fillStyle = 'rgba(0,0,0,0.62)'; g.fillRect(0, 0, W, H);
    const pw = 1200, ph = 560, px = W / 2 - pw / 2, py = H / 2 - ph / 2;
    const wb3 = Machines.near(Player.x, Player.y, 'workbench3');
    const wb2 = wb3 || Machines.near(Player.x, Player.y, 'workbench2');
    const nearBench = wb2 || Machines.near(Player.x, Player.y, 'workbench');
    const nearFurn = Machines.near(Player.x, Player.y, 'furnace');
    const nearFire = Machines.near(Player.x, Player.y, 'campfire');
    this.panel(g, px, py, pw, ph, 'Крафт' +
      (wb3 ? ' · верстак 3 ур.' : wb2 ? ' · верстак 2 ур.' : nearBench ? ' · верстак' : '') +
      (nearFurn ? ' · печь' : '') + (nearFire ? ' · костёр' : ''));

    const avail = st => !st || (st === 'workbench' && nearBench) || (st === 'workbench2' && wb2) ||
      (st === 'workbench3' && wb3) || (st === 'furnace' && nearFurn) || (st === 'campfire' && nearFire);
    const list = RECIPES.filter(r => avail(r.station));
    const hidden = RECIPES.length - list.length;
    if (hidden) this.text(g, 'скрыто рецептов: ' + hidden + ' — подойди к верстаку, печи или костру',
      px + pw - 24, py + 26, 'rgba(200,190,160,0.5)', 12, '500', 'right');

    let col = 0, row = 0;
    const cw = 275, chh = 74;
    for (let i = 0; i < list.length; i++) {
      const r = list[i];
      const x = px + 20 + col * (cw + 10), y = py + 52 + row * (chh + 8);
      const stationOk = true;
      const fuelOk = !r.fuel || (nearFurn && Machines.list.some(m => m.type === 'furnace' && m.fuel > 0));
      const matOk = Player.inv.has(r.in);
      const can = stationOk && matOk && fuelOk;
      const over = Input.mx > x && Input.mx < x + cw && Input.my > y && Input.my < y + chh;

      g.fillStyle = over && can ? 'rgba(190,170,110,0.18)' : 'rgba(255,255,255,0.04)';
      g.beginPath(); g.roundRect(x, y, cw, chh, 8); g.fill();
      g.strokeStyle = can ? 'rgba(200,190,140,0.4)' : 'rgba(150,140,120,0.15)';
      g.lineWidth = 1; g.beginPath(); g.roundRect(x + 0.5, y + 0.5, cw - 1, chh - 1, 8); g.stroke();

      g.save(); g.translate(x + 8, y + 12);
      if (!can) g.globalAlpha = 0.4;
      ITEMS[r.out[0]].icon(g, 48);
      g.restore();

      this.text(g, ITEMS[r.out[0]].name + (r.out[1] > 1 ? ' ×' + r.out[1] : ''), x + 64, y + 24, can ? '#e8e2ca' : 'rgba(200,190,160,0.45)', 13, '700');
      let ing = [];
      for (const k in r.in) ing.push(ITEMS[k].name + ' ' + Player.inv.count(k) + '/' + r.in[k]);
      this.text(g, ing.join(' · '), x + 64, y + 42, matOk ? 'rgba(180,200,160,0.75)' : 'rgba(210,150,130,0.75)', 11, '500');
      const need = [];
      if (r.station && !stationOk) need.push('нужен ' + (r.station === 'workbench' ? 'верстак' :
        r.station === 'workbench2' ? 'верстак 2 ур.' : r.station === 'workbench3' ? 'верстак 3 ур.' :
        r.station === 'furnace' ? 'печь' : 'костёр'));
      if (r.fuel && !fuelOk) need.push('печь должна быть затоплена');
      this.text(g, need.join(' · '), x + 64, y + 60, 'rgba(210,150,130,0.7)', 11, '500');

      if (over && Input.mclick && can) {
        for (const k in r.in) Player.inv.remove(k, r.in[k]);
        const left = Player.inv.add(r.out[0], r.out[1]);
        if (left > 0) Drops.add(Player.x, Player.y - 20, r.out[0], left);
        Player.say('Готово: ' + ITEMS[r.out[0]].name);
        Particles.burst(Player.x, Player.y - 24, [200, 180, 120], 6);
      }
      row++;
      if (py + 52 + row * (chh + 8) + chh > py + ph - 20) { row = 0; col++; }
    }
    this.text(g, 'Esc / C — закрыть', px + pw - 24, py + ph - 14, 'rgba(200,190,160,0.4)', 12, '500', 'right');
  },

  // ---- карта локаций (M) ----
  drawMap(g) {
    const W = this.W, H = this.H;
    g.fillStyle = 'rgba(0,0,0,0.66)'; g.fillRect(0, 0, W, H);
    const pw = 1000, ph = 560, px = W / 2 - pw / 2, py = H / 2 - ph / 2;
    this.panel(g, px, py, pw, ph, 'Карта · выбери локацию');
    const here = zoneAtPx(Player.x);
    this.text(g, 'ты здесь: ' + here.name, px + pw - 24, py + 26, 'rgba(220,210,170,0.7)', 12, '600', 'right');

    // полоса мира
    const bx = px + 30, bw = pw - 60, byy = py + 56;
    g.fillStyle = 'rgba(255,255,255,0.05)'; g.beginPath(); g.roundRect(bx, byy, bw, 26, 5); g.fill();
    for (const z of ZONES) {
      const zx = bx + (z.x0 / WW) * bw, zw = ((z.x1 - z.x0) / WW) * bw;
      g.fillStyle = z.color + '66';
      g.beginPath(); g.roundRect(zx, byy, zw, 26, 4); g.fill();
      g.fillStyle = 'rgba(240,235,215,0.8)'; g.font = '600 9px system-ui'; g.textAlign = 'center';
      g.fillText(z.name, zx + zw / 2, byy + 17);
    }
    g.textAlign = 'left';
    const mx = bx + (Player.x / (WW * CELL)) * bw;
    g.fillStyle = '#f0e8c0'; g.beginPath(); g.moveTo(mx, byy - 5); g.lineTo(mx - 4, byy - 12); g.lineTo(mx + 4, byy - 12); g.fill();

    // карточки локаций
    const cw = (pw - 60 - 2 * 14) / 3, chh = 152;
    let i = 0;
    for (const z of ZONES) {
      const x = px + 30 + (i % 3) * (cw + 14), y = py + 104 + Math.floor(i / 3) * (chh + 14);
      const cur = z.id === here.id;
      const over = Input.mx > x && Input.mx < x + cw && Input.my > y && Input.my < y + chh;
      g.fillStyle = over && !cur ? 'rgba(200,185,120,0.16)' : 'rgba(255,255,255,0.05)';
      g.beginPath(); g.roundRect(x, y, cw, chh, 9); g.fill();
      g.strokeStyle = cur ? '#e8dfb0' : over ? 'rgba(220,210,170,0.5)' : 'rgba(190,180,150,0.2)';
      g.lineWidth = cur ? 2 : 1; g.beginPath(); g.roundRect(x, y, cw, chh, 9); g.stroke();
      g.fillStyle = z.color; g.beginPath(); g.roundRect(x + 12, y + 14, 26, 6, 3); g.fill();
      this.text(g, z.name, x + 12, y + 44, '#e8e2ca', 16, '700');
      this.text(g, 'угроза: ' + z.danger, x + 12, y + 62, z.zombies > 1.5 ? '#e08a6a' : z.zombies === 0 ? '#8ac0a0' : 'rgba(210,200,170,0.7)', 12, '600');
      // описание в две-три строки
      const words = z.desc.split(' ');
      let line = '', ly = y + 80;
      for (const w of words) {
        if ((line + ' ' + w).length > 34) { this.text(g, line, x + 12, ly, 'rgba(200,190,160,0.7)', 11); line = w; ly += 15; }
        else line = line ? line + ' ' + w : w;
      }
      this.text(g, line, x + 12, ly, 'rgba(200,190,160,0.7)', 11);
      if (cur) this.text(g, 'ты здесь', x + 12, y + chh - 18, '#e8dfb0', 12, '700');
      else if (this.btn(g, x + 12, y + chh - 40, cw - 24, 30, this.pickedZone === z.id ? '✓ выбрано' : 'Выбрать', this.pickedZone === z.id)) {
        this.pickedZone = z.id;
      }
      i++;
    }
    // переход только по отдельному подтверждению — случайный клик никуда не уносит
    const picked = ZONES.find(z => z.id === this.pickedZone && z.id !== here.id);
    if (picked) {
      const cxp = Math.floor((picked.x0 + picked.x1) / 2) * CELL;
      const km = (Math.abs(cxp - Player.x) / CELL / 100).toFixed(1);
      const dir = cxp > Player.x ? 'на восток (D)' : 'на запад (A)';
      this.text(g, picked.name + ' — ' + dir + ', идти ' + km + ' км',
        px + pw / 2, py + ph - 44, '#e8dfb0', 14, '700', 'center');
    } else {
      this.text(g, 'выбери локацию — покажу, куда и сколько идти', px + pw / 2, py + ph - 40, 'rgba(200,190,160,0.5)', 13, '600', 'center');
    }
    this.text(g, 'Телепортов нет: все переходы пешком. M — закрыть',
      px + pw / 2, py + ph - 14, 'rgba(200,190,160,0.45)', 12, '500', 'center');
  },

  // ---- навыки (Ё) ----
  drawSkills(g) {
    const W = this.W, H = this.H;
    g.fillStyle = 'rgba(0,0,0,0.66)'; g.fillRect(0, 0, W, H);
    const pw = 860, ph = 560, px = W / 2 - pw / 2, py = H / 2 - ph / 2;
    this.panel(g, px, py, pw, ph, 'Навыки');
    this.text(g, Player.coins + ' монет', px + pw - 24, py + 26, '#e8cf72', 15, '800', 'right');
    this.text(g, 'За каждого убитого зомби — 2 монеты. Убито: ' + Player.kills, px + 20, py + 52, 'rgba(200,190,160,0.6)', 12);

    let i = 0;
    const cw = (pw - 40 - 14) / 2, chh = 84;
    for (const s of SKILLS) {
      const x = px + 20 + (i % 2) * (cw + 14), y = py + 66 + Math.floor(i / 2) * (chh + 8);
      const lvl = Player.skills[s.id];
      const cost = skillCost(lvl);
      const can = lvl < SKILL_MAX && Player.coins >= cost;
      g.fillStyle = 'rgba(255,255,255,0.045)'; g.beginPath(); g.roundRect(x, y, cw, chh, 8); g.fill();
      g.strokeStyle = 'rgba(190,180,150,0.18)'; g.lineWidth = 1; g.beginPath(); g.roundRect(x, y, cw, chh, 8); g.stroke();
      this.text(g, s.name, x + 14, y + 26, '#e8e2ca', 15, '700');
      this.text(g, s.desc, x + 14, y + 46, 'rgba(200,190,160,0.7)', 11, '500');
      // пипсы уровней
      for (let k = 0; k < SKILL_MAX; k++) {
        g.fillStyle = k < lvl ? '#d8c060' : 'rgba(255,255,255,0.12)';
        g.beginPath(); g.roundRect(x + 14 + k * 16, y + 58, 12, 8, 2); g.fill();
      }
      if (lvl >= SKILL_MAX) this.text(g, 'максимум', x + cw - 18, y + 66, '#8ac0a0', 12, '700', 'right');
      else if (this.btn(g, x + cw - 116, y + 46, 100, 26, cost + ' монет', false) && can) Player.buySkill(s.id);
      else if (!can && lvl < SKILL_MAX) this.text(g, '', 0, 0);
      i++;
    }
    this.text(g, 'F / Esc — закрыть', px + pw - 24, py + ph - 16, 'rgba(200,190,160,0.45)', 12, '500', 'right');
  },

  // ---- торговец ----
  shopTrader: null,

  drawShop(g) {
    const W = this.W, H = this.H;
    g.fillStyle = 'rgba(0,0,0,0.66)'; g.fillRect(0, 0, W, H);
    const pw = 900, ph = 560, px = W / 2 - pw / 2, py = H / 2 - ph / 2;
    const disc = 1 - 0.08 * Player.skills.trade;
    const who = this.shopTrader ? this.shopTrader.name : 'Торговец';
    this.panel(g, px, py, pw, ph, who + (Player.skills.trade ? ' · скидка ' + Math.round((1 - disc) * 100) + '%' : ''));
    if (this.shopTrader) this.text(g, this.shopTrader.greet, px + pw - 16, py + 26, 'rgba(200,190,160,0.55)', 12, '500', 'right');
    this.text(g, Player.coins + ' монет', px + pw - 24, py + 26, '#e8cf72', 15, '800', 'right');

    let i = 0;
    const cw = (pw - 40 - 2 * 12) / 3, chh = 62;
    for (const [id, n, price] of SHOP) {
      const x = px + 20 + (i % 3) * (cw + 12), y = py + 56 + Math.floor(i / 3) * (chh + 8);
      const cost = Math.max(1, Math.round(price * disc));
      const can = Player.coins >= cost;
      const over = Input.mx > x && Input.mx < x + cw && Input.my > y && Input.my < y + chh;
      g.fillStyle = over && can ? 'rgba(200,185,120,0.16)' : 'rgba(255,255,255,0.045)';
      g.beginPath(); g.roundRect(x, y, cw, chh, 8); g.fill();
      g.strokeStyle = can ? 'rgba(200,190,140,0.35)' : 'rgba(150,140,120,0.15)';
      g.lineWidth = 1; g.beginPath(); g.roundRect(x, y, cw, chh, 8); g.stroke();
      g.save(); g.translate(x + 8, y + 12); if (!can) g.globalAlpha = 0.45; ITEMS[id].icon(g, 38); g.restore();
      this.text(g, ITEMS[id].name + (n > 1 ? ' ×' + n : ''), x + 54, y + 26, can ? '#e8e2ca' : 'rgba(200,190,160,0.5)', 13, '700');
      this.text(g, cost + ' монет', x + 54, y + 44, can ? '#e8cf72' : 'rgba(210,180,110,0.45)', 12, '600');
      if (over && Input.mclick && can) {
        Player.coins -= cost;
        if (Player.inv.add(id, n) > 0) Drops.add(Player.x, Player.y - 20, id, n);
        Player.say('Куплено: ' + ITEMS[id].name);
      }
      i++;
    }
    this.text(g, 'Esc — уйти', px + pw - 24, py + ph - 16, 'rgba(200,190,160,0.45)', 12, '500', 'right');
  },

  // ---- доска заданий ----
  drawBoard(g) {
    const W = this.W, H = this.H;
    g.fillStyle = 'rgba(0,0,0,0.66)'; g.fillRect(0, 0, W, H);
    const pw = 720, ph = 460, px = W / 2 - pw / 2, py = H / 2 - ph / 2;
    this.panel(g, px, py, pw, ph, 'Доска заданий');
    this.text(g, Player.coins + ' монет', px + pw - 24, py + 26, '#e8cf72', 15, '800', 'right');
    let y = py + 60;
    for (const m of Missions.list) {
      g.fillStyle = 'rgba(255,255,255,0.045)'; g.beginPath(); g.roundRect(px + 20, y, pw - 40, 76, 8); g.fill();
      g.fillStyle = m.state === 3 ? '#5f7f5a' : m.state === 0 ? 'rgba(190,180,150,0.3)' : '#c8a848';
      g.beginPath(); g.roundRect(px + 20, y, 4, 76, 2); g.fill();
      this.text(g, m.text, px + 38, y + 26, '#e8e2ca', 15, '700');
      this.text(g, Missions.progress(m) + ' · награда ' + m.pay + ' монет', px + 38, y + 48, 'rgba(200,190,160,0.75)', 12, '500');
      const label = m.state === 0 ? 'Взять' : m.state === 3 ? 'Сдано' : 'Сдать';
      if (this.btn(g, px + pw - 160, y + 22, 130, 32, label, m.state === 3) && m.state !== 3) Missions.turnIn(m);
      y += 84;
    }
    this.text(g, 'Esc — отойти', px + pw - 24, py + ph - 16, 'rgba(200,190,160,0.45)', 12, '500', 'right');
  },

  // ---- пауза / управление ----
  drawOptions(g) {
    const W = this.W, H = this.H;
    g.fillStyle = 'rgba(0,0,0,0.72)'; g.fillRect(0, 0, W, H);
    const pw = 520, ph = 500, px = W / 2 - pw / 2, py = H / 2 - ph / 2;
    this.panel(g, px, py, pw, ph, 'Управление');
    const rows = [
      ['A / D', 'идти влево-вправо'],
      ['Shift', 'бежать (тратит еду и воду)'],
      ['Space / W', 'подпрыгнуть'],
      ['ЛКМ', 'копать породу · стрелять'],
      ['ПКМ', 'применить предмет: поставить, съесть, надеть'],
      ['E', 'подобрать, вскрыть ящик, использовать машину'],
      ['1–6', 'быстрый доступ'],
      ['колесо', 'смена предмета в руке'],
      ['M', 'карта локаций и переходы между ними'],
      ['F', 'навыки за монеты (2 монеты за зомби)'],
      ['I', 'инвентарь (30 ячеек) и снаряжение'],
      ['B', 'состояние тела и лечение'],
      ['C', 'крафт'],
      ['R', 'перезарядка'],
      ['Esc', 'пауза']
    ];
    let y = py + 60;
    for (const [k, v] of rows) {
      g.fillStyle = 'rgba(255,255,255,0.05)'; g.beginPath(); g.roundRect(px + 20, y - 14, pw - 40, 26, 5); g.fill();
      this.text(g, k, px + 32, y + 4, '#e0d8bc', 12, '700');
      this.text(g, v, px + 130, y + 4, 'rgba(200,190,160,0.75)', 12, '500');
      y += 31;
    }
    if (this.btn(g, px + 20, py + ph - 56, pw - 40, 40, this.fromMenu ? 'Назад в меню' : 'Продолжить')) {
      if (this.fromMenu) { this.screen = 'menu'; this.fromMenu = false; }
      else this.screen = null;
    }
  },

  drawDead(g) {
    const W = this.W, H = this.H;
    g.fillStyle = 'rgba(20,6,6,0.82)'; g.fillRect(0, 0, W, H);
    this.text(g, 'ТЫ УМЕР', W / 2, H / 2 - 60, '#c8483c', 62, '800', 'center');
    this.text(g, Player.deathCause, W / 2, H / 2 - 16, '#d8c8b8', 16, '500', 'center');
    this.text(g, 'день ' + Game.day + ' · травм: ' + Player.totalWounds() + ' · радиация ' + Math.round(Player.rad) + '%',
      W / 2, H / 2 + 10, 'rgba(200,180,170,0.6)', 13, '500', 'center');
    const hasBed = !!(Structures.bed() || Machines.bed());
    if (hasBed) {
      if (this.btn(g, W / 2 - 140, H / 2 + 50, 280, 46, 'Очнуться в своей кровати')) Game.respawnAtBed();
      this.text(g, 'вещи и мир остаются, тело подлечено', W / 2, H / 2 + 112, 'rgba(200,190,160,0.5)', 12, '500', 'center');
      if (this.btn(g, W / 2 - 140, H / 2 + 126, 280, 36, 'Начать новую жизнь с нуля')) Game.start();
    } else {
      this.text(g, 'кровати нет — возрождаться некуда', W / 2, H / 2 + 44, 'rgba(210,150,130,0.7)', 12, '600', 'center');
      if (this.btn(g, W / 2 - 120, H / 2 + 58, 240, 46, 'Проснуться заново')) Game.start();
    }
    if (this.btn(g, W / 2 - 120, H / 2 + (hasBed ? 174 : 116), 240, 36, 'В меню')) { this.screen = 'menu'; Player.dead = false; }
  },

  // ---- интро ----
  drawIntro(g) {
    const W = this.W, H = this.H;
    const t = Game.introT;
    g.fillStyle = 'rgba(0,0,0,' + clamp(1.4 - t * 0.5, 0, 1) + ')';
    g.fillRect(0, 0, W, H);
    const lines = [
      ['...сколько я спал?', 0.6],
      ['Стены нет. Крыши почти нет.', 3.0],
      ['Воздух жжёт горло. Надо чем-то дышать.', 5.6],
      ['Рядом на полу — противогаз. Подойди и нажми E.', 8.2]
    ];
    for (const [txt, at] of lines) {
      const a = clamp((t - at) * 0.8, 0, 1) * clamp(1 - (t - at - 6) * 0.5, 0, 1);
      if (a <= 0) continue;
      g.globalAlpha = a;
      this.text(g, txt, W / 2, 120 + lines.findIndex(l => l[0] === txt) * 26, '#e8dfc4', 17, '600', 'center');
      g.globalAlpha = 1;
    }
    if (t > 14) Game.introDone = true;
  }
};
