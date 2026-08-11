// player.js — физика, шкалы, тело и травмы, радиация, действия
'use strict';

const LIMBS = [
  { id: 'head', name: 'Голова' },
  { id: 'torso', name: 'Торс' },
  { id: 'armL', name: 'Левая рука' },
  { id: 'armR', name: 'Правая рука' },
  { id: 'legL', name: 'Левая нога' },
  { id: 'legR', name: 'Правая нога' }
];

const WOUND_NAMES = ['цела', 'C1 — ссадина', 'C2 — лёгкая рана', 'C3 — средняя рана', 'C4 — смертельная рана'];
const WOUND_COLORS = ['#5f7f5a', '#b6b06a', '#d09848', '#c4642f', '#a8232a'];

// навыки: качаются за монеты, по 2 монеты за убитого зомби
const SKILLS = [
  { id: 'dig', name: 'Горняк', desc: 'Скорость копания +15% за уровень' },
  { id: 'speed', name: 'Ходок', desc: 'Скорость передвижения +8% за уровень' },
  { id: 'legs', name: 'Крепкие ноги', desc: 'Меньше урона и травм от падения' },
  { id: 'lungs', name: 'Лёгкие', desc: 'Медленнее копится радиация, дольше живёт фильтр' },
  { id: 'meta', name: 'Метаболизм', desc: 'Еда и вода тратятся на 12% медленнее' },
  { id: 'aim', name: 'Стрелок', desc: 'Меньше разброс, +8% урона от оружия' },
  { id: 'medic', name: 'Санитар', desc: 'Аптечки и бинты лечат ощутимо лучше' },
  { id: 'trade', name: 'Барыга', desc: 'Скидка у торговца и +1 монета с зомби' }
];
const SKILL_MAX = 5;
function skillCost(lvl) { return 10 + lvl * 8; }

const Player = {
  x: 0, y: 0, vx: 0, vy: 0, w: 13, h: 54,
  coins: 0, kills: 0,
  skills: { dig: 0, speed: 0, legs: 0, lungs: 0, meta: 0, aim: 0, medic: 0, trade: 0 },
  face: 1, phase: 0, onGround: false, fallStart: null,
  hp: 100, food: 240, water: 220, psy: 100, rad: 0,
  mask: null,            // {filter: 0..100} — надет
  filterWear: 100,
  look: { skin: 1, hair: 0, hairStyle: 0, beard: true, name: 'Выживший' },
  inv: null,
  hotbar: 0,
  body: {},
  digProgress: 0, digAnim: undefined, digTarget: null,
  planPart: 0, planTier: 0,
  reload: 0, cooldown: 0, recoil: 0, mag: {},
  dead: false, deathCause: '',
  msg: '', msgT: 0,

  buySkill(id) {
    const lvl = this.skills[id];
    if (lvl >= SKILL_MAX) { this.say('Навык уже прокачан до конца'); return false; }
    const cost = skillCost(lvl);
    if (this.coins < cost) { this.say('Нужно ' + cost + ' монет'); return false; }
    this.coins -= cost;
    this.skills[id] = lvl + 1;
    this.say(SKILLS.find(s => s.id === id).name + ' — уровень ' + (lvl + 1));
    return true;
  },

  init() {
    this.inv = new Inventory(30);
    for (const l of LIMBS) this.body[l.id] = { w: 0, bleed: false };
    this.x = World.spawnX * CELL;
    this.y = (World.surface[World.spawnX] - 1) * CELL;
    this.inv.add('canteen_dirty', 1);
    this.inv.add('can', 1);
    // магазин заводим на каждый вид оружия: у новых стволов его не было,
    // и вместо числа патронов в HUD показывалось NaN
    this.mag = {};
    for (const id in ITEMS) if (ITEMS[id].type === 'gun') this.mag[ITEMS[id].kind] = 0;
  },

  say(t) { this.msg = t; this.msgT = 3.4; },

  // Выбросить всё из выбранной ячейки под ноги, как в Майнкрафте.
  // Вещь летит в сторону взгляда и полторы секунды не подбирается обратно
  dropHand() {
    const slot = this.hand();
    if (!slot) { this.say('В руке пусто'); return false; }
    const id = slot.id, n = slot.n;
    Drops.add(this.x + this.face * 12, this.y - 30, id, n, this.face * 1.6, -2, 1.2);
    this.inv.slots[this.hotbar] = null;
    this.say('Выбросил: ' + ITEMS[id].name + (n > 1 ? ' ×' + n : ''));
    return true;
  },

  // выбросить произвольную пачку (её тянут мышью на красную полосу)
  dropStack(id, n) {
    Drops.add(this.x + this.face * 12, this.y - 30, id, n, this.face * 1.6, -2, 1.2);
    this.say('Выбросил: ' + ITEMS[id].name + (n > 1 ? ' ×' + n : ''));
    return true;
  },

  // выбросить конкретную ячейку инвентаря (правый клик по ней с зажатым Shift)
  dropSlot(i) {
    const slot = this.inv.slots[i];
    if (!slot) return false;
    Drops.add(this.x + this.face * 12, this.y - 30, slot.id, slot.n, this.face * 1.6, -2, 1.2);
    this.say('Выбросил: ' + ITEMS[slot.id].name + (slot.n > 1 ? ' ×' + slot.n : ''));
    this.inv.slots[i] = null;
    return true;
  },

  hand() { return this.inv.slots[this.hotbar]; },
  handItem() { const s = this.hand(); return s ? ITEMS[s.id] : null; },

  // ---- модификаторы от травм ----
  legPenalty() {
    const a = this.body.legL.w, b = this.body.legR.w;
    return 1 - Math.min(0.75, (a + b) * 0.11);
  },
  armPenalty() {
    const a = this.body.armL.w, b = this.body.armR.w;
    return 1 - Math.min(0.7, (a + b) * 0.1);
  },
  wound(limb, sev) {
    const b = this.body[limb];
    if (sev > b.w) b.w = Math.min(4, sev);
    if (b.w >= 3) b.bleed = true;
    Floaters.push(this.x, this.y - 60, WOUND_NAMES[b.w].split(' ')[0] + ' ' + LIMBS.find(l => l.id === limb).name.toLowerCase(), '#d0603c');
  },
  totalWounds() { let s = 0; for (const l of LIMBS) s += this.body[l.id].w; return s; },

  heal(item) {
    // лечит самую тяжёлую рану, которую умеет
    const power = item.heals + (this.skills.medic >= 3 ? 1 : 0);
    let best = null;
    for (const l of LIMBS) {
      const b = this.body[l.id];
      if (b.w > 0 && b.w <= power && (!best || b.w > this.body[best].w)) best = l.id;
    }
    if (best) {
      this.body[best].w = Math.max(0, this.body[best].w - (item.heals >= 4 ? 4 : 1));
      if (this.body[best].w < 3) this.body[best].bleed = false;
      this.say('Обработал: ' + LIMBS.find(l => l.id === best).name.toLowerCase());
      return true;
    }
    if (item.rad) { return false; }
    return false;
  },

  update(dt) {
    if (this.dead) return;
    const speed = 1.65 * this.legPenalty() * (1 + 0.08 * this.skills.speed);
    const sprint = Input.isDown('ShiftLeft') || Input.isDown('ShiftRight')
      ? 1 + 0.55 * clamp(this.legPenalty(), 0.35, 1) : 1;
    let ax = 0;
    if (Input.isDown('KeyA') || Input.isDown('ArrowLeft')) ax -= 1;
    if (Input.isDown('KeyD') || Input.isDown('ArrowRight')) ax += 1;
    const inWater = World.get(Math.floor(this.x / CELL), Math.floor((this.y - 10) / CELL)) === M.WATER;

    this.vx = ax * speed * sprint * (inWater ? 0.6 : 1);
    if (ax !== 0) { this.face = ax; this.phase += dt * (7 + Math.abs(this.vx) * 3.2); }
    else this.phase += dt * 0.6;
    // со стволом в руках персонаж разворачивается на курсор, как в шутерах
    const hi = this.handItem();
    if (hi && (hi.type === 'gun' || hi.type === 'melee')) this.face = Input.wx >= this.x ? 1 : -1;

    // лестница: по ней лазают вверх-вниз
    const onLadder = World.get(Math.floor(this.x / CELL), Math.floor((this.y - 20) / CELL)) === M.LADDER ||
                     World.get(Math.floor(this.x / CELL), Math.floor((this.y - 44) / CELL)) === M.LADDER;
    this.onLadder = onLadder;
    if (onLadder) {
      const up = Input.isDown('KeyW') || Input.isDown('ArrowUp') || Input.isDown('Space');
      const dn = Input.isDown('KeyS') || Input.isDown('ArrowDown');
      this.vy = up ? -1.5 : dn ? 1.9 : 0;
      this.vx *= 0.5;
      this.phase += dt * 5;
    } else {
      if ((Input.isDown('Space') || Input.isDown('KeyW')) && this.onGround) {
        this.vy = -5.4 * clamp(this.legPenalty() + 0.2, 0.4, 1);
        this.onGround = false;
      }
      this.vy += GRAV * (inWater ? 0.35 : 1);
      if (inWater) this.vy = Math.min(this.vy, 1.2);
      this.vy = Math.min(this.vy, 14);
    }

    this.unstuck();
    this.moveX(this.vx);
    this.moveY(this.vy);

    this.needs(dt);
    this.actions(dt);

    if (this.recoil > 0) this.recoil = Math.max(0, this.recoil - dt * 6);
    if (this.cooldown > 0) this.cooldown -= dt;
    if (this.reload > 0) {
      this.reload -= dt;
      if (this.reload <= 0) this.finishReload();
    }
    if (this.msgT > 0) this.msgT -= dt;
  },

  moveX(vx) {
    const nx = this.x + vx;
    if (!this.hits(nx, this.y)) { this.x = nx; return; }
    // авто-подъём на уступ, но только если над головой есть куда встать:
    // иначе игрока заталкивало в перекрытие на этажах
    for (let up = 1; up <= 2; up++) {
      const ny = this.y - up * CELL;
      if (this.hits(nx, ny)) continue;
      if (this.hits(this.x, ny)) continue;              // не пролезает вверх на месте
      this.x = nx; this.y = ny; return;
    }
    this.vx = 0;
  },

  // страховка от застревания: если тело оказалось внутри породы — выдавливаем наружу
  unstuck() {
    if (!this.hits(this.x, this.y)) return;
    for (let up = 1; up <= 14; up++) {
      if (!this.hits(this.x, this.y - up * CELL)) { this.y -= up * CELL; this.vy = 0; return; }
    }
    for (const dx of [-1, 1, -2, 2, -3, 3]) {
      if (!this.hits(this.x + dx * CELL, this.y)) { this.x += dx * CELL; this.vy = 0; return; }
    }
    // совсем зажало — поднимаем на поверхность
    const cx = clamp(Math.floor(this.x / CELL), 0, WW - 1);
    this.y = (World.surface[cx] - 1) * CELL;
    this.vy = 0;
  },
  moveY(vy) {
    const ny = this.y + vy;
    if (!this.hits(this.x, ny)) {
      this.y = ny;
      this.onGround = false;
      if (this.onLadder) this.fallStart = null;
      else if (vy > 0 && this.fallStart === null) this.fallStart = this.y - vy;
      return;
    }
    if (vy > 0) {
      // приземление
      while (!this.hits(this.x, this.y + 1) && this.hits(this.x, ny)) this.y += 1;
      if (this.fallStart !== null) {
        const fall = (this.y - this.fallStart) / CELL - this.skills.legs * 3;
        if (fall > 13) {
          // C4 — только за совсем безумную высоту, иначе прототип превращается в казнь
          const sev = fall > 55 ? 4 : fall > 32 ? 3 : fall > 20 ? 2 : 1;
          this.wound(Math.random() < 0.5 ? 'legL' : 'legR', sev);
          this.hp -= (fall - 10) * 1.5 * Math.pow(0.85, this.skills.legs);
          Particles.burst(this.x, this.y, [90, 70, 50], 10);
          this.say('Приземлился неудачно');
        }
        this.fallStart = null;
      }
      this.onGround = true;
    }
    this.vy = 0;
  },
  hits(x, y) {
    const x0 = Math.floor((x - this.w / 2) / CELL), x1 = Math.floor((x + this.w / 2 - 1) / CELL);
    const y0 = Math.floor((y - this.h) / CELL), y1 = Math.floor((y - 1) / CELL);
    for (let cy = y0; cy <= y1; cy++) for (let cx = x0; cx <= x1; cx++) if (World.solid(cx, cy)) return true;
    return false;
  },

  // ---- шкалы, радиация, кровь ----
  needs(dt) {
    const sprinting = Math.abs(this.vx) > 2;
    const meta = 1 - 0.12 * this.skills.meta;
    // Одна единица примерно за 15 секунд: полные 300 держатся больше часа игры.
    // Бег ускоряет расход в полтора раза, не больше
    this.food -= dt * (1 / 15) * (sprinting ? 1.5 : 1) * meta;
    this.water -= dt * (1 / 13) * (sprinting ? 1.5 : 1) * meta;

    // радиация. В противогазе с живым фильтром — не растёт вообще и медленно сходит.
    // Без противогаза копится не спеша, и вредит только выше 30%.
    const sheltered = World.isUnderground(this.x, this.y) || World.hasRoof(this.x, this.y);
    const atHome = Home.inside(this.x, this.y);
    const zoneMul = atHome ? 0 : zoneAtPx(this.x).radMul;
    const lungs = 1 - 0.15 * this.skills.lungs;
    let radIn = 0;
    if (atHome) radIn = 0;                                              // дом всегда чистый
    else if (this.mask && this.filterWear > 0) radIn = 0;
    else if (this.mask) radIn = (sheltered ? 0.3 : 1.1) * zoneMul;      // фильтр сдох
    else radIn = (sheltered ? 0.35 : 1.5) * zoneMul;                    // без маски
    if (World.get(Math.floor(this.x / CELL), Math.floor((this.y - 6) / CELL)) === M.WATER) radIn += 1.2;
    this.rad = clamp(this.rad + radIn * lungs * dt - dt * 1.1, 0, 100);
    if (this.mask && !sheltered && !atHome) this.filterWear = Math.max(0, this.filterWear - dt * 0.22 * (1 - 0.12 * this.skills.lungs));

    if (this.rad > 30) this.hp -= dt * (this.rad - 30) * 0.02;

    // психика
    const dark = Game.nightAmount();

    // кровотечение
    let bleeding = 0;
    for (const l of LIMBS) if (this.body[l.id].bleed) bleeding++;
    if (bleeding) { this.hp -= dt * bleeding * 1.6; if (Math.random() < dt * 6) Particles.blood(this.x, this.y - 30); }

    // голод и жажда бьют по здоровью
    if (this.food <= 0) this.hp -= dt * 1.2;
    if (this.water <= 0) this.hp -= dt * 1.8;
    // психика здоровье не отнимает: на нуле просто сереет мир
    // медленная регенерация в сытости и без ран
    if (this.food > 120 && this.water > 120 && this.totalWounds() === 0 && this.rad < 15) this.hp += dt * 0.8;

    this.food = clamp(this.food, 0, FOOD_MAX);
    this.water = clamp(this.water, 0, WATER_MAX);
    this.hp = clamp(this.hp, 0, 100);

    if (this.hp <= 0) {
      this.dead = true;
      this.deathCause =
        this.rad > 45 ? 'Лучевая болезнь. Не стоило снимать противогаз.' :
        this.water <= 0 ? 'Обезвоживание.' :
        this.food <= 0 ? 'Голод.' :
        bleeding ? 'Кровопотеря.' : 'Тело не выдержало.';
    }
  },

  // ---- действия ----
  actions(dt) {
    const it = this.handItem();
    // прицел
    this.aimAng = Math.atan2(Input.wy - (this.y - 41), Input.wx - this.x);

    // взрывчатка: бросок в сторону курсора, сила зависит от дальности прицела
    if (it && it.type === 'throw') {
      if ((Input.mclick || Input.rclick || Input.once('KeyQ')) && this.cooldown <= 0) {
        const slot = this.hand();
        if (slot && slot.n > 0) {
          this.cooldown = 0.45;
          const d = clamp(dist(this.x, this.y - 34, Input.wx, Input.wy) / 26, 3, 11);
          Throwables.throwIt(slot.id, this.x + this.face * 10, this.y - 36, this.aimAng, d);
          this.inv.remove(slot.id, 1);
          this.say(it.name + ' брошена');
        }
      }
      this.digProgress = 0; this.digAnim = undefined;
      return;
    }

    // строительный план: колесо листает детали, ЛКМ и ПКМ ставят
    if (it && it.type === 'plan') {
      // деталь листается колесом и кнопкой O — как просил
      if (Input.wheel || Input.once('KeyO')) {
        const back = Input.wheel < 0;
        this.planPart = (this.planPart + (back ? PARTS.length - 1 : 1)) % PARTS.length;
        Input.wheel = 0;
        this.say(PARTS[this.planPart].name);
      }
      if (Input.once('KeyZ')) {
        this.planTier = (this.planTier + 1) % TIERS.length;
        this.say('Материал: ' + TIERS[this.planTier].name);
      }
      if (Input.mclick || Input.rclick || Input.once('KeyQ')) {
        const part = PARTS[this.planPart];
        const g = Structures.snap(part, Input.wx, Input.wy);
        if (dist(this.x, this.y - 28, (g.gx + part.w / 2) * CELL, (g.gy + part.h / 2) * CELL) > 110) {
          this.say('Слишком далеко — подойди ближе');
        } else {
          Structures.place(part.id, g.gx, g.gy, this.planTier);
        }
      }
      this.digProgress = 0; this.digAnim = undefined;
      return;
    }

    // молоток: ЛКМ — ремонт, ПКМ или Q — апгрейд материала
    if (it && it.type === 'hammer') {
      const target = Structures.at(Math.floor(Input.wx / CELL), Math.floor(Input.wy / CELL));
      const near = target && dist(this.x, this.y - 28, Input.wx, Input.wy) < 100;
      if (Input.mclick) {
        if (near) Structures.repair(target); else this.say('Наведи на свою постройку');
      }
      if (Input.rclick || Input.once('KeyQ')) {
        if (near) Structures.upgrade(target); else this.say('Наведи на свою постройку');
      }
      this.digProgress = 0; this.digAnim = undefined;
      return;
    }

    if (it && it.type === 'gun') {
      this.digProgress = 0; this.digAnim = undefined;
      if (Input.isDown('KeyR') || Input.once('KeyR')) this.startReload(it);
      const fire = it.kind === 'pistol' ? Input.mclick : Input.mdown;
      if (fire && this.cooldown <= 0 && this.reload <= 0) this.shoot(it);
      if (Input.once('KeyQ')) this.useRight(it);
      return;
    }

    if (it && it.type === 'melee') {
      if (Input.mdown && this.cooldown <= 0) this.swing(it);
      if (this.swingT > 0) { this.swingT -= dt; this.digAnim = 1 - this.swingT / 0.35; }
      else this.digAnim = undefined;
      if (Input.rclick || Input.once('KeyQ')) this.useRight(it);
      return;
    }

    // инструментом тоже можно врезать: если зомби рядом под курсором — бьём, а не копаем
    if (it && it.type === 'tool' && it.dmg && Input.mdown && this.cooldown <= 0) {
      const zx = this.x + (Input.wx > this.x ? 1 : -1) * 26;
      if (Zombies.list.some(z => z.hp > 0 && dist(zx, this.y - 30, z.x, z.y - 24) < 32)) {
        this.swing({ dmg: it.dmg, rof: 0.5 });
        return;
      }
    }
    if (this.swingT > 0) { this.swingT -= dt; this.digAnim = 1 - this.swingT / 0.35; }

    if (Input.mdown) this.dig(dt, it);
    else { this.digProgress = 0; this.digAnim = undefined; this.digTarget = null; }

    if (Input.rclick || Input.once('KeyQ')) this.useRight(it);
  },

  reach() { return 78; },

  swing(it) {
    this.cooldown = it.rof;
    this.swingT = 0.35;
    this.face = Input.wx > this.x ? 1 : -1;
    const hx = this.x + this.face * 24, hy = this.y - 30;
    let hitAny = false;
    for (const z of Zombies.list) {
      if (z.hp <= 0) continue;
      // по горизонтали бьём вперёд с запасом, по высоте прощаем разницу уровней:
      // иначе зомби на кочке или вплотную к телу оказывался вне зоны удара
      const zdx = (z.x - hx) * this.face, zdy = (z.y - 24) - hy;
      if (zdx > -34 && zdx < 40 && Math.abs(zdy) < 34) {
        z.hp -= it.dmg * this.armPenalty();
        z.vx += this.face * 1.6; z.vy = -2.2;
        for (let k = 0; k < 7; k++) Particles.blood(z.x, z.y - 26);
        Floaters.push(z.x, z.y - 40, String(Math.round(it.dmg * this.armPenalty())), '#e0b090');
        hitAny = true;
      }
    }
    if (hitAny) Game.shake = 3;
  },

  dig(dt, it) {
    const cx = Math.floor(Input.wx / CELL), cy = Math.floor(Input.wy / CELL);
    if (dist(this.x, this.y - 28, Input.wx, Input.wy) > this.reach()) { this.digProgress = 0; return; }
    if (World.protectedAt(cx)) { this.digProgress = 0; this.say('Город трогать нельзя'); return; }
    // нода руды: бьём по валуну, ресурс капает с каждого удара
    const node = Nodes.at(Input.wx, Input.wy, 26);
    if (node) {
      const power = it && it.type === 'tool' ? (it.power || 0.4) * 12 : 4;
      this.digProgress += dt * 2.4 * this.armPenalty();
      this.digAnim = (this.digAnim === undefined ? 0 : (this.digAnim + dt * 3.4) % 1);
      if (this.digProgress >= 1) {
        this.digProgress = 0;
        Nodes.hit(node, power * (1 + 0.15 * this.skills.dig));
      }
      return;
    }
    // постройки не выгрызаются по частицам: у них своя прочность
    const st = Structures.at(cx, cy);
    if (st) {
      const power = it && it.type === 'tool' ? (it.dmg || 12) : 6;
      this.digProgress += dt * 2.2;
      this.digAnim = (this.digAnim === undefined ? 0 : (this.digAnim + dt * 3.4) % 1);
      if (this.digProgress >= 1) {
        this.digProgress = 0;
        Structures.damage(st, power * (1 + 0.15 * this.skills.dig));
        Floaters.push(Input.wx, Input.wy - 8, '-' + Math.round(power), '#e0b070');
      }
      return;
    }
    const m = World.get(cx, cy);
    if (m === M.AIR || m === M.WATER || MATS[m].door) { this.digProgress = 0; this.digTarget = null; return; }
    if (!this.digTarget || this.digTarget.x !== cx || this.digTarget.y !== cy) {
      this.digTarget = { x: cx, y: cy }; this.digProgress = 0;
    }
    this.face = Input.wx > this.x ? 1 : -1;
    let power = 0.22;                         // руками
    const woody = MATS[m] && (MATS[m].woody || MATS[m].bark || MATS[m].plank || MATS[m].leaf);
    if (it && it.type === 'tool') power = it.power * (woody && it.wood ? it.wood : 1);
    power *= this.armPenalty() * (1 + 0.15 * this.skills.dig);
    // кисть: руками одна частица, деревянным кайлом 3×3, металлической киркой 9×9
    const brush = it && it.type === 'tool' ? (it.brush || 0) : 0;
    const square = brush >= 2;
    const area = square ? (brush * 2 + 1) * (brush * 2 + 1) : 1 + brush * 4;
    const hard = Math.max(0.2, World.hardnessAt(cx, cy, Math.min(1, brush)));
    this.digProgress += dt * power / (hard * (1 + area * 0.014));
    this.digAnim = (this.digAnim === undefined ? 0 : (this.digAnim + dt * 3.4) % 1);
    if (this.digProgress >= 1) {
      this.digProgress = 0;
      const drops = World.digAt(cx, cy, brush, square);
      for (const id in drops) {
        const n = Math.max(1, Math.round(drops[id] * 0.45));
        if (this.inv.add(id, n) > 0) this.say('Инвентарь полон');
        else Floaters.push(cx * CELL, cy * CELL, '+' + n + ' ' + ITEMS[id].name, '#cfe0b0');
      }
      World.dirty(cx, cy);
    }
  },

  // применить предмет на себя: ПКМ в мире или ПКМ по ячейке в инвентаре
  consume(i) {
    const slot = this.inv.slots[i];
    if (!slot) return false;
    const it = ITEMS[slot.id];
    if (!it) return false;

    if (it.type === 'food') {
      if (this.food >= FOOD_MAX && !it.hp) { this.say('Ты сыт'); return false; }
      this.food = clamp(this.food + (it.food || 0) * 2.5, 0, FOOD_MAX);
      this.water = clamp(this.water + (it.water || 0) * 2.5, 0, WATER_MAX);
      this.hp = clamp(this.hp + (it.hp || 0), 0, 100);
      this.inv.remove(slot.id, 1);
      if (slot.id === 'can') this.inv.add('scrap', 1);
      this.say('Съел: ' + it.name);
      return true;
    }
    if (it.type === 'drink') {
      if (this.water >= WATER_MAX) { this.say('Пить не хочется'); return false; }
      this.water = clamp(this.water + (it.water || 0) * 2.5, 0, WATER_MAX);
      this.hp = clamp(this.hp + (it.hp || 0), 0, 100);
      if (slot.id === 'canteen_dirty') this.rad = clamp(this.rad + 10, 0, 100);
      this.inv.remove(slot.id, 1); this.inv.add('canteen', 1);
      this.say('Выпил');
      return true;
    }
    if (it.type === 'med') {
      // принимается сразу: лечит рану, сбивает радиацию, поднимает психику — что может
      let used = false;
      if (it.rad && this.rad > 0) { this.rad = clamp(this.rad - it.rad, 0, 100); used = true; this.say('Радиация сбита'); }
      if (it.heals && this.heal(it)) used = true;
      if (!used && (it.hp || 0) > 0 && this.hp < 100) { used = true; this.say('Перевязался'); }
      if (!used) { this.say('Сейчас это ничего не даст'); return false; }
      this.hp = clamp(this.hp + (it.hp || 0), 0, 100);
      this.inv.remove(slot.id, 1);
      return true;
    }
    if (it.type === 'zinc') {
      this.inv.remove(slot.id, 1);
      const left = this.inv.add(it.gives[0], it.gives[1]);
      this.say('Вскрыл цинк: ' + it.gives[1] + ' патронов' + (left ? ' (часть не влезла)' : ''));
      return true;
    }
    if (it.type === 'mask') { this.wearMask(); return true; }
    if (it.type === 'filter') {
      if (!this.mask) { this.say('Противогаз не надет'); return false; }
      if (this.filterWear > 95) { this.say('Фильтр ещё свежий'); return false; }
      this.filterWear = 100; this.inv.remove(slot.id, 1); this.say('Фильтр заменён');
      return true;
    }
    return false;
  },

  useRight(it) {
    if (!it) return;
    const slot = this.hand();
    const cx = Math.floor(Input.wx / CELL), cy = Math.floor(Input.wy / CELL);
    const inReach = dist(this.x, this.y - 28, Input.wx, Input.wy) <= this.reach();

    if (it.type === 'door' && inReach) {
      if (!canBuildAtCell(cx)) { this.say('В самой локации строить нельзя — отойди за её край'); return; }
      if (Doors.place(cx, cy)) this.inv.remove(slot.id, 1);
      return;
    }
    if (it.type === 'flag' && inReach) {
      if (!canBuildAtCell(cx)) { this.say('Дом ставится вне локаций — на пустоши или между ними'); return; }
      if (Home.place(cx, cy)) this.inv.remove(slot.id, 1);
      return;
    }
    if ((it.type === 'build' || it.type === 'place' || it.type === 'machine') && inReach && World.protectedAt(cx)) {
      this.say('Город трогать нельзя'); return;
    }
    if (it.type === 'build' && inReach) {
      if (!canBuildAtCell(cx)) { this.say('В самой локации строить нельзя — отойди за её край'); return; }
      // как в Майнкрафте: если целишь в занятую деталь, встаёт с той грани,
      // с которой ты смотришь — на любую поверхность, любой высоты и длины
      let bx = cx & ~1, by = cy & ~1;
      const busy = (gx, gy) => {
        for (let dx = 0; dx < 2; dx++) for (let dy = 0; dy < 2; dy++) {
          const m = World.get(gx + dx, gy + dy);
          if (m !== M.AIR && (MATS[m].build || MATS[m].door || MATS[m].metal)) return true;
        }
        return Machines.boxBusy(gx, gy + 1, 2, 2);
      };
      if (busy(bx, by)) {
        // грань выбираем по тому, куда именно попал курсор внутри детали
        const fx = Input.wx / CELL - bx, fy = Input.wy / CELL - by;
        const cand = [];
        if (fx < 0.5) cand.push([bx - 2, by], [bx + 2, by]); else cand.push([bx + 2, by], [bx - 2, by]);
        if (fy < 0.5) cand.unshift([bx, by - 2]); else cand.push([bx, by + 2]);
        const free = cand.find(([gx, gy]) => !busy(gx, gy));
        if (!free) { this.say('Здесь уже стоит деталь'); return; }
        bx = free[0]; by = free[1];
        if (!canBuildAtCell(bx)) { this.say('В самой локации строить нельзя'); return; }
      }
      let support = false;
      for (let dx = -1; dx <= 2 && !support; dx++) for (let dy = -1; dy <= 2 && !support; dy++) {
        if (dx >= 0 && dx <= 1 && dy >= 0 && dy <= 1) continue;
        if (World.get(bx + dx, by + dy) !== M.AIR) support = true;
      }
      if (!support) { this.say('Деталь должна к чему-то примыкать'); return; }
      for (let dx = 0; dx < 2; dx++) for (let dy = 0; dy < 2; dy++) World.set(bx + dx, by + dy, it.mat);
      Particles.burst(bx * CELL + CELL, by * CELL + CELL, [140, 106, 66], 5);
      this.inv.remove(slot.id, 1);
      this.unstuck();
      return;
    }
    if (it.type === 'place' && inReach) {
      if (World.get(cx, cy) !== M.AIR) { this.say('Место занято'); return; }
      // лестнице хватает стенки ствола в двух частицах или другой лестницы сверху-снизу
      const ok = it.mat === M.LADDER
        ? (World.hasSupportNear(cx, cy, 2) || World.ladderNear(cx, cy))
        : World.hasNeighbour(cx, cy);
      if (!ok) { this.say('Не к чему прикрепить'); return; }
      if (Math.abs(cx * CELL + 4 - this.x) < 10 && cy * CELL > this.y - this.h && cy * CELL < this.y) return;
      World.set(cx, cy, it.mat);
      this.inv.remove(slot.id, 1);
      return;
    }
    if (it.type === 'machine' && inReach) {
      if (Machines.place(slot.id, cx, cy)) this.inv.remove(slot.id, 1);
      return;
    }
    if (it.type === 'light' && inReach) {
      if (World.get(cx, cy) !== M.AIR) { this.say('Место занято'); return; }
      if (!World.hasSupportNear(cx, cy, 1)) { this.say('Факелу нужна стена или пол рядом'); return; }
      Machines.addTorch(cx, cy); this.inv.remove(slot.id, 1);
      return;
    }
    // предметы, которые надо куда-то поставить: если далеко — говорим об этом
    if (!inReach && ['build', 'place', 'machine', 'light', 'door', 'flag', 'seed'].includes(it.type)) {
      this.say('Слишком далеко — подойди ближе');
      return;
    }
    // всё, что просто применяется на себя, уходит в consume — работает и из инвентаря
    if (['food', 'drink', 'med', 'zinc', 'mask', 'filter'].includes(it.type)) {
      this.consume(this.hotbar);
      return;
    }
    if (it.type === 'canteen') {
      // набрать воды из лужи
      if (inReach && World.get(cx, cy) === M.WATER) {
        this.inv.remove(slot.id, 1); this.inv.add('canteen_dirty', 1);
        this.say('Набрал мутной воды');
      } else this.say('Нужна вода рядом');
      return;
    }
    if (it.type === 'seed') {
      if (inReach && Machines.plant(cx, cy, slot.id)) this.inv.remove(slot.id, 1);
      else this.say('Нужна грядка');
      return;
    }
    if (it.type === 'mask') { this.wearMask(); return; }
    if (it.type === 'filter') {
      if (!this.mask) { this.say('Противогаз не надет'); return; }
      this.filterWear = 100; this.inv.remove(slot.id, 1); this.say('Фильтр заменён');
      return;
    }
  },

  wearMask() {
    if (this.mask) return;
    if (!this.inv.remove('gasmask', 1)) return;
    this.mask = true; this.say('Противогаз надет. Дышать можно.');
  },
  removeMask() {
    if (!this.mask) return;
    this.mask = false;
    this.inv.add('gasmask', 1);
    this.say('Противогаз снят. Ты чувствуешь металлический привкус.');
  },

  // ---- оружие ----
  startReload(gun) {
    if (this.reload > 0) return;
    const id = gun.kind;
    if (this.mag[id] >= gun.mag) return;
    if (this.inv.count(gun.ammo) <= 0) { this.say('Нет патронов ' + ITEMS[gun.ammo].name); return; }
    this.reload = gun.kind === 'mg' ? 4.2 : gun.kind === 'rifle' ? 2.4 : 1.6;
    this.reloadGun = gun;
    this.say('Перезарядка...');
  },
  finishReload() {
    const gun = this.reloadGun; if (!gun) return;
    const need = gun.mag - this.mag[gun.kind];
    const have = Math.min(need, this.inv.count(gun.ammo));
    this.inv.remove(gun.ammo, have);
    this.mag[gun.kind] += have;
    this.reloadGun = null;
  },
  shoot(gun) {
    if (this.mag[gun.kind] <= 0) { this.say('Пусто — R'); this.cooldown = 0.4; return; }
    this.mag[gun.kind]--;
    this.cooldown = gun.rof;
    this.recoil = gun.rec;
    const spread = gun.spread * (2 - this.armPenalty()) * (1 - 0.12 * this.skills.aim);
    const dmg = gun.dmg * (1 + 0.08 * this.skills.aim);
    // дробовик кидает несколько картечин одним выстрелом
    const n = gun.pellets || 1;
    let mx = this.x, my = this.y - 41;
    for (let i = 0; i < n; i++) {
      const ang = this.aimAng + (Math.random() - 0.5) * spread;
      mx = this.x + Math.cos(ang) * 22; my = this.y - 41 + Math.sin(ang) * 22;
      Bullets.spawn(mx, my, ang, dmg, gun.kind);
    }
    Particles.flash(mx, my, this.aimAng);
    Game.shake = Math.min(6, Game.shake + gun.rec * 1.2);
  }
};
