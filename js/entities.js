// entities.js — частицы, пули, зомби, машины, лут на земле
'use strict';

const Particles = {
  list: [],
  burst(x, y, col, n) {
    for (let i = 0; i < n; i++) this.list.push({
      x, y, vx: rnd(-1.4, 1.4), vy: rnd(-2.2, 0.2), g: 0.14, life: rnd(0.4, 1.1), t: 0,
      s: rnd(1.4, 3.2), col: rgb(col[0] + rnd(-14, 14), col[1] + rnd(-14, 14), col[2] + rnd(-14, 14))
    });
  },
  blood(x, y) {
    this.list.push({ x, y, vx: rnd(-0.8, 0.8), vy: rnd(-0.4, 0.6), g: 0.2, life: 0.8, t: 0, s: rnd(1.2, 2.4), col: '#8e2a24' });
  },
  flash(x, y, ang) {
    for (let i = 0; i < 7; i++) this.list.push({
      x, y, vx: Math.cos(ang) * rnd(1, 5) + rnd(-0.6, 0.6), vy: Math.sin(ang) * rnd(1, 5) + rnd(-0.6, 0.6),
      g: 0.02, life: rnd(0.05, 0.16), t: 0, s: rnd(2, 4.5), col: i < 3 ? '#fff3c0' : '#f0a03c', glow: true
    });
    for (let i = 0; i < 4; i++) this.list.push({
      x, y, vx: rnd(-0.5, 0.5), vy: rnd(-0.9, -0.2), g: -0.02, life: rnd(0.3, 0.7), t: 0, s: rnd(2, 5), col: 'rgba(150,150,150,0.5)'
    });
  },
  smoke(x, y, col) {
    this.list.push({ x, y, vx: rnd(-0.25, 0.25), vy: rnd(-0.8, -0.35), g: -0.012, life: rnd(0.8, 1.8), t: 0, s: rnd(2.5, 5.5), col: col || 'rgba(120,120,120,0.42)' });
  },
  spark(x, y) {
    for (let i = 0; i < 5; i++) this.list.push({
      x, y, vx: rnd(-2, 2), vy: rnd(-2, 1), g: 0.16, life: rnd(0.1, 0.35), t: 0, s: rnd(1, 2), col: '#ffe6a0', glow: true
    });
  },
  update(dt) {
    for (let i = this.list.length - 1; i >= 0; i--) {
      const p = this.list[i];
      p.t += dt;
      if (p.t > p.life) { this.list.splice(i, 1); continue; }
      p.vy += p.g; p.x += p.vx; p.y += p.vy;
    }
    if (this.list.length > 1400) this.list.splice(0, this.list.length - 1400);
  },
  draw(ctx) {
    for (const p of this.list) {
      const a = 1 - p.t / p.life;
      ctx.globalAlpha = clamp(a, 0, 1);
      ctx.fillStyle = p.col;
      const s = p.s * (p.glow ? a + 0.4 : 1);
      ctx.fillRect(p.x - s / 2, p.y - s / 2, s, s);
    }
    ctx.globalAlpha = 1;
  }
};

const Floaters = {
  list: [],
  push(x, y, text, col) { this.list.push({ x, y, text, col: col || '#e8e2d0', t: 0 }); },
  update(dt) {
    for (let i = this.list.length - 1; i >= 0; i--) {
      const f = this.list[i]; f.t += dt; f.y -= dt * 16;
      if (f.t > 1.6) this.list.splice(i, 1);
    }
  },
  draw(ctx) {
    ctx.font = '600 9px system-ui, sans-serif'; ctx.textAlign = 'center';
    for (const f of this.list) {
      ctx.globalAlpha = clamp(1.6 - f.t, 0, 1) * 0.95;
      ctx.fillStyle = 'rgba(0,0,0,0.5)'; ctx.fillText(f.text, f.x + 0.8, f.y + 0.8);
      ctx.fillStyle = f.col; ctx.fillText(f.text, f.x, f.y);
    }
    ctx.globalAlpha = 1; ctx.textAlign = 'left';
  }
};

const Bullets = {
  list: [],
  spawn(x, y, ang, dmg, kind, foe) {
    const sp = kind === 'pistol' ? 15 : kind === 'rifle' ? 21 : 24;
    // foe — пуля врага: бьёт игрока и не трогает своих
    this.list.push({ x, y, px: x, py: y, vx: Math.cos(ang) * sp, vy: Math.sin(ang) * sp, dmg, life: 1.1, t: 0, foe: !!foe });
  },
  update(dt) {
    for (let i = this.list.length - 1; i >= 0; i--) {
      const b = this.list[i];
      b.t += dt;
      b.px = b.x; b.py = b.y;
      let hit = false;
      for (let s = 0; s < 4; s++) {
        b.x += b.vx / 4; b.y += b.vy / 4;
        b.vy += 0.05;
        if (World.solid(Math.floor(b.x / CELL), Math.floor(b.y / CELL))) {
          Particles.spark(b.x, b.y);
          const mi = World.info(Math.floor(b.x / CELL), Math.floor(b.y / CELL));
          if (mi) Particles.burst(b.x, b.y, mi.c, 2);
          hit = true; break;
        }
        // вражеская пуля ищет игрока, своя — зомби
        if (b.foe) {
          if (!Player.dead && Math.abs(b.x - Player.x) < 10 && b.y > Player.y - 52 && b.y < Player.y) {
            Player.hp -= b.dmg;
            if (Math.random() < 0.4) Player.wound(pick(['torso', 'armL', 'armR', 'legL', 'legR']), Math.random() < 0.25 ? 2 : 1);
            for (let k = 0; k < 6; k++) Particles.blood(b.x, b.y);
            Game.shake = 4;
            hit = true; break;
          }
          continue;
        }
        for (const z of Zombies.list) {
          if (z.hp <= 0) continue;
          if (Math.abs(b.x - z.x) < 9 && b.y > z.y - 48 && b.y < z.y) {
            const head = b.y < z.y - 38;
            z.hp -= b.dmg * (head ? 2.4 : 1);
            z.vx += Math.sign(b.vx) * 0.7;
            for (let k = 0; k < 6; k++) Particles.blood(b.x, b.y);
            Floaters.push(b.x, b.y - 6, head ? 'в голову!' : '' + Math.round(b.dmg * (head ? 2.4 : 1)), head ? '#ffd27a' : '#d8b0a0');
            hit = true; break;
          }
        }
        if (hit) break;
      }
      if (hit || b.t > b.life) this.list.splice(i, 1);
    }
  },
  draw(ctx) {
    ctx.strokeStyle = '#ffe9a8'; ctx.lineWidth = 1.4; ctx.lineCap = 'round';
    for (const b of this.list) {
      ctx.globalAlpha = 0.9;
      ctx.beginPath(); ctx.moveTo(b.px, b.py); ctx.lineTo(b.x, b.y); ctx.stroke();
    }
    ctx.globalAlpha = 1;
  }
};

// Двадцать видов заражённых. tier — насколько поздно встречается и насколько
// страшен: по нему же растёт сложность этажей в небоскрёбе
const ZTYPES = [
  { id: 'shambler',  name: 'Бродяга',        tier: 1,  hp: 55,   spd: 0.55, dmg: 6,  scale: 0.79, skin: '#79906f', rag: '#4e4b3f' },
  { id: 'crawler',   name: 'Ползун',         tier: 2,  hp: 40,   spd: 0.75, dmg: 5,  scale: 0.62, skin: '#8a9c78', rag: '#46443a', low: true },
  { id: 'dog',       name: 'Заражённый пёс', tier: 3,  hp: 45,   spd: 1.45, dmg: 9,  scale: 0.70, skin: '#7d6a52', rag: '#5a4a38', quad: true },
  { id: 'runner',    name: 'Бегун',          tier: 4,  hp: 55,   spd: 1.3, dmg: 8,  scale: 0.76, skin: '#93a381', rag: '#3f4438' },
  { id: 'worker',    name: 'Рабочий',        tier: 5,  hp: 95,   spd: 0.65, dmg: 10, scale: 0.82, skin: '#6f8566', rag: '#7a6a2e', helmet: true },
  { id: 'bloated',   name: 'Раздутый',       tier: 6,  hp: 130,  spd: 0.42, dmg: 12, scale: 0.92, skin: '#8fa07e', rag: '#4a4a3c', fat: true },
  { id: 'spitter',   name: 'Плевун',         tier: 7,  hp: 70,   spd: 0.7,  dmg: 7,  scale: 0.79, skin: '#7fa06a', rag: '#3e4c36', spit: true },
  { id: 'wolf',      name: 'Волк-мутант',    tier: 8,  hp: 85,   spd: 1.6, dmg: 14, scale: 0.79, skin: '#6a6152', rag: '#4a4438', quad: true },
  { id: 'soldier',   name: 'Солдат',         tier: 9,  hp: 140,  spd: 0.9, dmg: 14, scale: 0.82, skin: '#6c8062', rag: '#4b5540', armor: true, helmet: true },
  { id: 'burnt',     name: 'Обожжённый',     tier: 10, hp: 110,  spd: 0.95, dmg: 13, scale: 0.79, skin: '#5c534c', rag: '#33302c', burn: true },
  { id: 'stalker',   name: 'Сталкер',        tier: 11, hp: 120,  spd: 1.15, dmg: 15, scale: 0.80, skin: '#6d8a70', rag: '#43503f', mask: true },
  { id: 'brute',     name: 'Громила',        tier: 12, hp: 260,  spd: 0.6,  dmg: 22, scale: 1.04, skin: '#758a68', rag: '#4a4738', fat: true },
  { id: 'hound',     name: 'Гончая пепла',   tier: 13, hp: 130,  spd: 1.8,  dmg: 18, scale: 0.82, skin: '#4f4a45', rag: '#3a3632', quad: true, burn: true },
  { id: 'medic',     name: 'Санитар',        tier: 14, hp: 170,  spd: 0.95, dmg: 16, scale: 0.82, skin: '#87a184', rag: '#c9c6bb', heals: true },
  { id: 'trooper',   name: 'Штурмовик',      tier: 15, hp: 220,  spd: 1.0,  dmg: 20, scale: 0.84, skin: '#66795e', rag: '#3f4a3a', armor: true, helmet: true },
  { id: 'juggernaut',name: 'Тяжёлый',        tier: 16, hp: 420,  spd: 0.55, dmg: 28, scale: 1.12, skin: '#6b7d62', rag: '#4c5340', armor: true, fat: true },
  { id: 'screamer',  name: 'Крикун',         tier: 17, hp: 200,  spd: 1.1, dmg: 17, scale: 0.85, skin: '#9fb08c', rag: '#3c4636', screams: true },
  { id: 'gunner',    name: 'Стрелок',        tier: 18, hp: 240,  spd: 0.9,  dmg: 18, scale: 0.84, skin: '#6a7f66', rag: '#454f3c', armor: true, gun: 'pistol' },
  { id: 'officer',   name: 'Офицер',         tier: 19, hp: 340,  spd: 1.05, dmg: 24, scale: 0.87, skin: '#647a5e', rag: '#3b4636', armor: true, helmet: true, gun: 'rifle' },
  { id: 'warlord',   name: 'Хозяин высотки', tier: 20, hp: 900,  spd: 1.0, dmg: 34, scale: 1.24, skin: '#5f7358', rag: '#33402f', armor: true, helmet: true, gun: 'mg', boss: true }
];
function ztype(i) { return ZTYPES[clamp(i, 0, ZTYPES.length - 1)]; }

const Zombies = {
  list: [],
  // Гнёзда: заранее размеченные места на этажах башен. Зомби не висят в мире
  // постоянно — они поднимаются, когда игрок подходит, и исчезают, когда уходит.
  // Убитые не возвращаются
  nests: [],
  addNest(x, y, tier) { this.nests.push({ x, y, tier, alive: null, cleared: false }); },
  // Этажный зомби привязан к своему этажу: он не сходит с него и не падает вниз.
  // Иначе вся башня осыпалась игроку на голову
  holdFloor(z, dt) {
    const n = z.nest;
    if (!n) return;
    if (Math.abs(z.y - n.y) > 40) {          // сорвался или всплыл — возвращаем
      z.y = n.y; z.vy = 0; z.onGround = true;
    }
    if (Math.abs(z.x - n.x) > 150) {          // не убегает с этажа далеко
      z.x = clamp(z.x, n.x - 150, n.x + 150);
      z.vx = 0;
    }
  },
  updateNests() {
    for (const n of this.nests) {
      if (n.cleared) continue;
      const near = Math.abs(n.x - Player.x) < 1400 && Math.abs(n.y - Player.y) < 1400;
      if (near && !n.alive) {
        n.alive = this.make(n.x, n.y, n.tier, Player.x > n.x ? 1 : -1);
        n.alive.nest = n;
      } else if (!near && n.alive) {
        const i = this.list.indexOf(n.alive);
        if (i >= 0) this.list.splice(i, 1);
        n.alive = null;
      }
    }
  },
  spawnTimer: 4,
  update(dt) {
    this.updateNests();
    // ночью лезут, днём почти нет; в мёртвой зоне лезут всегда, в городе никогда
    const night = Game.nightAmount();
    const zm = zoneAtPx(Player.x).zombies;
    this.spawnTimer -= dt * (0.3 + night * 2.4) * zm;
    const cap = Math.round((3 + night * 7) * zm);
    if (zm <= 0) { this.list.length = 0; }
    else if (this.spawnTimer <= 0 && this.list.length < cap) {
      this.spawnTimer = rnd(2.5, 7) / Math.max(0.4, zm);
      this.spawn();
    }
    for (let i = this.list.length - 1; i >= 0; i--) {
      const z = this.list[i];
      if (z.hp <= 0) {
        if (!z.counted) {
          z.counted = true;
          const tier = z.type ? z.type.tier : 1;
          const gain = Math.round((1 + tier * 0.6) * (Player.skills.trade >= 3 ? 1.5 : 1));
          Player.coins += gain;
          Player.kills++;
          Missions.onKill();
          Floaters.push(z.x, z.y - 50, '+' + gain + ' монет', '#e8cf72');
        }
        if (z.nest) { z.nest.cleared = true; z.nest.alive = null; z.nest = null; }
        z.dieT = (z.dieT || 0) + dt;
        if (z.dieT > 0.9) {
          // чем страшнее был враг, тем интереснее с него падает
          const tt = z.type || ZTYPES[0];
          if (Math.random() < 0.75) Drops.add(z.x, z.y - 10, Math.random() < 0.55 ? 'rag' : 'meat_rot', 1);
          if (tt.armor && Math.random() < 0.5) Drops.add(z.x, z.y - 10, 'scrap', irnd(1, 3));
          if (tt.gun && Math.random() < 0.6) {
            const ammo = tt.gun === 'pistol' ? 'ammo9' : tt.gun === 'rifle' ? 'ammo545' : 'ammo762';
            Drops.add(z.x, z.y - 10, ammo, irnd(6, 18));
          }
          if (tt.boss) {
            Drops.add(z.x, z.y - 12, 'mg', 1);
            Drops.add(z.x + 10, z.y - 12, 'zinc762', 1);
            Drops.add(z.x - 10, z.y - 12, 'medkit', 2);
          }
          this.list.splice(i, 1);
        }
        continue;
      }
      const dx = Player.x - z.x;
      const far = Math.abs(dx) > 900;
      if (far && !z.nest) { this.list.splice(i, 1); continue; }
      z.face = dx > 0 ? 1 : -1;
      const t = z.type || ZTYPES[0];
      const see = Math.abs(dx) < (t.gun ? 620 : 320) && !Player.dead;
      let spd = see ? z.speed : z.speed * 0.35;
      // вооружённые не лезут в упор: подходят на дистанцию выстрела и стреляют
      if (t.gun && see && Math.abs(dx) < 210) spd = -z.speed * 0.5;
      z.vx = (see ? z.face : z.wander) * spd;
      if (t.gun && see) {
        z.shootCd -= dt;
        if (z.shootCd <= 0 && Math.abs(dx) < 620) {
          z.shootCd = t.gun === 'mg' ? rnd(0.12, 0.2) : t.gun === 'rifle' ? rnd(0.5, 1.1) : rnd(0.9, 1.6);
          const ang = Math.atan2((Player.y - 30) - (z.y - 34), Player.x - z.x) + rnd(-0.09, 0.09);
          Bullets.spawn(z.x + z.face * 12, z.y - 34, ang, t.gun === 'mg' ? 9 : t.gun === 'rifle' ? 12 : 8, t.gun, true);
          Particles.flash(z.x + z.face * 18, z.y - 34, ang);
        }
      }
      // крикун зовёт остальных
      if (t.screams && see && Math.random() < dt * 0.35) {
        for (const o of this.list) if (o !== z && Math.abs(o.x - z.x) < 700) o.alerted = 2;
      }
      z.phase += dt * (4 + spd * 3);

      // Прыжок только через невысокий уступ вверх. Вниз зомби не сигают:
      // раньше они прыгали с этажей прямо на голову игроку
      const aheadX = z.x + z.face * 10;
      const acx = Math.floor(aheadX / CELL);
      if (z.onGround && World.solid(acx, Math.floor((z.y - 6) / CELL))) z.vy = -4.4;

      // край этажа: если впереди пропасть глубже трёх частиц — разворачиваемся
      if (z.onGround) {
        let drop = 0;
        const fy = Math.floor(z.y / CELL);
        while (drop < 5 && !World.solid(acx, fy + drop)) drop++;
        if (drop >= 4) {
          z.vx = 0;
          z.wander = -z.wander;
          if (!z.nest) z.face = -z.face;      // на этаже разворачиваемся, но не уходим
        }
      }

      z.vy = Math.min(z.vy + GRAV, 13);
      // движение
      const nx = z.x + z.vx;
      if (!this.hits(z, nx, z.y)) z.x = nx; else if (z.onGround && z.vx !== 0) z.vy = -4.2;
      const ny = z.y + z.vy;
      if (!this.hits(z, z.x, ny)) { z.y = ny; z.onGround = false; }
      else {
        if (z.vy > 0) { while (!this.hits(z, z.x, z.y + 1)) z.y += 1; z.onGround = true; }
        z.vy = 0;
      }
      this.holdFloor(z, dt);

      // атака
      z.cd = Math.max(0, (z.cd || 0) - dt);
      if (!Player.dead && Math.abs(Player.x - z.x) < 16 && Math.abs(Player.y - z.y) < 40 && z.cd <= 0) {
        z.cd = 1.15;
        Player.hp -= z.dmg;
        const limb = pick(['armL', 'armR', 'legL', 'legR', 'torso', 'head']);
        if (Math.random() < 0.55) Player.wound(limb, Math.random() < 0.22 ? 2 : 1);
        for (let k = 0; k < 8; k++) Particles.blood(Player.x, Player.y - 30);
        Game.shake = 5;
      }
    }
  },
  hits(z, x, y) {
    const x0 = Math.floor((x - 6) / CELL), x1 = Math.floor((x + 6) / CELL);
    const y0 = Math.floor((y - 46) / CELL), y1 = Math.floor((y - 1) / CELL);
    for (let cy = y0; cy <= y1; cy++) for (let cx = x0; cx <= x1; cx++) if (World.solid(cx, cy)) return true;
    return false;
  },
  // Кого именно поднимать: зависит от опасности локации и от прожитых дней.
  // В спокойных местах бродяги и псы, в мёртвой зоне — солдаты и громилы
  pickTier() {
    const z = zoneAtPx(Player.x);
    const danger = z.zombies || 1;
    const byDay = Math.min(6, (Game.day - 1) * 0.6);
    const base = danger * 2.2 + byDay;
    const spread = 2 + danger;
    return clamp(Math.round(base + rnd(-spread, spread)), 0, ZTYPES.length - 4);
  },

  make(x, y, tierIdx, face) {
    const t = ztype(tierIdx);
    const z = {
      type: t, x, y, vx: 0, vy: 0,
      hp: t.hp * rnd(0.9, 1.15), maxHp: t.hp,
      dmg: t.dmg, speed: t.spd * rnd(0.92, 1.08),
      face: face || (Math.random() < 0.5 ? -1 : 1),
      phase: Math.random() * 6, onGround: false,
      wander: Math.random() < 0.5 ? -1 : 1,
      pale: Math.random() < 0.4, shootCd: rnd(1, 3)
    };
    z.maxHp = z.hp;
    this.list.push(z);
    return z;
  },

  spawn() {
    const side = Math.random() < 0.5 ? -1 : 1;
    const x = Player.x + side * rnd(340, 620);
    const cx = clamp(Math.floor(x / CELL), 4, WW - 5);
    const y = (World.surface[cx] - 1) * CELL;
    return this.make(cx * CELL, y, this.pickTier(), -side);
  },
  draw(ctx) {
    for (const z of this.list) {
      if (z.hp <= 0) {
        ctx.save(); ctx.globalAlpha = clamp(1 - (z.dieT || 0) / 0.9, 0, 1);
        ctx.translate(z.x, z.y); ctx.rotate(z.face * 1.5); ctx.translate(-z.x, -z.y);
        drawZombie(ctx, z.x, z.y, z); ctx.restore();
        continue;
      }
      drawZombie(ctx, z.x, z.y, z);
      if (z.hp < 95) {
        ctx.fillStyle = 'rgba(0,0,0,0.5)'; ctx.fillRect(z.x - 12, z.y - 58, 24, 3);
        ctx.fillStyle = '#a8402f'; ctx.fillRect(z.x - 12, z.y - 58, 24 * clamp(z.hp / 95, 0, 1), 3);
      }
    }
  }
};

// ---- лут на земле и ящики ----
const Drops = {
  list: [],
  add(x, y, id, n, vx, vy, noPick) {
    this.list.push({
      x, y, id, n, t: 0, crate: false,
      vx: vx !== undefined ? vx : rnd(-0.6, 0.6),
      vy: vy !== undefined ? vy : -1.2,
      noPick: noPick || 0        // сколько секунд предмет нельзя поднять обратно
    });
  },
  addCrate(cx, cy, loot, military) {
    this.list.push({ x: cx * CELL, y: cy * CELL, crate: true, military, loot, opened: false, t: 0 });
  },
  update(dt) {
    for (const d of this.list) {
      d.t += dt;
      if (d.crate) continue;
      d.vy = Math.min(d.vy + GRAV * 0.6, 8);
      if (!World.solid(Math.floor((d.x + d.vx) / CELL), Math.floor(d.y / CELL))) d.x += d.vx; else d.vx *= -0.4;
      if (!World.solid(Math.floor(d.x / CELL), Math.floor((d.y + d.vy) / CELL))) d.y += d.vy;
      else { d.vy = 0; d.vx *= 0.7; }
    }
  },
  nearest(x, y, r) {
    let best = null, bd = r;
    for (const d of this.list) {
      if (d.crate && d.opened) continue;
      if (d.noPick && d.t < d.noPick) continue;
      const dd = dist(x, y, d.x, d.y - (d.crate ? 8 : 0));
      if (dd < bd) { bd = dd; best = d; }
    }
    return best;
  },
  take(d) {
    if (d.crate) {
      d.opened = true;
      for (const [id, n] of d.loot) {
        if (Player.inv.add(id, n) > 0) Drops.add(d.x + rnd(-8, 8), d.y - 12, id, n);
        Floaters.push(d.x, d.y - 16 - Math.random() * 10, '+' + n + ' ' + ITEMS[id].name, '#d8e0b0');
      }
      Player.say('Ящик вскрыт');
      Particles.burst(d.x, d.y - 8, [126, 96, 62], 8);
      return;
    }
    const left = Player.inv.add(d.id, d.n);
    if (left > 0) { d.n = left; Player.say('Инвентарь полон'); return; }
    Floaters.push(d.x, d.y - 10, '+' + d.n + ' ' + ITEMS[d.id].name, '#d8e0b0');
    this.list.splice(this.list.indexOf(d), 1);
  },
  draw(ctx) {
    for (const d of this.list) {
      if (d.crate) {
        const w = d.military ? 26 : 22, h = 16;
        ctx.save(); ctx.translate(d.x, d.y - h);
        ctx.fillStyle = d.opened ? 'rgba(60,50,40,0.6)' : (d.military ? '#4a5340' : '#7c5a34');
        ctx.beginPath(); ctx.roundRect(-w / 2, 0, w, h, 2); ctx.fill();
        ctx.fillStyle = 'rgba(0,0,0,0.3)'; ctx.fillRect(-w / 2, h * 0.45, w, 2);
        ctx.fillStyle = d.military ? '#39402f' : '#5e4326';
        ctx.fillRect(-w / 2 + 2, 2, 3, h - 4); ctx.fillRect(w / 2 - 5, 2, 3, h - 4);
        if (d.military && !d.opened) {
          ctx.fillStyle = '#c9b166'; ctx.font = '700 6px system-ui'; ctx.textAlign = 'center';
          ctx.fillText('ARMY', 0, h * 0.4); ctx.textAlign = 'left';
        }
        if (!d.opened) {
          ctx.globalAlpha = 0.35 + Math.sin(d.t * 3) * 0.2;
          ctx.strokeStyle = '#e8dfa8'; ctx.lineWidth = 1;
          ctx.beginPath(); ctx.roundRect(-w / 2 - 1.5, -1.5, w + 3, h + 3, 3); ctx.stroke();
          ctx.globalAlpha = 1;
        }
        ctx.restore();
        continue;
      }
      const bob = Math.sin(d.t * 2.6) * 1.6;
      ctx.save(); ctx.translate(d.x - 8, d.y - 16 + bob);
      ctx.globalAlpha = 0.45; ctx.fillStyle = '#000';
      ctx.beginPath(); ctx.ellipse(8, 18 - bob, 7, 2.4, 0, 0, 7); ctx.fill();
      ctx.globalAlpha = 1;
      ITEMS[d.id].icon(ctx, 16);
      ctx.restore();
    }
  }
};

// ---- двери: проём 2×7, закрытая держит зомби ----
const Doors = {
  list: [],
  W: 2, H: 7,
  place(cx, cy) {
    // cy — верх проёма; вниз до опоры
    const x0 = cx, y0 = cy;
    for (let dx = 0; dx < this.W; dx++) for (let dy = 0; dy < this.H; dy++) {
      if (World.get(x0 + dx, y0 + dy) !== M.AIR) { Player.say('Проёму мешает порода'); return false; }
    }
    let support = false;
    for (let dx = 0; dx < this.W; dx++) if (World.solid(x0 + dx, y0 + this.H)) support = true;
    if (!support) { Player.say('Двери нужен пол под низом'); return false; }
    if (this.at(x0, y0)) { Player.say('Здесь уже дверь'); return false; }
    for (let dx = 0; dx < this.W; dx++) for (let dy = 0; dy < this.H; dy++) World.set(x0 + dx, y0 + dy, M.DOOR);
    this.list.push({ x: x0, y: y0, open: false, anim: 0 });
    return true;
  },
  at(cx, cy) {
    return this.list.find(d => cx >= d.x - 1 && cx < d.x + this.W + 1 && cy >= d.y - 1 && cy < d.y + this.H + 1);
  },
  nearest(px, py, r) {
    let best = null, bd = r;
    for (const d of this.list) {
      const dd = dist(px, py, (d.x + this.W / 2) * CELL, (d.y + this.H / 2) * CELL);
      if (dd < bd) { bd = dd; best = d; }
    }
    return best;
  },
  toggle(d) {
    d.open = !d.open;
    const mat = d.open ? M.DOOR_OPEN : M.DOOR;
    // не закрываемся прямо на игроке
    if (!d.open) {
      const px = Math.floor(Player.x / CELL);
      if (px >= d.x - 1 && px <= d.x + this.W && Math.abs(Player.y - (d.y + this.H) * CELL) < 60) {
        d.open = true; Player.say('Ты стоишь в проёме'); return;
      }
    }
    for (let dx = 0; dx < this.W; dx++) for (let dy = 0; dy < this.H; dy++) World.set(d.x + dx, d.y + dy, mat);
    Player.say(d.open ? 'Дверь открыта' : 'Дверь закрыта');
  },
  update(dt) {
    for (const d of this.list) d.anim = lerp(d.anim, d.open ? 1 : 0, Math.min(1, dt * 9));
  },
  draw(ctx) {
    for (const d of this.list) {
      const w = this.W * CELL, h = this.H * CELL;
      const px = d.x * CELL, py = d.y * CELL;
      // рама
      ctx.fillStyle = '#5a4026';
      ctx.fillRect(px - 2, py - 3, w + 4, 3);
      ctx.fillRect(px - 2, py - 3, 2, h + 3);
      ctx.fillRect(px + w, py - 3, 2, h + 3);
      // полотно: при открытии сжимается в сторону петель
      const openW = lerp(w, w * 0.18, d.anim);
      ctx.save();
      ctx.translate(px, py);
      const gr = ctx.createLinearGradient(0, 0, openW, 0);
      gr.addColorStop(0, '#7c5730'); gr.addColorStop(0.5, '#96703f'); gr.addColorStop(1, '#6b4a26');
      ctx.fillStyle = gr;
      ctx.fillRect(0, 0, openW, h);
      // доски и обвязка
      ctx.fillStyle = 'rgba(40,26,16,0.4)';
      for (let i = 1; i < 3; i++) ctx.fillRect(0, h * i / 3, openW, 1.4);
      ctx.fillStyle = 'rgba(255,240,210,0.12)';
      for (let i = 1; i < 3; i++) ctx.fillRect(0, h * i / 3 + 1.4, openW, 1);
      // петли и ручка
      ctx.fillStyle = '#4a4d52';
      ctx.fillRect(-1, h * 0.16, 3.4, 4);
      ctx.fillRect(-1, h * 0.74, 3.4, 4);
      if (d.anim < 0.5) {
        ctx.fillStyle = '#c9a94a';
        ctx.beginPath(); ctx.arc(openW - 4, h * 0.5, 1.8, 0, 7); ctx.fill();
      }
      ctx.restore();
    }
  }
};

// ---- дом: один флажок на всю игру, внутри радиации нет ----
const Home = {
  flag: null,
  R: 170,                       // радиус дома вокруг флажка
  place(cx, cy) {
    if (this.flag) { Player.say('Флажок уже стоит. Забери его, чтобы перенести дом'); return false; }
    if (!World.solid(cx, cy + 1)) { Player.say('Флажок нужно ставить на землю или пол'); return false; }
    this.flag = { x: cx * CELL + 4, y: (cy + 1) * CELL, t: 0 };
    Player.say('Дом отмечен. Внутри радиация тебя не тронет');
    return true;
  },
  take() {
    if (!this.flag) return false;
    this.flag = null;
    Player.inv.add('home_flag', 1);
    Player.say('Флажок снят. Дом больше не защищает');
    return true;
  },
  inside(px, py) {
    if (!this.flag) return false;
    return Math.abs(px - this.flag.x) < this.R && Math.abs(py - this.flag.y) < this.R * 0.8;
  },
  nearFlag(px, py, r) {
    if (!this.flag) return false;
    return dist(px, py, this.flag.x, this.flag.y - 20) < r;
  },
  update(dt) { if (this.flag) this.flag.t += dt; },
  draw(ctx) {
    const f = this.flag; if (!f) return;
    // граница дома: пунктирная линия по земле
    ctx.strokeStyle = 'rgba(210,180,110,0.22)'; ctx.lineWidth = 1; ctx.setLineDash([6, 6]);
    ctx.beginPath();
    ctx.moveTo(f.x - this.R, f.y - 2); ctx.lineTo(f.x + this.R, f.y - 2);
    ctx.stroke(); ctx.setLineDash([]);
    // древко
    ctx.strokeStyle = '#8a7a5a'; ctx.lineWidth = 2.4; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(f.x, f.y); ctx.lineTo(f.x, f.y - 42); ctx.stroke();
    // полотно, слегка колышется
    const w = Math.sin(f.t * 2.2) * 2.5;
    ctx.fillStyle = '#b8452f';
    ctx.beginPath();
    ctx.moveTo(f.x + 1, f.y - 41);
    ctx.quadraticCurveTo(f.x + 12, f.y - 38 + w, f.x + 24, f.y - 34 - w);
    ctx.quadraticCurveTo(f.x + 13, f.y - 28 + w, f.x + 1, f.y - 26);
    ctx.fill();
    ctx.fillStyle = 'rgba(255,255,255,0.22)';
    ctx.beginPath();
    ctx.moveTo(f.x + 1, f.y - 41);
    ctx.quadraticCurveTo(f.x + 10, f.y - 38 + w, f.x + 14, f.y - 36 - w);
    ctx.lineTo(f.x + 1, f.y - 33);
    ctx.fill();
    ctx.fillStyle = '#5a4a30';
    ctx.beginPath(); ctx.ellipse(f.x, f.y, 5, 1.8, 0, 0, 7); ctx.fill();
  }
};

// ---- город: торговец и доска заданий ----
// Торговцы разные: у каждого своя специальность, свой прилавок и свой вид.
// Один торгует железом, другой лечит, третий продаёт патроны
const TRADERS = [
  {
    id: 'quartermaster', name: 'Завхоз', zone: 'city', at: 0.5, coat: '#6b5a3c', hat: '#4a3f2a',
    greet: 'Бери что надо, только не задерживай очередь.',
    stock: [['plank', 5, 6], ['stone', 10, 8], ['wood', 20, 10], ['coal', 5, 3],
            ['iron', 5, 8], ['copper', 5, 7], ['scrap', 5, 6], ['ladder', 4, 5]]
  },
  {
    id: 'medic', name: 'Фельдшер', zone: 'city', at: 0.28, coat: '#b9b3a2', hat: '#8f8b7c',
    greet: 'Раны показывай сразу, не жди, пока почернеют.',
    stock: [['bandage', 2, 9], ['splint', 1, 12], ['medkit', 1, 26], ['antirad', 1, 10],
            ['filter', 1, 14], ['can', 2, 12], ['canteen_clean', 2, 8], ['seeds', 2, 6]]
  },
  {
    id: 'gunsmith', name: 'Оружейник', zone: 'city', at: 0.72, coat: '#4a4e52', hat: '#33373b',
    greet: 'Патроны есть. Стрелять научишься сам.',
    stock: [['ammo9', 20, 12], ['ammo545', 20, 16], ['ammo762', 20, 20], ['buckshot', 10, 14],
            ['zinc9', 1, 90], ['pistol', 1, 120], ['sawnoff', 1, 140], ['shotgun', 1, 210],
            ['grenade', 1, 60]]
  },
  {
    id: 'prospector', name: 'Старатель', zone: 'mine', at: 0.5, coat: '#7a5a34', hat: '#5c4426',
    greet: 'Наверху за это дадут вдвое. Но наверх ещё дойти надо.',
    stock: [['pick', 1, 90], ['torch', 6, 8], ['coal', 10, 5], ['iron', 10, 14],
            ['drill', 1, 260], ['fuel', 5, 18], ['canteen_clean', 1, 5]]
  },
  {
    id: 'scav', name: 'Барахольщик', zone: 'waste', at: 0.78, coat: '#5e5344', hat: '#453c30',
    greet: 'Хлам? Это не хлам. Это запчасти.',
    stock: [['scrap', 10, 9], ['rag', 6, 4], ['plank', 6, 7], ['bandage', 1, 7],
            ['can', 1, 9], ['gasmask', 1, 140], ['filter', 2, 26]]
  }
];
// общий прайс на случай, если торговец не найден
const SHOP = TRADERS[0].stock;

const Missions = {
  list: [
    { id: 'iron', text: 'Принести 20 железа', need: { iron: 20 }, pay: 45, state: 0 },
    { id: 'kill', text: 'Уложить 15 зомби', kills: 15, pay: 55, state: 0, from: 0 },
    { id: 'food', text: 'Принести 10 печёной картошки', need: { potato_baked: 10 }, pay: 40, state: 0 },
    { id: 'coal', text: 'Принести 40 угля', need: { coal: 40 }, pay: 50, state: 0 }
  ],
  onKill() {
    for (const m of this.list) if (m.kills && m.state === 1 && Player.kills - m.from >= m.kills) m.state = 2;
  },
  accept(m) {
    if (m.state !== 0) return;
    m.state = 1;
    if (m.kills) m.from = Player.kills;
    Player.say('Задание взято: ' + m.text);
  },
  turnIn(m) {
    if (m.state === 0) { this.accept(m); return; }
    if (m.state === 3) { Player.say('Уже сдано'); return; }
    if (m.need) {
      if (!Player.inv.has(m.need)) { Player.say('Не хватает материалов'); return; }
      for (const k in m.need) Player.inv.remove(k, m.need[k]);
    } else if (m.state !== 2) {
      Player.say('Осталось убить: ' + (m.kills - (Player.kills - m.from))); return;
    }
    m.state = 3;
    Player.coins += m.pay;
    Player.say('Задание сдано: +' + m.pay + ' монет');
  },
  progress(m) {
    if (m.state === 3) return 'сдано';
    if (m.state === 0) return 'не взято';
    if (m.kills) return Math.min(m.kills, Player.kills - m.from) + '/' + m.kills + ' зомби';
    const k = Object.keys(m.need)[0];
    return Player.inv.count(k) + '/' + m.need[k] + ' ' + ITEMS[k].name.toLowerCase();
  }
};

const City = {
  trader: null, board: null, props: [], lamps: [], traders: [],
  build() {
    const z = ZONES.find(zz => zz.id === 'city');
    const cx = Math.floor((z.x0 + z.x1) / 2);
    const base = World.surface[cx];
    // каждый торговец стоит в своей локации на своём месте
    this.traders = [];
    for (const def of TRADERS) {
      const zz = ZONES.find(q => q.id === def.zone);
      if (!zz) continue;
      const tx = Math.round(zz.x0 + (zz.x1 - zz.x0) * def.at);
      this.traders.push({ def, x: tx * CELL, y: (World.surface[tx] - 1) * CELL, phase: Math.random() * 6 });
    }
    this.trader = this.traders[0];
    this.board = { x: (cx + 14) * CELL, y: (base - 1) * CELL };
    // фонари, бочки, мешки, ящики, вывески — то, что делает город обжитым
    this.props = []; this.lamps = [];
    const rand = mulberry32(31337);
    for (let i = 0; i < 9; i++) {
      const lx = z.x0 + 24 + i * 62;
      this.lamps.push({ x: lx * CELL, y: (World.surface[lx] - 1) * CELL, t: rand() * 9 });
    }
    for (let i = 0; i < 26; i++) {
      const px = z.x0 + 14 + Math.floor(rand() * (z.x1 - z.x0 - 28));
      const kind = rand() < 0.32 ? 'barrel' : rand() < 0.55 ? 'sandbag' : rand() < 0.8 ? 'crate' : 'banner';
      this.props.push({ x: px * CELL, y: (World.surface[px] - 1) * CELL, kind, r: rand() });
    }
  },
  lights() {
    return this.lamps.map(l => ({ x: l.x, y: l.y - 46, r: 190, i: 0.95 }));
  },
  nearest(x, y, r) {
    for (const t of this.traders) {
      if (dist(x, y, t.x, t.y - 26) < r) return { kind: 'trader', trader: t };
    }
    if (this.board && dist(x, y, this.board.x, this.board.y - 26) < r) return { kind: 'board' };
    return null;
  },
  update(dt) { for (const t of this.traders) t.phase += dt; },
  draw(ctx) {
    if (!this.traders.length) return;
    // Отсечение по экрану. Раньше вся обстановка города рисовалась с
    // градиентами каждый кадр, даже когда игрок был в другой локации, — это
    // съедало шестую часть кадра впустую.
    const v = Game.view;
    const vis = v ? (x, m) => x > v.x - m && x < v.x + v.w + m : () => true;
    // ---- обстановка города ----
    for (const p of this.props) {
      if (!vis(p.x, 80)) continue;
      ctx.save(); ctx.translate(p.x, p.y);
      if (p.kind === 'barrel') {
        const bg = ctx.createLinearGradient(-6, 0, 6, 0);
        bg.addColorStop(0, '#4a5a48'); bg.addColorStop(0.5, '#6d8168'); bg.addColorStop(1, '#3e4c3e');
        ctx.fillStyle = bg; ctx.beginPath(); ctx.roundRect(-6, -17, 12, 17, 2); ctx.fill();
        ctx.fillStyle = 'rgba(150,86,44,0.4)'; ctx.fillRect(-6, -12, 12, 2); ctx.fillRect(-6, -6, 12, 2);
        ctx.fillStyle = '#8a9a84'; ctx.beginPath(); ctx.ellipse(0, -17, 6, 2, 0, 0, 7); ctx.fill();
      } else if (p.kind === 'sandbag') {
        for (let r = 0; r < 2; r++) for (let i = 0; i < 3 - r; i++) {
          ctx.fillStyle = r ? '#8d8267' : '#7d7359';
          ctx.beginPath(); ctx.ellipse(-9 + i * 9 + r * 4.5, -4 - r * 6, 5.4, 3.4, 0, 0, 7); ctx.fill();
          ctx.strokeStyle = 'rgba(50,44,32,0.4)'; ctx.lineWidth = 0.7;
          ctx.beginPath(); ctx.ellipse(-9 + i * 9 + r * 4.5, -4 - r * 6, 5.4, 3.4, 0, 0, 7); ctx.stroke();
        }
      } else if (p.kind === 'crate') {
        ctx.fillStyle = '#7c5a34'; ctx.beginPath(); ctx.roundRect(-8, -15, 16, 15, 1.5); ctx.fill();
        ctx.strokeStyle = '#5e4326'; ctx.lineWidth = 1.6;
        ctx.beginPath(); ctx.moveTo(-8, -15); ctx.lineTo(8, 0); ctx.moveTo(8, -15); ctx.lineTo(-8, 0); ctx.stroke();
      } else {
        // тканевый баннер на шесте
        ctx.strokeStyle = '#5a4a30'; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(0, -34); ctx.stroke();
        ctx.fillStyle = p.r > 0.5 ? '#8a4a3c' : '#4a6a7a';
        ctx.beginPath(); ctx.moveTo(1, -33); ctx.lineTo(15, -31); ctx.lineTo(13, -18); ctx.lineTo(1, -20); ctx.fill();
        ctx.fillStyle = 'rgba(255,255,255,0.18)'; ctx.fillRect(3, -30, 9, 2);
      }
      ctx.restore();
    }
    // ---- фонари ----
    for (const l of this.lamps) {
      if (!vis(l.x, 140)) continue;
      l.t += 0.05;
      ctx.strokeStyle = '#4a4d52'; ctx.lineWidth = 2.6;
      ctx.beginPath(); ctx.moveTo(l.x, l.y); ctx.lineTo(l.x, l.y - 46); ctx.lineTo(l.x + 8, l.y - 46); ctx.stroke();
      const night = Game.nightAmount();
      const flick = 1 + Math.sin(l.t * 4) * 0.05;
      ctx.fillStyle = '#3c4046';
      ctx.beginPath(); ctx.moveTo(l.x + 3, l.y - 46); ctx.lineTo(l.x + 13, l.y - 46); ctx.lineTo(l.x + 11, l.y - 40); ctx.lineTo(l.x + 5, l.y - 40); ctx.fill();
      const gr = ctx.createRadialGradient(l.x + 8, l.y - 40, 0, l.x + 8, l.y - 40, 16 * flick);
      gr.addColorStop(0, 'rgba(255,240,190,' + (0.5 + night * 0.5) + ')');
      gr.addColorStop(1, 'rgba(255,210,120,0)');
      ctx.fillStyle = gr; ctx.beginPath(); ctx.arc(l.x + 8, l.y - 40, 16 * flick, 0, 7); ctx.fill();
    }
    // Каждый торговец рисуется в своём цвете и со своей вывеской
    for (const t of this.traders) {
      if (!vis(t.x, 120)) continue;
      const d = t.def;
      ctx.fillStyle = 'rgba(0,0,0,0.3)';
      ctx.beginPath(); ctx.ellipse(t.x, t.y, 10, 2.6, 0, 0, 7); ctx.fill();
      drawHuman(ctx, t.x, t.y, { skin: d.id.length % 5, hair: 1, hairStyle: 3, beard: true },
        { face: -1, phase: t.phase, moving: false, mask: d.zone !== 'city' });
      // плащ в цвете лавки
      ctx.fillStyle = d.coat;
      ctx.beginPath();
      ctx.moveTo(t.x - 8, t.y - 42); ctx.quadraticCurveTo(t.x - 12, t.y - 12, t.x - 9, t.y - 2);
      ctx.lineTo(t.x + 8, t.y - 2); ctx.quadraticCurveTo(t.x + 11, t.y - 16, t.x + 7, t.y - 42);
      ctx.fill();
      ctx.fillStyle = 'rgba(0,0,0,0.28)'; ctx.fillRect(t.x - 8, t.y - 26, 16, 3);
      // шапка
      ctx.fillStyle = d.hat;
      ctx.beginPath(); ctx.ellipse(t.x - 0.5, t.y - 54, 7, 3.4, 0, Math.PI, 0); ctx.fill();
      ctx.fillRect(t.x - 8, t.y - 54, 15, 2);
      // прилавок с товаром
      ctx.fillStyle = '#6b4a26'; ctx.beginPath(); ctx.roundRect(t.x + 14, t.y - 16, 30, 4, 1.5); ctx.fill();
      ctx.fillStyle = '#553a1e'; ctx.fillRect(t.x + 17, t.y - 12, 4, 12); ctx.fillRect(t.x + 37, t.y - 12, 4, 12);
      // на прилавке лежит то, чем он торгует
      ctx.save(); ctx.translate(t.x + 19, t.y - 30); ctx.scale(0.5, 0.5);
      const first = ITEMS[d.stock[0][0]]; if (first) first.icon(ctx, 20);
      ctx.restore();
      ctx.save(); ctx.translate(t.x + 31, t.y - 29); ctx.scale(0.42, 0.42);
      const second = ITEMS[d.stock[1][0]]; if (second) second.icon(ctx, 20);
      ctx.restore();
      // вывеска с именем
      const label = d.name.toUpperCase() + ' · E';
      ctx.font = '700 7px system-ui'; ctx.textAlign = 'center';
      const lw = Math.max(46, ctx.measureText(label).width + 12);
      ctx.fillStyle = 'rgba(20,20,18,0.85)';
      ctx.beginPath(); ctx.roundRect(t.x + 17 - lw / 2, t.y - 62, lw, 12, 2); ctx.fill();
      ctx.strokeStyle = d.coat; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.roundRect(t.x + 17 - lw / 2, t.y - 62, lw, 12, 2); ctx.stroke();
      ctx.fillStyle = '#d8c88a';
      ctx.fillText(label, t.x + 17, t.y - 53);
      ctx.textAlign = 'left';
    }

    // доска заданий
    const b = this.board;
    ctx.fillStyle = '#6b4a26'; ctx.fillRect(b.x - 2, b.y - 22, 4, 22);
    ctx.fillStyle = '#7c5a34'; ctx.beginPath(); ctx.roundRect(b.x - 16, b.y - 44, 32, 24, 2); ctx.fill();
    ctx.fillStyle = '#d8d2c0';
    for (let i = 0; i < 3; i++) ctx.fillRect(b.x - 12 + (i % 2) * 12, b.y - 40 + i * 6, 10, 6);
    ctx.fillStyle = 'rgba(20,20,18,0.85)';
    ctx.beginPath(); ctx.roundRect(b.x - 20, b.y - 60, 40, 12, 2); ctx.fill();
    ctx.fillStyle = '#d8c88a'; ctx.font = '700 7px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('ЗАДАНИЯ · E', b.x, b.y - 51);
    ctx.textAlign = 'left';
  }
};

// ---- машины ----
const Machines = {
  list: [],
  torches: [],
  defs: {
    workbench: { w: 4, h: 3, name: 'Верстак' },
    furnace: { w: 4, h: 4, name: 'Печь' },
    workbench2: { w: 5, h: 3, name: 'Верстак 2 ур.' },
    workbench3: { w: 6, h: 3, name: 'Верстак 3 ур.' },
    campfire: { w: 4, h: 2, name: 'Костёр' },
    drill: { w: 4, h: 5, name: 'Автобур' },
    farm: { w: 3, h: 1, name: 'Грядка' },
    refinery: { w: 5, h: 4, name: 'НПЗ' },
  },
  bed() { return this.list.find(m => m.type === 'bed'); },
  place(itemId, cx, cy) {
    const it = ITEMS[itemId];
    const def = this.defs[it.machine];
    // клик по полу или земле = поставить сверху: поднимаемся над твердью
    let base = cy;
    for (let i = 0; i < 4 && World.solid(cx, base); i++) base--;
    const x0 = cx - Math.floor(def.w / 2);
    if (!World.solid(cx, base + 1) && !World.solid(cx, base + 2)) { Player.say('Нужен пол или земля под низом'); return false; }
    if (this.boxBusy(x0, base, def.w, def.h)) { Player.say('Здесь уже стоит'); return false; }
    // тяжёлую машину не ставим себе под ноги
    if (def.h > 3 && Math.abs((x0 + def.w / 2) * CELL - Player.x) < 14) { Player.say('Отойди на шаг'); return false; }
    for (let x = x0; x < x0 + def.w; x++) {
      for (let y = base; y > base - def.h; y--) {
        const m = World.get(x, y);
        if (m !== M.AIR && !MATS[m].door) World.set(x, y, M.AIR);        // расчищаем место
      }
      if (!World.solid(x, base + 1)) World.set(x, base + 1, M.DIRT);      // подсыпаем опору
    }
    if (it.machine === 'farm') {
      const under = World.get(cx, base + 1);
      if (under !== M.GRASS && under !== M.DIRT && under !== M.CLAY) { Player.say('Грядка ставится на землю'); return false; }
      for (let x = x0; x < x0 + def.w; x++) World.set(x, base + 1, M.FARM);
    }
    this.list.push({
      type: it.machine, x: x0, y: base, w: def.w, h: def.h,
      fuel: 0, prog: 0, buffer: {}, seed: null, growth: 0, depth: 0, anim: 0
    });
    return true;
  },
  addTorch(cx, cy) { this.torches.push({ x: cx * CELL + 4, y: cy * CELL + 4, t: Math.random() * 9 }); },
  // строгое пересечение: две машины можно ставить вплотную друг к другу
  at(cx, cy) {
    return this.list.find(m => cx >= m.x && cx < m.x + m.w && cy <= m.y && cy > m.y - m.h);
  },
  // занята ли площадка под новую машину шириной w и высотой h
  boxBusy(x0, y0, w, h) {
    return this.list.some(m => x0 < m.x + m.w && x0 + w > m.x && y0 - h < m.y && y0 > m.y - m.h);
  },
  near(x, y, type) {
    return this.list.some(m => m.type === type && dist(x, y - 20, (m.x + m.w / 2) * CELL, m.y * CELL) < 90);
  },
  nearFire(x, y) {
    if (this.list.some(m => (m.type === 'campfire' || (m.type === 'furnace' && m.fuel > 0)) && dist(x, y - 20, (m.x + m.w / 2) * CELL, m.y * CELL) < 80)) return true;
    return this.torches.some(t => dist(x, y - 20, t.x, t.y) < 60);
  },
  plant(cx, cy, seedId) {
    const m = this.list.find(mm => mm.type === 'farm' && cx >= mm.x - 1 && cx <= mm.x + mm.w && Math.abs(cy - mm.y) <= 2);
    if (!m || m.seed) return false;
    m.seed = seedId; m.growth = 0;
    Player.say('Посажено');
    return true;
  },
  update(dt) {
    for (const m of this.list) {
      m.anim += dt;
      if (m.type === 'campfire') {
        if (Math.random() < dt * 14) Particles.smoke((m.x + m.w / 2) * CELL + rnd(-4, 4), (m.y - 1) * CELL, 'rgba(90,90,90,0.35)');
      }
      if (m.type === 'furnace' && m.fuel > 0) {
        m.fuel -= dt;
        if (Math.random() < dt * 8) Particles.smoke((m.x + m.w / 2) * CELL, (m.y - m.h) * CELL, 'rgba(70,70,70,0.4)');
      }
      if (m.type === 'farm' && m.seed) {
        const def = ITEMS[m.seed];
        m.growth = Math.min(def.grow, m.growth + dt);
      }
      if (m.type === 'refinery') {
        // уголь идёт вдвое эффективнее дерева
        if (m.fuel <= 0) {
          if ((m.buffer.coal || 0) > 0) { m.buffer.coal--; m.fuel = 8; m.yield = 2; }
          else if ((m.buffer.wood || 0) > 0) { m.buffer.wood--; m.fuel = 8; m.yield = 1; }
        }
        if (m.fuel > 0) {
          m.fuel -= dt; m.prog += dt;
          m.anim += dt;
          if (Math.random() < dt * 6) Particles.smoke((m.x + m.w - 1) * CELL, (m.y - m.h) * CELL, 'rgba(90,86,80,0.45)');
          if (m.prog > 2.4) {
            m.prog = 0;
            m.out = (m.out || 0) + (m.yield || 1);
            Floaters.push((m.x + m.w / 2) * CELL, (m.y - m.h) * CELL, '+' + (m.yield || 1) + ' топливо', '#e08a4a');
          }
        }
      }

      if (m.type === 'drill') {
        if (m.fuel <= 0) {
          // автозаправка из внутреннего запаса топлива
          if ((m.buffer.fuel || 0) > 0) { m.buffer.fuel--; m.fuel = 26; }
        }
        if (m.fuel > 0) {
          m.fuel -= dt;
          m.prog += dt;
          if (Math.random() < dt * 10) Particles.burst((m.x + m.w / 2) * CELL, (m.y + 1 + m.depth) * CELL, [110, 100, 92], 1);
          if (m.prog > 1.6) {
            m.prog = 0;
            const dy = m.y + 1 + m.depth;
            const cx = m.x + Math.floor(m.w / 2);
            let got = false;
            for (let x = m.x; x < m.x + m.w; x++) {
              const mat = World.get(x, dy);
              if (mat !== M.AIR && mat !== M.WATER) {
                const drop = MATS[mat].drop;
                if (drop) m.buffer[drop] = (m.buffer[drop] || 0) + 1;
                World.set(x, dy, M.AIR);
                got = true;
              }
            }
            if (!got) m.depth++;
            if (dy > WH - 4) m.depth = 0;
          }
        }
      }
    }
  },
  // взаимодействие: забрать из бура, собрать урожай, заправить
  interact(m) {
    if (m.type === 'refinery') {
      // забираем готовое топливо
      if ((m.out || 0) > 0) {
        const left = Player.inv.add('fuel', m.out);
        const got = m.out - left; m.out = left;
        if (got) { Player.say('Забрал топливо: ' + got); return; }
      }
      // загружаем сырьё
      const coal = Player.inv.count('coal'), wood = Player.inv.count('wood');
      if (coal > 0) {
        const n = Math.min(20, coal);
        Player.inv.remove('coal', n); m.buffer.coal = (m.buffer.coal || 0) + n;
        Player.say('НПЗ загружен: ' + n + ' угля'); return;
      }
      if (wood > 0) {
        const n = Math.min(40, wood);
        Player.inv.remove('wood', n); m.buffer.wood = (m.buffer.wood || 0) + n;
        Player.say('НПЗ загружен: ' + n + ' дерева'); return;
      }
      Player.say('Нужен уголь или дерево');
      return;
    }
    if (m.type === 'drill') {
      let took = 0;
      // сначала заправляем топливом из инвентаря
      const fuel = Player.inv.count('fuel');
      if (m.fuel <= 0 && (m.buffer.fuel || 0) === 0 && fuel > 0) {
        const n = Math.min(10, fuel);
        Player.inv.remove('fuel', n);
        m.buffer.fuel = (m.buffer.fuel || 0) + n;
        Player.say('Заправил бур: ' + n + ' топлива');
        return;
      }
      for (const id in m.buffer) {
        if (id === 'fuel') continue;
        const n = m.buffer[id];
        if (n <= 0) continue;
        const left = Player.inv.add(id, n);
        m.buffer[id] = left;
        took += n - left;
      }
      if (took) { Player.say('Забрал из бура: ' + took); Floaters.push((m.x + m.w / 2) * CELL, m.y * CELL - 20, '+' + took, '#cfe0b0'); }
      else Player.say(m.fuel > 0 ? 'Бур работает, пусто' : 'Буру нужно топливо с НПЗ');
      return;
    }
    if (m.type === 'farm') {
      if (!m.seed) { Player.say('Посади семена (ПКМ семенами)'); return; }
      const def = ITEMS[m.seed];
      if (m.growth < def.grow) { Player.say('Ещё растёт: ' + Math.round(m.growth / def.grow * 100) + '%'); return; }
      const [id, n] = def.yield;
      const total = n + (Math.random() < 0.4 ? 1 : 0);
      Player.inv.add(id, total);
      Player.inv.add(m.seed, 1);
      Floaters.push((m.x + m.w / 2) * CELL, m.y * CELL - 14, '+' + total + ' ' + ITEMS[id].name, '#cfe0b0');
      m.seed = null; m.growth = 0;
      return;
    }
    if (m.type === 'furnace') {
      const coal = Player.inv.count('coal');
      if (coal > 0) {
        const n = Math.min(5, coal);
        Player.inv.remove('coal', n); m.fuel += n * 12;
        Player.say('Печь затоплена');
      } else Player.say('Нужен уголь');
      return;
    }
    if (m.type === 'bed') {
      // сон до утра: восстанавливает психику и немного здоровья
      Game.time = DAY_LEN * 0.3;
      Game.day++;
      Player.hp = clamp(Player.hp + 12, 0, 100);
      Player.food = clamp(Player.food - 40, 1, FOOD_MAX);
      Player.water = clamp(Player.water - 46, 1, WATER_MAX);
      Zombies.list.length = 0;
      Player.say('Утро. Ты спал в своей кровати');
      return;
    }
    if (m.type === 'workbench' || m.type === 'workbench2' || m.type === 'workbench3') { UI.screen = 'craft'; return; }
    if (m.type === 'campfire') { UI.screen = 'craft'; return; }
  },
  nearest(x, y, r) {
    let best = null, bd = r;
    for (const m of this.list) {
      const d = dist(x, y, (m.x + m.w / 2) * CELL, m.y * CELL - 6);
      if (d < bd) { bd = d; best = m; }
    }
    return best;
  },
  lights() {
    const out = [];
    for (const t of this.torches) out.push({ x: t.x, y: t.y, r: 130, i: 0.95 });
    for (const m of this.list) {
      if (m.type === 'campfire') out.push({ x: (m.x + m.w / 2) * CELL, y: m.y * CELL - 4, r: 170, i: 1 });
      if (m.type === 'furnace' && m.fuel > 0) out.push({ x: (m.x + m.w / 2) * CELL, y: m.y * CELL - 10, r: 140, i: 0.9 });
      if (m.type === 'drill' && m.fuel > 0) out.push({ x: (m.x + m.w / 2) * CELL, y: m.y * CELL - 20, r: 90, i: 0.6 });
    }
    return out;
  },
  draw(ctx) {
    for (const t of this.torches) {
      t.t += 0.1;
      ctx.strokeStyle = '#7b5c38'; ctx.lineWidth = 2.4; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(t.x, t.y + 5); ctx.lineTo(t.x, t.y - 3); ctx.stroke();
      const f = 1 + Math.sin(t.t * 3) * 0.14;
      const gr = ctx.createRadialGradient(t.x, t.y - 7, 0, t.x, t.y - 7, 9 * f);
      gr.addColorStop(0, '#fff6c8'); gr.addColorStop(0.4, '#f2a83c'); gr.addColorStop(1, 'rgba(230,110,30,0)');
      ctx.fillStyle = gr; ctx.beginPath(); ctx.ellipse(t.x, t.y - 7, 5 * f, 8 * f, 0, 0, 7); ctx.fill();
      if (Math.random() < 0.12) Particles.smoke(t.x, t.y - 10, 'rgba(120,110,100,0.25)');
    }
    for (const m of this.list) {
      const px = m.x * CELL, py = m.y * CELL, w = m.w * CELL, h = m.h * CELL;
      ctx.save();
      if (m.type === 'workbench') {
        ctx.fillStyle = '#6b4a26'; ctx.fillRect(px + 3, py - h + 8, 5, h - 8); ctx.fillRect(px + w - 8, py - h + 8, 5, h - 8);
        ctx.fillStyle = '#8a6134'; ctx.beginPath(); ctx.roundRect(px - 2, py - h, w + 4, 9, 2); ctx.fill();
        ctx.fillStyle = 'rgba(0,0,0,0.25)'; ctx.fillRect(px - 2, py - h + 7, w + 4, 2);
        ctx.fillStyle = '#9aa0a6'; ctx.fillRect(px + w * 0.5, py - h - 4, 10, 4);
        ctx.fillStyle = '#7a5c38'; ctx.fillRect(px + 4, py - h - 5, 7, 5);
      } else if (m.type === 'furnace') {
        const g2 = ctx.createLinearGradient(px, py - h, px, py);
        g2.addColorStop(0, '#8b8d90'); g2.addColorStop(1, '#5f6164');
        ctx.fillStyle = g2; ctx.beginPath(); ctx.roundRect(px, py - h, w, h, 3); ctx.fill();
        ctx.fillStyle = '#4a4c4f'; ctx.fillRect(px + 3, py - h - 5, 7, 6);
        ctx.fillStyle = m.fuel > 0 ? '#2a1c14' : '#22242a';
        ctx.beginPath(); ctx.roundRect(px + w * 0.25, py - h * 0.5, w * 0.5, h * 0.4, 2); ctx.fill();
        if (m.fuel > 0) {
          const fl = 1 + Math.sin(m.anim * 7) * 0.15;
          const gr = ctx.createRadialGradient(px + w / 2, py - h * 0.22, 0, px + w / 2, py - h * 0.22, w * 0.4 * fl);
          gr.addColorStop(0, '#fff0b8'); gr.addColorStop(0.5, '#e8721e'); gr.addColorStop(1, 'rgba(200,60,10,0)');
          ctx.fillStyle = gr; ctx.beginPath(); ctx.ellipse(px + w / 2, py - h * 0.24, w * 0.3 * fl, h * 0.2 * fl, 0, 0, 7); ctx.fill();
        }
      } else if (m.type === 'campfire') {
        ctx.strokeStyle = '#5e4326'; ctx.lineWidth = 3.4; ctx.lineCap = 'round';
        ctx.beginPath(); ctx.moveTo(px + 3, py - 2); ctx.lineTo(px + w - 3, py - 9);
        ctx.moveTo(px + w - 3, py - 2); ctx.lineTo(px + 3, py - 9); ctx.stroke();
        for (let i = 0; i < 5; i++) {
          ctx.fillStyle = '#6f7176';
          ctx.beginPath(); ctx.ellipse(px + 2 + i * (w - 4) / 4, py, 2.6, 2, 0, 0, 7); ctx.fill();
        }
        const fl = 1 + Math.sin(m.anim * 8) * 0.18;
        const gr = ctx.createRadialGradient(px + w / 2, py - 10, 0, px + w / 2, py - 10, 16 * fl);
        gr.addColorStop(0, '#fff6cc'); gr.addColorStop(0.35, '#f5a52e'); gr.addColorStop(1, 'rgba(220,90,20,0)');
        ctx.fillStyle = gr; ctx.beginPath(); ctx.ellipse(px + w / 2, py - 11, 9 * fl, 15 * fl, 0, 0, 7); ctx.fill();
      } else if (m.type === 'drill') {
        // опорная рама
        ctx.strokeStyle = '#4a3f36'; ctx.lineWidth = 2.6; ctx.lineCap = 'round';
        ctx.beginPath();
        ctx.moveTo(px + 2, py); ctx.lineTo(px + w * 0.3, py - h * 0.55);
        ctx.moveTo(px + w - 2, py); ctx.lineTo(px + w * 0.7, py - h * 0.55);
        ctx.stroke();
        // корпус
        const bg = ctx.createLinearGradient(px, py - h, px, py - h * 0.35);
        bg.addColorStop(0, '#6a7078'); bg.addColorStop(1, '#3c4146');
        ctx.fillStyle = bg; ctx.beginPath(); ctx.roundRect(px, py - h, w, h * 0.58, 3); ctx.fill();
        ctx.strokeStyle = '#2b2f33'; ctx.lineWidth = 1; ctx.stroke();
        // ржавчина и клёпки
        ctx.fillStyle = 'rgba(120,74,44,0.35)';
        ctx.fillRect(px + 2, py - h * 0.5, w - 4, 2);
        ctx.fillStyle = '#2b2f33';
        for (let i = 0; i < 4; i++) ctx.fillRect(px + 3 + i * (w - 8) / 3, py - h + 2.5, 1.6, 1.6);
        // труба и дым
        ctx.fillStyle = '#33383c'; ctx.fillRect(px + w - 9, py - h - 6, 5, 7);
        // лампа работы
        ctx.fillStyle = m.fuel > 0 ? '#e8c04a' : '#5a5040';
        ctx.beginPath(); ctx.arc(px + 5, py - h * 0.72, 2.2, 0, 7); ctx.fill();
        // индикатор угля
        ctx.fillStyle = '#1d2024'; ctx.beginPath(); ctx.roundRect(px + 9, py - h * 0.74, w - 16, 4.4, 2); ctx.fill();
        ctx.fillStyle = '#c0703c';
        ctx.beginPath(); ctx.roundRect(px + 9.5, py - h * 0.74 + 0.5, (w - 17) * clamp((m.buffer.coal || 0) / 10, 0, 1), 3.4, 1.7); ctx.fill();
        // бур
        const spin = m.fuel > 0 ? m.anim * 12 : 0;
        ctx.save();
        ctx.translate(px + w / 2, py - h * 0.3 + (m.depth * CELL));
        ctx.fillStyle = '#9aa0a6';
        ctx.beginPath(); ctx.moveTo(-5, 0); ctx.lineTo(5, 0); ctx.lineTo(0, 22 + Math.sin(spin) * 2); ctx.fill();
        ctx.strokeStyle = '#6d7378'; ctx.lineWidth = 1.4;
        for (let i = 0; i < 3; i++) {
          const yy = 4 + i * 6, ph = spin + i;
          ctx.beginPath(); ctx.moveTo(-4 + Math.sin(ph) * 2, yy); ctx.lineTo(4 + Math.sin(ph) * 2, yy + 2); ctx.stroke();
        }
        ctx.restore();
      } else if (m.type === 'bed') {
        // каркас, матрас, подушка, одеяло
        ctx.fillStyle = '#5a3f20';
        ctx.fillRect(px, py - 4, 4, 4); ctx.fillRect(px + w - 4, py - 4, 4, 4);
        ctx.fillStyle = '#6b4a26';
        ctx.beginPath(); ctx.roundRect(px, py - h + 2, w, 5, 1.5); ctx.fill();
        ctx.fillStyle = '#4a3418';
        ctx.beginPath(); ctx.roundRect(px - 1, py - h - 4, 4, 12, 1.5); ctx.fill();
        ctx.beginPath(); ctx.roundRect(px + w - 3, py - h - 1, 4, 9, 1.5); ctx.fill();
        const mg = ctx.createLinearGradient(px, py - h - 2, px, py - h + 3);
        mg.addColorStop(0, '#8a7060'); mg.addColorStop(1, '#6a5446');
        ctx.fillStyle = mg;
        ctx.beginPath(); ctx.roundRect(px + 2, py - h - 2, w - 4, 6, 2); ctx.fill();
        ctx.fillStyle = '#8a4a3c';
        ctx.beginPath(); ctx.roundRect(px + w * 0.35, py - h - 3, w * 0.6, 6, 2); ctx.fill();
        ctx.fillStyle = 'rgba(255,255,255,0.14)';
        ctx.fillRect(px + w * 0.35, py - h - 3, w * 0.6, 1.4);
        ctx.fillStyle = '#cfc8b4';
        ctx.beginPath(); ctx.roundRect(px + 3, py - h - 4, w * 0.24, 5, 2); ctx.fill();
      } else if (m.type === 'refinery') {
        // корпус, труба, бак, манометр
        ctx.fillStyle = '#4e5359';
        ctx.beginPath(); ctx.roundRect(px, py - h, w * 0.62, h, 3); ctx.fill();
        ctx.fillStyle = '#5c6167';
        ctx.beginPath(); ctx.roundRect(px + 2, py - h + 2, w * 0.62 - 4, h * 0.4, 2); ctx.fill();
        ctx.fillStyle = '#3c4147';
        ctx.beginPath(); ctx.roundRect(px + w * 0.66, py - h - 8, w * 0.3, h + 8, 3); ctx.fill();
        ctx.fillStyle = '#2f3338';
        ctx.beginPath(); ctx.roundRect(px + w * 0.7, py - h - 16, w * 0.2, 10, 2); ctx.fill();
        // бак
        ctx.fillStyle = m.out > 0 ? '#c24a2a' : '#7a4030';
        ctx.beginPath(); ctx.roundRect(px + 4, py - h * 0.5, w * 0.5, h * 0.42, 3); ctx.fill();
        ctx.fillStyle = 'rgba(255,255,255,0.14)';
        ctx.fillRect(px + 4, py - h * 0.5, w * 0.5, 1.6);
        // манометр мигает, когда работает
        const on = m.fuel > 0;
        ctx.fillStyle = on ? '#8ad06a' : '#5a5f55';
        ctx.beginPath(); ctx.arc(px + w * 0.5, py - h * 0.78, 3, 0, 7); ctx.fill();
        if (on) {
          ctx.strokeStyle = 'rgba(240,200,120,0.5)'; ctx.lineWidth = 1;
          ctx.beginPath(); ctx.arc(px + w * 0.5, py - h * 0.78, 5 + Math.sin(m.anim * 6) * 1.5, 0, 7); ctx.stroke();
        }
        if ((m.out || 0) > 0) {
          ctx.fillStyle = '#e8cf72'; ctx.font = '600 7px system-ui';
          ctx.fillText('топливо ' + m.out, px, py - h - 20);
        }
      } else if (m.type === 'farm') {
        ctx.fillStyle = '#3f2d1e'; ctx.fillRect(px - 1, py - 3, w + 2, 5);
        ctx.fillStyle = '#5a4229';
        for (let i = 0; i < m.w; i++) ctx.fillRect(px + i * CELL, py - 5, CELL - 1, 3);
        if (m.seed) {
          const def = ITEMS[m.seed];
          const g = clamp(m.growth / def.grow, 0, 1);
          for (let i = 0; i < 3; i++) {
            const sx = px + 5 + i * (w - 10) / 2;
            const hh = 3 + g * 16;
            ctx.strokeStyle = g < 1 ? '#6f9a4a' : '#8aa845'; ctx.lineWidth = 1.6; ctx.lineCap = 'round';
            ctx.beginPath(); ctx.moveTo(sx, py - 4); ctx.lineTo(sx + Math.sin(m.anim + i) * 1.5, py - 4 - hh); ctx.stroke();
            if (g > 0.35) {
              ctx.fillStyle = '#7fa050';
              ctx.beginPath(); ctx.ellipse(sx - 3, py - 4 - hh * 0.6, 3.5 * g, 1.8 * g, 0.4, 0, 7); ctx.fill();
              ctx.beginPath(); ctx.ellipse(sx + 3, py - 4 - hh * 0.8, 3.5 * g, 1.8 * g, -0.4, 0, 7); ctx.fill();
            }
            if (g >= 1) {
              ctx.fillStyle = '#c8a25c';
              ctx.beginPath(); ctx.ellipse(sx, py - 6, 2.6, 2, 0, 0, 7); ctx.fill();
            }
          }
        }
      }
      ctx.restore();
    }
  }
};
