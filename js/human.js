// human.js — процедурная отрисовка человека: белая майка, тёмные штаны, армейские ботинки
'use strict';

const SKINS = ['#e0b48c', '#c99873', '#a97a54', '#7d5638', '#5a3d28'];
const HAIRS = ['#2b2320', '#4a3526', '#7a6242', '#c9b183', '#8e8e8e'];
const HAIRSTYLES = ['Короткая', 'Ёжик', 'Зачёс', 'Лысина', 'Лохматая'];

function shade(hex, f) {
  const n = parseInt(hex.slice(1), 16);
  const r = clamp(((n >> 16) & 255) * f, 0, 255), g = clamp(((n >> 8) & 255) * f, 0, 255), b = clamp((n & 255) * f, 0, 255);
  return rgb(r, g, b);
}

function limb(ctx, x, y, len, ang, w, col) {
  const ex = x + Math.sin(ang) * len, ey = y + Math.cos(ang) * len;
  ctx.strokeStyle = col; ctx.lineWidth = w; ctx.lineCap = 'round';
  ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(ex, ey); ctx.stroke();
  return [ex, ey];
}

// a — облик: {skin, hair, hairStyle, beard}
// s — состояние: {face:1|-1, phase, moving, air, dig, aim, mask, item, hurtLeg}
function drawHuman(ctx, px, py, a, s) {
  const face = s.face || 1;
  const t = s.phase || 0;
  const walk = s.moving ? 1 : 0;
  const skin = SKINS[a.skin % SKINS.length];
  const hair = HAIRS[a.hair % HAIRS.length];
  const shirt = '#d9d5c4', shirtDark = '#b3ae9b';
  const pants = '#2f313a', pantsDark = '#22242b';
  const boot = '#4e3f30', bootDark = '#3a2f24';

  ctx.save();
  ctx.translate(px, py);
  ctx.scale(face, 1);

  const bob = s.air ? 0.6 : -Math.abs(Math.sin(t)) * 1.3 * walk;
  const lean = s.air ? 0.12 : walk * 0.1;
  ctx.translate(0, bob);

  const hipY = -25, shoulderY = -43, headY = -50;

  // ---- ноги ----
  const thighL = 13, shinL = 12;
  function leg(phaseOff, back) {
    const th = walk ? Math.sin(t + phaseOff) * 0.52 : (back ? -0.07 : 0.07);
    const kn = walk ? th - Math.max(0, Math.sin(t + phaseOff + 1.1)) * 0.85 : th - 0.05;
    const f = back ? 0.72 : 1;
    const [kx, ky] = limb(ctx, 0, hipY, thighL, th + lean, 8.5, back ? shade(pants, 0.72) : pants);
    const [fx, fy] = limb(ctx, kx, ky, shinL, kn + lean, 7, back ? shade(pants, 0.7) : pantsDark);
    // ботинок
    ctx.fillStyle = back ? shade(boot, 0.75) : boot;
    ctx.save(); ctx.translate(fx, fy); ctx.rotate(-(kn + lean) * 0.4);
    ctx.beginPath(); ctx.roundRect(-3.4, -2.5, 9.5, 6.2, 2); ctx.fill();
    ctx.fillStyle = back ? shade(bootDark, 0.8) : bootDark;
    ctx.beginPath(); ctx.roundRect(-3.6, 1.6, 10, 2.6, 1.2); ctx.fill();
    // шнуровка
    ctx.strokeStyle = 'rgba(20,16,12,0.55)'; ctx.lineWidth = 0.8;
    ctx.beginPath(); ctx.moveTo(0.5, -2); ctx.lineTo(3.5, 0.6); ctx.moveTo(3.2, -2); ctx.lineTo(0.8, 0.6); ctx.stroke();
    ctx.restore();
    return f;
  }
  leg(Math.PI, true);

  // ---- дальняя рука ----
  const armL = 10, foreL = 10;
  const hasGun = !!s.aim;
  if (!hasGun) {
    const ah = walk ? -Math.sin(t) * 0.5 : -0.12;
    const [ex, ey] = limb(ctx, -1, shoulderY + 2, armL, ah, 6.4, shade(skin, 0.7));
    limb(ctx, ex, ey, foreL, ah - 0.2, 5.6, shade(skin, 0.66));
  }

  // ---- торс ----
  ctx.save();
  ctx.rotate(lean * 0.5);
  const grd = ctx.createLinearGradient(-6, shoulderY, 7, hipY);
  grd.addColorStop(0, shirt); grd.addColorStop(1, shirtDark);
  ctx.fillStyle = grd;
  ctx.beginPath();
  ctx.moveTo(-6.5, shoulderY + 1);
  ctx.quadraticCurveTo(-7.5, hipY - 8, -5.2, hipY + 1);
  ctx.lineTo(5.4, hipY + 1);
  ctx.quadraticCurveTo(7.6, hipY - 9, 6.6, shoulderY + 1);
  ctx.quadraticCurveTo(0, shoulderY - 2.4, -6.5, shoulderY + 1);
  ctx.fill();
  // бретельки майки и грязь
  ctx.fillStyle = 'rgba(120,112,92,0.35)';
  ctx.fillRect(-5.6, hipY - 5, 11.4, 2.2);
  ctx.fillStyle = 'rgba(90,80,62,0.22)';
  ctx.fillRect(-4.2, hipY - 11, 4, 4);
  ctx.fillStyle = 'rgba(255,255,255,0.25)';
  ctx.fillRect(-2.4, shoulderY + 2, 4.6, 6);
  // ремень
  ctx.fillStyle = '#31261d';
  ctx.fillRect(-6, hipY - 1.5, 12, 3.4);
  ctx.fillStyle = '#8b7a52';
  ctx.fillRect(0.4, hipY - 1, 2.4, 2.6);
  // шея
  ctx.fillStyle = shade(skin, 0.85);
  ctx.fillRect(-2.2, shoulderY - 4, 4.6, 6);
  ctx.restore();

  // ---- голова ----
  ctx.save();
  ctx.translate(0, headY);
  ctx.rotate(lean * 0.3);
  if (s.mask) {
    // противогаз: резина, стекло, фильтр
    ctx.fillStyle = shade(skin, 0.9);
    ctx.beginPath(); ctx.ellipse(0, 0, 5.6, 6.4, 0, 0, 7); ctx.fill();
    ctx.fillStyle = '#3c4038';
    ctx.beginPath(); ctx.ellipse(0.4, 0.2, 6.2, 6.8, 0, 0, 7); ctx.fill();
    ctx.fillStyle = '#2b2f2a';
    ctx.beginPath(); ctx.ellipse(1.2, 2.4, 5.4, 4.4, 0, 0, 7); ctx.fill();
    // стекло
    const gg = ctx.createLinearGradient(-2, -3, 5, 3);
    gg.addColorStop(0, '#9fb6a6'); gg.addColorStop(0.5, '#5f7466'); gg.addColorStop(1, '#33413a');
    ctx.fillStyle = gg;
    ctx.beginPath(); ctx.ellipse(2.2, -1.4, 3.5, 2.9, -0.15, 0, 7); ctx.fill();
    ctx.strokeStyle = '#20241f'; ctx.lineWidth = 0.9;
    ctx.beginPath(); ctx.ellipse(2.2, -1.4, 3.5, 2.9, -0.15, 0, 7); ctx.stroke();
    ctx.fillStyle = 'rgba(255,255,255,0.35)';
    ctx.beginPath(); ctx.ellipse(1.2, -2.4, 1.3, 0.8, -0.4, 0, 7); ctx.fill();
    // фильтр
    ctx.fillStyle = '#4a4f45';
    ctx.beginPath(); ctx.roundRect(3.4, 3.2, 5.4, 4.6, 1.4); ctx.fill();
    ctx.fillStyle = '#31352e';
    ctx.beginPath(); ctx.roundRect(3.4, 4.6, 5.4, 1.2, 0.6); ctx.fill();
    // ремни
    ctx.strokeStyle = '#33372f'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.moveTo(-4.6, -3.4); ctx.lineTo(-7, -2.2); ctx.moveTo(-4.6, 2.4); ctx.lineTo(-7, 2); ctx.stroke();
  } else {
    ctx.fillStyle = skin;
    ctx.beginPath(); ctx.ellipse(0, 0, 5.4, 6.2, 0, 0, 7); ctx.fill();
    // нос, глаз
    ctx.fillStyle = shade(skin, 0.86);
    ctx.beginPath(); ctx.moveTo(4.6, -0.6); ctx.lineTo(6.4, 0.8); ctx.lineTo(4.4, 1.2); ctx.fill();
    ctx.fillStyle = '#1d1a18';
    ctx.fillRect(2.4, -1.8, 1.5, 1.5);
    // волосы
    ctx.fillStyle = hair;
    const st = a.hairStyle % HAIRSTYLES.length;
    if (st === 0) { ctx.beginPath(); ctx.ellipse(-0.4, -3.2, 5.4, 3.4, 0, Math.PI, 0); ctx.fill(); ctx.fillRect(-5.6, -3.6, 3, 4); }
    else if (st === 1) { ctx.beginPath(); ctx.ellipse(-0.3, -4.4, 5, 2.4, 0, Math.PI, 0); ctx.fill(); }
    else if (st === 2) { ctx.beginPath(); ctx.moveTo(-5.6, -3.2); ctx.quadraticCurveTo(0, -9, 5.4, -3.6); ctx.quadraticCurveTo(1, -5.4, -5.6, -3.2); ctx.fill(); }
    else if (st === 3) { ctx.beginPath(); ctx.ellipse(-2.8, -3.4, 3, 2.4, 0, Math.PI, 0); ctx.fill(); }
    else { for (let i = 0; i < 9; i++) { const an = Math.PI + i * 0.4; ctx.beginPath(); ctx.ellipse(Math.cos(an) * 4.4, -3 + Math.sin(an) * 3.4, 2.2, 2, 0, 0, 7); ctx.fill(); } }
    if (a.beard) {
      ctx.fillStyle = shade(hair, 0.85);
      ctx.beginPath(); ctx.ellipse(1.4, 3.2, 4, 3, 0, 0, Math.PI); ctx.fill();
    }
  }
  ctx.restore();

  // ---- ближняя нога ----
  leg(0, false);

  // ---- ближняя рука и предмет ----
  const sx = 1.5, sy = shoulderY + 2;
  if (hasGun) {
    // Внутри scale(-1,1) мировой угол θ превращается в π−θ, а не в −θ.
    // Из-за этой ошибки оружие при взгляде влево смотрело не туда
    const ang = face === 1 ? s.aimAng : Math.PI - s.aimAng;
    const hx = sx + Math.cos(ang) * 15, hy = sy + Math.sin(ang) * 15;
    // дальняя рука поддерживает
    limb(ctx, -1, sy, 9, Math.PI / 2 - ang - 0.5, 6, shade(skin, 0.7));
    drawWeapon(ctx, sx + Math.cos(ang) * 6, sy + Math.sin(ang) * 6, ang, s.aim, s.recoil || 0);
    ctx.strokeStyle = skin; ctx.lineWidth = 6.4; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(sx, sy); ctx.lineTo(hx, hy); ctx.stroke();
  } else {
    let ah = walk ? Math.sin(t) * 0.5 : 0.12;
    if (s.dig !== undefined) ah = -1.5 + Math.sin(s.dig * Math.PI) * 2.6;
    const [ex, ey] = limb(ctx, sx, sy, armL, ah, 6.6, skin);
    const [hx, hy] = limb(ctx, ex, ey, foreL, ah + 0.25, 5.8, skin);
    if (s.item === 'pick') drawPickaxe(ctx, hx, hy, ah + 1.1);
    else if (s.item === 'axe') drawAxe(ctx, hx, hy, ah + 1.1);
    else if (s.item === 'club') drawClub(ctx, hx, hy, ah + 1.1);
  }

  ctx.restore();
}

function drawPickaxe(ctx, x, y, ang) {
  ctx.save(); ctx.translate(x, y); ctx.rotate(ang);
  ctx.strokeStyle = '#7b5c38'; ctx.lineWidth = 2.6; ctx.lineCap = 'round';
  ctx.beginPath(); ctx.moveTo(0, 6); ctx.lineTo(0, -14); ctx.stroke();
  ctx.strokeStyle = '#9aa0a6'; ctx.lineWidth = 3;
  ctx.beginPath(); ctx.moveTo(-8, -10); ctx.quadraticCurveTo(0, -17, 8, -10); ctx.stroke();
  ctx.strokeStyle = '#6d7378'; ctx.lineWidth = 1.2;
  ctx.beginPath(); ctx.moveTo(-8, -10); ctx.quadraticCurveTo(0, -15.5, 8, -10); ctx.stroke();
  ctx.restore();
}

function drawAxe(ctx, x, y, ang) {
  ctx.save(); ctx.translate(x, y); ctx.rotate(ang);
  ctx.strokeStyle = '#7b5c38'; ctx.lineWidth = 2.6; ctx.lineCap = 'round';
  ctx.beginPath(); ctx.moveTo(0, 6); ctx.lineTo(0, -13); ctx.stroke();
  ctx.fillStyle = '#9aa0a6';
  ctx.beginPath(); ctx.moveTo(0, -14); ctx.lineTo(7, -11); ctx.lineTo(7, -5); ctx.lineTo(0, -7); ctx.fill();
  ctx.restore();
}

function drawClub(ctx, x, y, ang) {
  ctx.save(); ctx.translate(x, y); ctx.rotate(ang);
  ctx.strokeStyle = '#6b4d30'; ctx.lineWidth = 2.8; ctx.lineCap = 'round';
  ctx.beginPath(); ctx.moveTo(0, 5); ctx.lineTo(0, -6); ctx.stroke();
  ctx.fillStyle = '#8a6640';
  ctx.beginPath(); ctx.roundRect(-3.4, -18, 6.8, 13, 2.6); ctx.fill();
  ctx.fillStyle = '#5f452c';
  ctx.fillRect(-3.4, -14, 6.8, 1.2);
  ctx.fillStyle = '#9aa0a6';
  ctx.fillRect(-5, -16, 2, 1.4); ctx.fillRect(3, -11, 2, 1.4);
  ctx.restore();
}

// Оружие рисуется в профиль, деталями: рама, ствол, магазин, приклад,
// прицельные, дерево накладок. Ноль внешних картинок — всё векторное
function drawWeapon(ctx, x, y, ang, kind, recoil) {
  ctx.save();
  ctx.translate(x - Math.cos(ang) * recoil * 3, y - Math.sin(ang) * recoil * 3);
  ctx.rotate(ang);

  const steel = (x0, y0, w, h, r) => {
    const g = ctx.createLinearGradient(0, y0, 0, y0 + h);
    g.addColorStop(0, '#6f757c'); g.addColorStop(0.45, '#4a4f55'); g.addColorStop(1, '#2e3237');
    ctx.fillStyle = g;
    ctx.beginPath(); ctx.roundRect(x0, y0, w, h, r || 1); ctx.fill();
  };
  const dark = (x0, y0, w, h, r) => {
    ctx.fillStyle = '#2a2d31';
    ctx.beginPath(); ctx.roundRect(x0, y0, w, h, r || 1); ctx.fill();
  };
  const wood = (x0, y0, w, h, r) => {
    const g = ctx.createLinearGradient(0, y0, 0, y0 + h);
    g.addColorStop(0, '#7b5730'); g.addColorStop(0.5, '#5d411f'); g.addColorStop(1, '#3f2c15');
    ctx.fillStyle = g;
    ctx.beginPath(); ctx.roundRect(x0, y0, w, h, r || 1.5); ctx.fill();
    ctx.fillStyle = 'rgba(255,230,190,0.10)'; ctx.fillRect(x0, y0, w, 0.7);
  };
  const gloss = (x0, y0, w) => { ctx.fillStyle = 'rgba(255,255,255,0.14)'; ctx.fillRect(x0, y0, w, 0.7); };
  const sight = (x0, h) => { dark(x0, -3.2 - h, 1.4, h + 0.6, 0.4); };

  if (kind === 'pistol') {
    steel(0, -3.4, 16, 4.6, 1);                 // затвор
    gloss(1, -3.2, 13);
    dark(1.5, 1, 5.6, 8, 1.6);                  // рукоять
    ctx.fillStyle = '#3a3e43'; ctx.fillRect(7, 1.2, 3.4, 4.6);   // спусковая скоба
    dark(2.5, 1.2, 3.2, 6.4, 0.8);              // магазин
    steel(15.5, -2.4, 2.6, 2.4, 0.6);           // дуло
    sight(13.5, 1.4); sight(2, 1.2);
  } else if (kind === 'revolver') {
    steel(0, -3, 13, 4, 1);
    ctx.fillStyle = '#55595f';
    ctx.beginPath(); ctx.arc(3.6, -0.4, 3.4, 0, 7); ctx.fill();   // барабан
    ctx.fillStyle = '#33373c';
    for (let i = 0; i < 6; i++) {
      const a = i * Math.PI / 3;
      ctx.beginPath(); ctx.arc(3.6 + Math.cos(a) * 2, -0.4 + Math.sin(a) * 2, 0.7, 0, 7); ctx.fill();
    }
    wood(0.5, 1, 5, 8, 2);                      // деревянная рукоять
    steel(12.5, -2.2, 6, 2.2, 0.6);             // ствол
    ctx.fillStyle = '#3a3e43'; ctx.fillRect(6.5, 1.2, 3.2, 4.2);
    sight(17, 1.2); sight(1, 1.4);
  } else if (kind === 'smg') {
    steel(0, -3, 22, 4.4, 1);
    gloss(1, -2.8, 18);
    dark(3, 1, 4.6, 10, 1.2);                   // длинный магазин
    dark(11, 1, 4, 5, 1);                       // рукоять удержания
    wood(-8, -2.4, 8, 4.4, 1.5);                // приклад-дерево
    steel(21, -2.2, 4, 2.2, 0.6);
    ctx.fillStyle = '#3a3e43'; ctx.fillRect(8, 1.2, 3, 4);
    sight(19, 1.6); sight(2, 1.4);
  } else if (kind === 'shotgun') {
    steel(0, -3, 26, 4.6, 1);
    wood(-11, -2.6, 11, 5, 2);                  // приклад
    wood(9, 1, 10, 3.4, 1.5);                   // цевьё-помпа
    dark(19.5, 1.2, 3, 2.6, 0.8);
    steel(25, -2.4, 6, 2.6, 0.6);               // длинный ствол
    ctx.fillStyle = '#3a3e43'; ctx.fillRect(5, 1.2, 3.2, 4.2);
    gloss(1, -2.8, 22);
    sight(29, 1.2);
  } else if (kind === 'rifle') {
    steel(0, -3, 27, 4.4, 1);
    gloss(1, -2.8, 22);
    dark(4, 1, 5, 10, 1.4);                     // изогнутый магазин
    ctx.fillStyle = '#2a2d31';
    ctx.beginPath(); ctx.moveTo(4, 8); ctx.quadraticCurveTo(6, 12, 9.5, 11.5); ctx.lineTo(9, 8); ctx.fill();
    wood(-10, -2.4, 10, 4.6, 1.5);              // приклад
    wood(12, 0.8, 8, 3.2, 1.2);                 // накладка
    steel(26.5, -2.2, 5, 2.2, 0.6);
    dark(30.5, -2.6, 2.4, 3, 0.6);              // дульный тормоз
    ctx.fillStyle = '#3a3e43'; ctx.fillRect(9.5, 1.2, 3, 4.2);
    sight(24, 2.2); sight(3, 2);
  } else if (kind === 'sniper') {
    steel(0, -2.6, 30, 3.8, 1);
    wood(-12, -2.6, 12, 5, 2);
    wood(10, 0.6, 10, 3, 1.2);
    steel(29, -2, 8, 2, 0.5);                   // длинный ствол
    // оптика
    dark(6, -7.4, 14, 3.6, 1.8);
    ctx.fillStyle = '#8fb0c0';
    ctx.beginPath(); ctx.ellipse(19.6, -5.6, 1, 1.5, 0, 0, 7); ctx.fill();
    dark(9, -4, 1.6, 1.6, 0.4); dark(16, -4, 1.6, 1.6, 0.4);
    ctx.fillStyle = '#4a4f55'; ctx.fillRect(3.5, -3.4, 4, 1.6);   // рукоять затвора
    ctx.beginPath(); ctx.arc(7.5, -2.6, 1.1, 0, 7); ctx.fill();
    ctx.fillStyle = '#3a3e43'; ctx.fillRect(7, 1.2, 3, 4.2);
  } else {
    // пулемёт: короб, лента, сошки
    steel(-4, -3.6, 36, 5.6, 1.4);
    gloss(-2, -3.4, 30);
    ctx.fillStyle = '#3f4348';
    ctx.beginPath(); ctx.roundRect(2, 2, 13, 7.6, 1.6); ctx.fill();  // патронный короб
    ctx.fillStyle = '#a58b4a';
    for (let i = 0; i < 5; i++) ctx.fillRect(14 + i * 2.2, 3.4 + i * 0.5, 1.8, 2.2);  // лента
    dark(-12, -3.2, 9, 6.4, 1.8);               // приклад
    steel(31, -2.6, 7, 2.6, 0.6);
    dark(37, -3, 2.6, 3.4, 0.6);
    ctx.strokeStyle = '#33373c'; ctx.lineWidth = 1.6; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(24, 3); ctx.lineTo(28, 9); ctx.moveTo(32, 3); ctx.lineTo(28, 9); ctx.stroke();
    ctx.fillStyle = '#3a3e43'; ctx.fillRect(0, 1.4, 3.2, 4.4);
    sight(28, 2.4); sight(4, 2.6);
  }
  ctx.restore();
}

// зомби: тот же каркас, но перекошенный и гнилой
function drawZombie(ctx, px, py, z) {
  const face = z.face;
  const t = z.phase;
  ctx.save();
  ctx.translate(px, py); ctx.scale(face, 1);
  const skin = z.pale ? '#8f9e86' : '#79906f', skinD = shade(skin, 0.72);
  const rags = '#4e4b3f';
  const hipY = -23, shoulderY = -40;
  ctx.translate(0, -Math.abs(Math.sin(t)) * 1.4);
  // ноги
  for (const [off, back] of [[Math.PI, true], [0, false]]) {
    const th = Math.sin(t + off) * 0.6, kn = th - Math.max(0, Math.sin(t + off + 1)) * 0.7;
    const [kx, ky] = limb(ctx, 0, hipY, 12, th + 0.14, 7.5, back ? shade(rags, 0.72) : rags);
    limb(ctx, kx, ky, 11, kn + 0.14, 6.4, back ? shade(skin, 0.6) : skinD);
  }
  // руки вытянуты вперёд
  for (const [off, back] of [[0.5, true], [0, false]]) {
    const ah = 1.15 + Math.sin(t * 0.8 + off) * 0.18;
    const [ex, ey] = limb(ctx, 0, shoulderY + 3, 10, ah, 6, back ? shade(skin, 0.68) : skin);
    limb(ctx, ex, ey, 10, ah + 0.35, 5.2, back ? shade(skin, 0.62) : skinD);
    if (!back) { ctx.fillStyle = skinD; ctx.beginPath(); ctx.ellipse(ex + Math.sin(ah + 0.35) * 10, ey + Math.cos(ah + 0.35) * 10, 2.4, 2, 0, 0, 7); ctx.fill(); }
  }
  // торс в лохмотьях
  ctx.save(); ctx.rotate(0.16);
  ctx.fillStyle = rags;
  ctx.beginPath();
  ctx.moveTo(-6, shoulderY + 1); ctx.quadraticCurveTo(-7, hipY - 8, -5, hipY + 1);
  ctx.lineTo(5, hipY + 1); ctx.quadraticCurveTo(7, hipY - 9, 6, shoulderY + 1);
  ctx.quadraticCurveTo(0, shoulderY - 2, -6, shoulderY + 1); ctx.fill();
  ctx.fillStyle = skinD; ctx.fillRect(-3, hipY - 12, 5, 7);
  ctx.fillStyle = '#6b3b34'; ctx.fillRect(1, hipY - 9, 3.5, 5);
  ctx.fillStyle = shade(skin, 0.9); ctx.fillRect(-2, shoulderY - 4, 4.4, 6);
  ctx.restore();
  // голова
  ctx.save(); ctx.translate(1.5, shoulderY - 7); ctx.rotate(0.2);
  ctx.fillStyle = skin; ctx.beginPath(); ctx.ellipse(0, 0, 5.2, 6, 0, 0, 7); ctx.fill();
  ctx.fillStyle = '#2a1f1c'; ctx.beginPath(); ctx.ellipse(2.6, -1.4, 1.5, 1.8, 0, 0, 7); ctx.fill();
  ctx.fillStyle = '#d8d2c0'; ctx.fillRect(1.5, 2.6, 3.4, 1.4);
  ctx.strokeStyle = '#3d2b26'; ctx.lineWidth = 0.9;
  ctx.beginPath(); ctx.moveTo(-3, -3); ctx.lineTo(1, -4.6); ctx.stroke();
  ctx.fillStyle = shade(skin, 0.7); ctx.beginPath(); ctx.ellipse(-1, -4.6, 3.6, 2.2, 0, Math.PI, 0); ctx.fill();
  ctx.restore();
  ctx.restore();
}
