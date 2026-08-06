// boom.js — взрывчатка: гранаты и C4. Летят по дуге, взрываются по таймеру,
// выжигают кратер в породе, рвут зомби и постройки. Всё крафтится, не премиум.
'use strict';

const Explosions = {
  list: [],

  // Кратер: круг с рваным краем, чтобы не выглядел циркулем.
  // Город и локации не трогаем — там порода защищена
  carve(cx, cy, radius) {
    const drops = {};
    const r2 = radius * radius;
    for (let dy = -radius - 2; dy <= radius + 2; dy++) {
      for (let dx = -radius - 2; dx <= radius + 2; dx++) {
        const x = cx + dx, y = cy + dy;
        if (!World.inside(x, y) || World.protectedAt(x)) continue;
        // рваная кромка: радиус гуляет по углу
        const wob = 1 + (hash2(x * 3, y * 5) - 0.5) * 0.5;
        if (dx * dx + dy * dy > r2 * wob) continue;
        const m = World.get(x, y);
        if (m === M.AIR) continue;
        const mi = MATS[m];
        if (mi.struct !== undefined || mi.door) continue;      // постройки ломаются отдельно
        if (mi.drop && Math.random() < 0.15) drops[mi.drop] = (drops[mi.drop] || 0) + 1;
        World.set(x, y, M.AIR);
      }
    }
    // обугленная кромка кратера
    for (let dy = -radius - 3; dy <= radius + 3; dy++) {
      for (let dx = -radius - 3; dx <= radius + 3; dx++) {
        const x = cx + dx, y = cy + dy;
        const d = Math.hypot(dx, dy);
        if (d < radius || d > radius + 2.2) continue;
        if (!World.inside(x, y) || World.protectedAt(x)) continue;
        const m = World.get(x, y);
        if (m !== M.AIR && MATS[m].solid && MATS[m].struct === undefined && Math.random() < 0.5) World.set(x, y, M.ASH);
      }
    }
    return drops;
  },

  // Один взрыв: кратер, урон всему вокруг, вспышка и звуковая волна из частиц
  blast(x, y, opt) {
    const radiusCells = opt.crater || 0;
    const dmgR = opt.r || 90;
    const dmg = opt.dmg || 120;

    if (radiusCells > 0) {
      const drops = this.carve(Math.floor(x / CELL), Math.floor(y / CELL), radiusCells);
      for (const id in drops) Drops.add(x + rnd(-20, 20), y - 10, id, Math.max(1, Math.round(drops[id] * 0.4)));
    }

    // постройки
    for (const s of Structures.list.slice()) {
      const d = dist(x, y, (s.gx + s.w / 2) * CELL, (s.gy + s.h / 2) * CELL);
      if (d < dmgR * 1.2) Structures.damage(s, dmg * (1 - d / (dmgR * 1.2)) * 1.6);
    }
    // зомби
    for (const z of Zombies.list) {
      if (z.hp <= 0) continue;
      const d = dist(x, y, z.x, z.y - 22);
      if (d < dmgR) {
        z.hp -= dmg * (1 - d / dmgR);
        z.vx += Math.sign(z.x - x) * 4;
        z.vy = -3;
        for (let i = 0; i < 8; i++) Particles.blood(z.x, z.y - 20);
      }
    }
    // игрок — своя же взрывчатка бьёт больно
    const dp = dist(x, y, Player.x, Player.y - 26);
    if (dp < dmgR && !Player.dead) {
      const k = 1 - dp / dmgR;
      Player.hp -= dmg * k * 0.55;
      Player.vy = -4 * k;
      Player.vx += Math.sign(Player.x - x) * 5 * k;
      if (k > 0.4) Player.wound(pick(['legL', 'legR', 'armL', 'armR', 'torso']), k > 0.75 ? 3 : 2);
      Player.say('Тебя задело взрывом');
    }

    // картинка взрыва
    this.list.push({ x, y, t: 0, life: 0.75, r: dmgR });
    for (let i = 0; i < 46; i++) {
      const a = Math.random() * Math.PI * 2, sp = rnd(1.5, 7);
      Particles.list.push({
        x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 1.2, g: 0.12,
        life: rnd(0.3, 0.9), t: 0, s: rnd(2, 6),
        col: i < 16 ? '#fff0b0' : i < 30 ? '#f09040' : '#6a6a6a', glow: i < 30
      });
    }
    for (let i = 0; i < 16; i++) Particles.smoke(x + rnd(-24, 24), y + rnd(-16, 8), 'rgba(70,66,62,0.5)');
    Game.shake = Math.min(16, 6 + dmgR / 14);
  },

  update(dt) {
    for (let i = this.list.length - 1; i >= 0; i--) {
      const e = this.list[i];
      e.t += dt;
      if (e.t > e.life) this.list.splice(i, 1);
    }
  },

  draw(ctx) {
    for (const e of this.list) {
      const k = e.t / e.life;
      const r = e.r * (0.3 + k * 0.9);
      ctx.save();
      ctx.globalCompositeOperation = 'lighter';
      ctx.globalAlpha = (1 - k) * 0.9;
      const g = ctx.createRadialGradient(e.x, e.y, 0, e.x, e.y, r);
      g.addColorStop(0, 'rgba(255,248,210,0.95)');
      g.addColorStop(0.35, 'rgba(250,170,70,0.7)');
      g.addColorStop(1, 'rgba(120,40,20,0)');
      ctx.fillStyle = g;
      ctx.beginPath(); ctx.arc(e.x, e.y, r, 0, 7); ctx.fill();
      ctx.restore();
      // ударная волна
      ctx.strokeStyle = 'rgba(255,230,190,' + (1 - k) * 0.35 + ')';
      ctx.lineWidth = 2 - k * 1.6;
      ctx.beginPath(); ctx.arc(e.x, e.y, r * 1.15, 0, 7); ctx.stroke();
    }
  },

  // свет от вспышки, чтобы ночью взрыв освещал округу
  lights() {
    return this.list.map(e => ({ x: e.x, y: e.y, r: e.r * 2.2 * (1 - e.t / e.life), i: 1 }));
  }
};

// ---- брошенная взрывчатка ----
const Throwables = {
  list: [],

  throwIt(kind, fromX, fromY, angle, power) {
    const def = ITEMS[kind];
    this.list.push({
      kind, x: fromX, y: fromY,
      vx: Math.cos(angle) * power, vy: Math.sin(angle) * power,
      fuse: def.fuse, t: 0, spin: 0, stuck: false
    });
  },

  update(dt) {
    for (let i = this.list.length - 1; i >= 0; i--) {
      const b = this.list[i];
      b.t += dt;
      b.spin += (Math.abs(b.vx) + Math.abs(b.vy)) * dt * 0.6;

      if (!b.stuck) {
        b.vy += GRAV * 0.85;
        const nx = b.x + b.vx, ny = b.y + b.vy;
        const solidX = World.solid(Math.floor(nx / CELL), Math.floor(b.y / CELL));
        const solidY = World.solid(Math.floor(b.x / CELL), Math.floor(ny / CELL));
        const def = ITEMS[b.kind];
        if (solidY) {
          if (def.sticky) { b.stuck = true; b.vx = 0; b.vy = 0; }     // C4 прилипает
          else { b.vy *= -0.32; b.vx *= 0.6; if (Math.abs(b.vy) < 0.6) b.vy = 0; }
        } else b.y = ny;
        if (solidX) { if (def.sticky) { b.stuck = true; b.vx = 0; } else b.vx *= -0.4; }
        else b.x = nx;
      }

      if (b.t >= b.fuse) {
        const def = ITEMS[b.kind];
        Explosions.blast(b.x, b.y, { r: def.blastR, dmg: def.blastDmg, crater: def.crater });
        this.list.splice(i, 1);
      }
    }
  },

  draw(ctx) {
    for (const b of this.list) {
      const def = ITEMS[b.kind];
      const left = b.fuse - b.t;
      ctx.save();
      ctx.translate(b.x, b.y);
      ctx.rotate(b.spin);
      if (b.kind === 'c4') {
        ctx.fillStyle = '#c9bfa2';
        ctx.beginPath(); ctx.roundRect(-6, -4, 12, 8, 1.5); ctx.fill();
        ctx.fillStyle = '#8a7c5c'; ctx.fillRect(-6, -1, 12, 2);
        ctx.fillStyle = '#c04a3a'; ctx.fillRect(2, -6.5, 3, 3);
        ctx.strokeStyle = '#3a3f45'; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(3.5, -6.5); ctx.lineTo(6, -9); ctx.stroke();
      } else {
        ctx.fillStyle = '#4a5240';
        ctx.beginPath(); ctx.ellipse(0, 0, 4.4, 5.4, 0, 0, 7); ctx.fill();
        ctx.strokeStyle = 'rgba(20,24,18,0.6)'; ctx.lineWidth = 0.8;
        for (let i = -1; i <= 1; i++) { ctx.beginPath(); ctx.moveTo(-4, i * 2.4); ctx.lineTo(4, i * 2.4); ctx.stroke(); }
        ctx.fillStyle = '#6d7364'; ctx.fillRect(-1.6, -7, 3.2, 2.4);
      }
      ctx.restore();
      // мигающий огонёк запала — чем ближе, тем чаще
      const blink = Math.sin(b.t * (8 + (1 / Math.max(0.2, left)) * 6)) > 0;
      if (blink) {
        ctx.fillStyle = '#ff6a3a';
        ctx.beginPath(); ctx.arc(b.x + 3, b.y - 6, 1.8, 0, 7); ctx.fill();
      }
      Particles.smoke(b.x, b.y - 6, 'rgba(200,200,200,0.25)');
    }
  },

  lights() {
    return this.list.map(b => ({ x: b.x, y: b.y - 6, r: 70, i: 0.5 }));
  }
};
