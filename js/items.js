// items.js — предметы, иконки, инвентарь на 30 ячеек, рецепты
'use strict';

// иконки рисуются в квадрате size x size
const ICON = {
  lump(col, col2) {
    return (g, s) => {
      g.fillStyle = col;
      g.beginPath(); g.ellipse(s * 0.5, s * 0.56, s * 0.33, s * 0.27, 0.2, 0, 7); g.fill();
      g.fillStyle = col2;
      g.beginPath(); g.ellipse(s * 0.4, s * 0.42, s * 0.17, s * 0.13, -0.3, 0, 7); g.fill();
      g.beginPath(); g.ellipse(s * 0.64, s * 0.6, s * 0.1, s * 0.08, 0.4, 0, 7); g.fill();
    };
  },
  bar(col, col2) {
    return (g, s) => {
      g.fillStyle = col; g.beginPath();
      g.moveTo(s * 0.16, s * 0.66); g.lineTo(s * 0.28, s * 0.42); g.lineTo(s * 0.84, s * 0.42); g.lineTo(s * 0.72, s * 0.66); g.fill();
      g.fillStyle = col2; g.fillRect(s * 0.28, s * 0.36, s * 0.56, s * 0.07);
    };
  }
};

const ITEMS = {
  gasmask: {
    name: 'Противогаз ГП-1', max: 1, type: 'mask', desc: 'Ранг I. Дырявый, но живой. Без него на улице — смерть.',
    icon: (g, s) => {
      g.fillStyle = '#3c4038'; g.beginPath(); g.ellipse(s * 0.46, s * 0.42, s * 0.28, s * 0.31, 0, 0, 7); g.fill();
      g.fillStyle = '#7d9184'; g.beginPath(); g.ellipse(s * 0.52, s * 0.36, s * 0.15, s * 0.13, 0, 0, 7); g.fill();
      g.fillStyle = '#4a4f45'; g.beginPath(); g.roundRect(s * 0.42, s * 0.62, s * 0.26, s * 0.24, s * 0.06); g.fill();
      g.strokeStyle = '#33372f'; g.lineWidth = s * 0.06;
      g.beginPath(); g.moveTo(s * 0.2, s * 0.3); g.lineTo(s * 0.08, s * 0.24); g.stroke();
    }
  },
  filter: {
    name: 'Фильтр', max: 8, type: 'filter', desc: 'Сменный фильтр для противогаза.',
    icon: (g, s) => {
      g.fillStyle = '#4a4f45'; g.beginPath(); g.roundRect(s * 0.3, s * 0.24, s * 0.4, s * 0.52, s * 0.08); g.fill();
      g.fillStyle = '#31352e'; g.fillRect(s * 0.3, s * 0.42, s * 0.4, s * 0.08);
      g.fillStyle = '#8b8f80'; g.fillRect(s * 0.42, s * 0.16, s * 0.16, s * 0.1);
    }
  },
  pick: {
    name: 'Металлическая кирка', max: 1, type: 'tool', power: 1.0, dmg: 20, brush: 4, desc: 'Выгрызает 9×9 частиц за раз. Зомби в упор — тоже.',
    icon: (g, s) => { g.save(); g.translate(s * 0.5, s * 0.5); g.rotate(0.7); drawPickaxe(g, 0, s * 0.28, 0); g.restore(); }
  },
  axe: {
    name: 'Металлический топор', max: 1, type: 'tool', power: 1.0, wood: 3.4, dmg: 34, brush: 1, desc: 'По дереву — втрое быстрее кирки. И по зомби тоже.',
    icon: (g, s) => { g.save(); g.translate(s * 0.5, s * 0.5); g.rotate(0.7); drawAxe(g, 0, s * 0.28, 0); g.restore(); }
  },
  pick_wood: {
    name: 'Деревянное кайло', max: 1, type: 'tool', power: 0.45, dmg: 12, brush: 1, desc: 'Берёт 3×3 частицы. Землю грызёт, камень — еле-еле.',
    icon: (g, s) => {
      g.save(); g.translate(s * 0.5, s * 0.5); g.rotate(0.7);
      g.strokeStyle = '#7b5c38'; g.lineWidth = s * 0.1; g.lineCap = 'round';
      g.beginPath(); g.moveTo(0, s * 0.4); g.lineTo(0, -s * 0.3); g.stroke();
      g.strokeStyle = '#a07a44'; g.lineWidth = s * 0.11;
      g.beginPath(); g.moveTo(-s * 0.26, -s * 0.16); g.quadraticCurveTo(0, -s * 0.42, s * 0.26, -s * 0.16); g.stroke();
      g.restore();
    }
  },
  club: {
    name: 'Дубина', max: 1, type: 'melee', dmg: 30, rof: 0.55, desc: 'Тяжёлое бревно с гвоздями. ЛКМ — удар.',
    icon: (g, s) => {
      g.save(); g.translate(s * 0.5, s * 0.5); g.rotate(0.75);
      g.strokeStyle = '#6b4d30'; g.lineWidth = s * 0.11; g.lineCap = 'round';
      g.beginPath(); g.moveTo(0, s * 0.4); g.lineTo(0, s * 0.05); g.stroke();
      g.fillStyle = '#8a6640';
      g.beginPath(); g.roundRect(-s * 0.13, -s * 0.42, s * 0.26, s * 0.5, s * 0.1); g.fill();
      g.fillStyle = '#9aa0a6';
      g.fillRect(-s * 0.17, -s * 0.3, s * 0.07, s * 0.04);
      g.fillRect(s * 0.1, -s * 0.16, s * 0.07, s * 0.04);
      g.restore();
    }
  },
  grenade: {
    name: 'Граната Ф-1', max: 10, type: 'throw', fuse: 2.6, blastR: 95, blastDmg: 130, crater: 5,
    desc: 'ЛКМ или Q — бросок в сторону курсора. Оставляет небольшую воронку.',
    icon: (g, s) => {
      g.fillStyle = '#4a5240'; g.beginPath(); g.ellipse(s * 0.5, s * 0.56, s * 0.24, s * 0.3, 0, 0, 7); g.fill();
      g.strokeStyle = 'rgba(20,24,18,0.6)'; g.lineWidth = s * 0.04;
      for (let i = 0; i < 3; i++) { g.beginPath(); g.moveTo(s * 0.28, s * (0.42 + i * 0.14)); g.lineTo(s * 0.72, s * (0.42 + i * 0.14)); g.stroke(); }
      g.fillStyle = '#6d7364'; g.fillRect(s * 0.42, s * 0.16, s * 0.16, s * 0.12);
      g.strokeStyle = '#8b8f80'; g.lineWidth = s * 0.03;
      g.beginPath(); g.arc(s * 0.64, s * 0.2, s * 0.07, 0, 7); g.stroke();
    }
  },
  c4: {
    name: 'Заряд C4', max: 6, type: 'throw', fuse: 5, blastR: 190, blastDmg: 420, crater: 14, sticky: true,
    desc: 'Прилипает, где упал. Пять секунд — и большая воронка.',
    icon: (g, s) => {
      g.fillStyle = '#c9bfa2'; g.beginPath(); g.roundRect(s * 0.16, s * 0.36, s * 0.68, s * 0.34, s * 0.04); g.fill();
      g.fillStyle = '#8a7c5c'; g.fillRect(s * 0.16, s * 0.5, s * 0.68, s * 0.07);
      g.fillStyle = '#c04a3a'; g.beginPath(); g.roundRect(s * 0.56, s * 0.24, s * 0.16, s * 0.14, s * 0.03); g.fill();
      g.strokeStyle = '#3a3f45'; g.lineWidth = s * 0.035;
      g.beginPath(); g.moveTo(s * 0.64, s * 0.24); g.quadraticCurveTo(s * 0.8, s * 0.14, s * 0.86, s * 0.24); g.stroke();
    }
  },
  fuel: {
    name: 'Топливо', max: 60, type: 'res', desc: 'Переработано на НПЗ. Кормит бур и генератор убежища.',
    icon: (g, s) => {
      g.fillStyle = '#c24a2a'; g.beginPath(); g.roundRect(s * 0.26, s * 0.28, s * 0.46, s * 0.56, s * 0.06); g.fill();
      g.fillStyle = '#8f3520'; g.fillRect(s * 0.26, s * 0.46, s * 0.46, s * 0.06);
      g.fillStyle = '#e0e0d0'; g.fillRect(s * 0.34, s * 0.58, s * 0.3, s * 0.12);
      g.fillStyle = '#4a4d52'; g.fillRect(s * 0.42, s * 0.2, s * 0.14, s * 0.1);
      g.fillStyle = 'rgba(255,255,255,0.2)'; g.fillRect(s * 0.3, s * 0.3, s * 0.06, s * 0.5);
    }
  },
  plan: {
    name: 'Строительный план', max: 1, type: 'plan', desc: 'ПКМ или Q — поставить деталь. Колесо мыши — выбрать деталь.',
    icon: (g, s) => {
      g.fillStyle = '#d8d2c2'; g.beginPath(); g.roundRect(s * 0.14, s * 0.16, s * 0.72, s * 0.68, s * 0.04); g.fill();
      g.strokeStyle = '#3f6a8a'; g.lineWidth = s * 0.035;
      g.strokeRect(s * 0.26, s * 0.3, s * 0.48, s * 0.4);
      g.beginPath(); g.moveTo(s * 0.26, s * 0.5); g.lineTo(s * 0.74, s * 0.5); g.stroke();
      g.strokeStyle = 'rgba(60,90,120,0.5)'; g.lineWidth = s * 0.02;
      g.beginPath(); g.moveTo(s * 0.5, s * 0.3); g.lineTo(s * 0.5, s * 0.7); g.stroke();
      g.fillStyle = '#8a6238'; g.fillRect(s * 0.14, s * 0.16, s * 0.72, s * 0.06);
    }
  },
  hammer: {
    name: 'Молоток', max: 1, type: 'hammer', dmg: 14, desc: 'ЛКМ — починить деталь, ПКМ или Q — улучшить материал.',
    icon: (g, s) => {
      g.save(); g.translate(s * 0.5, s * 0.5); g.rotate(0.6);
      g.strokeStyle = '#7b5c38'; g.lineWidth = s * 0.1; g.lineCap = 'round';
      g.beginPath(); g.moveTo(0, s * 0.4); g.lineTo(0, -s * 0.16); g.stroke();
      g.fillStyle = '#5e6368';
      g.beginPath(); g.roundRect(-s * 0.22, -s * 0.38, s * 0.44, s * 0.2, s * 0.04); g.fill();
      g.fillStyle = '#8b9198';
      g.fillRect(-s * 0.22, -s * 0.38, s * 0.44, s * 0.06);
      g.restore();
    }
  },
  workbench2: {
    name: 'Верстак 2 уровня', max: 3, type: 'machine', machine: 'workbench2', w: 5, h: 3, desc: 'Открывает автоматы, дробовик и патроны посерьёзнее.',
    icon: (g, s) => {
      g.fillStyle = '#6b4a26'; g.fillRect(s * 0.1, s * 0.46, s * 0.8, s * 0.12);
      g.fillStyle = '#5a3f20'; g.fillRect(s * 0.14, s * 0.58, s * 0.1, s * 0.28); g.fillRect(s * 0.76, s * 0.58, s * 0.1, s * 0.28);
      g.fillStyle = '#7c8288'; g.fillRect(s * 0.2, s * 0.3, s * 0.3, s * 0.16);
      g.fillStyle = '#9aa0a6'; g.fillRect(s * 0.56, s * 0.24, s * 0.24, s * 0.22);
      g.fillStyle = '#c9a94a'; g.fillRect(s * 0.2, s * 0.24, s * 0.08, s * 0.06);
      g.fillStyle = '#e8dfc4'; g.font = '700 ' + (s * 0.22) + 'px system-ui'; g.fillText('2', s * 0.44, s * 0.86);
    }
  },
  workbench3: {
    name: 'Верстак 3 уровня', max: 3, type: 'machine', machine: 'workbench3', w: 6, h: 3, desc: 'Снайперка, пулемёт и всё лучшее. Нужен HQM.',
    icon: (g, s) => {
      g.fillStyle = '#5c6166'; g.fillRect(s * 0.08, s * 0.44, s * 0.84, s * 0.14);
      g.fillStyle = '#44484d'; g.fillRect(s * 0.12, s * 0.58, s * 0.1, s * 0.3); g.fillRect(s * 0.78, s * 0.58, s * 0.1, s * 0.3);
      g.fillStyle = '#8fa6bc'; g.fillRect(s * 0.18, s * 0.26, s * 0.28, s * 0.18);
      g.fillStyle = '#c2d6e8'; g.fillRect(s * 0.54, s * 0.2, s * 0.26, s * 0.24);
      g.fillStyle = '#7ad0a0'; g.beginPath(); g.arc(s * 0.3, s * 0.2, s * 0.04, 0, 7); g.fill();
      g.fillStyle = '#e8dfc4'; g.font = '700 ' + (s * 0.22) + 'px system-ui'; g.fillText('3', s * 0.44, s * 0.86);
    }
  },
  home_flag: {
    name: 'Флажок дома', max: 1, type: 'flag', desc: 'Ставится бесплатно. Внутри дома радиации нет. Дом может быть только один.',
    icon: (g, s) => {
      g.strokeStyle = '#8a7a5a'; g.lineWidth = s * 0.07; g.lineCap = 'round';
      g.beginPath(); g.moveTo(s * 0.34, s * 0.88); g.lineTo(s * 0.34, s * 0.16); g.stroke();
      g.fillStyle = '#b8452f';
      g.beginPath(); g.moveTo(s * 0.36, s * 0.18); g.lineTo(s * 0.82, s * 0.3); g.lineTo(s * 0.36, s * 0.46); g.fill();
      g.fillStyle = 'rgba(255,255,255,0.3)';
      g.beginPath(); g.moveTo(s * 0.36, s * 0.18); g.lineTo(s * 0.56, s * 0.24); g.lineTo(s * 0.36, s * 0.3); g.fill();
      g.fillStyle = '#5a4a30';
      g.beginPath(); g.ellipse(s * 0.34, s * 0.88, s * 0.12, s * 0.04, 0, 0, 7); g.fill();
    }
  },
  ladder: {
    name: 'Лестница', max: 100, type: 'place', mat: M.LADDER, desc: 'Ставь в шахте — по ней лазают W и S.',
    icon: (g, s) => {
      g.strokeStyle = '#7a5a34'; g.lineWidth = s * 0.08; g.lineCap = 'round';
      g.beginPath(); g.moveTo(s * 0.3, s * 0.16); g.lineTo(s * 0.3, s * 0.84);
      g.moveTo(s * 0.7, s * 0.16); g.lineTo(s * 0.7, s * 0.84); g.stroke();
      g.strokeStyle = '#a07a44'; g.lineWidth = s * 0.07;
      for (let i = 0; i < 3; i++) {
        const y = s * (0.3 + i * 0.2);
        g.beginPath(); g.moveTo(s * 0.26, y); g.lineTo(s * 0.74, y); g.stroke();
      }
    }
  },
  pistol: { name: 'Пистолет 9мм', max: 1, type: 'gun', kind: 'pistol', ammo: 'ammo9', mag: 12, rof: 0.24, dmg: 26, spread: 0.05, rec: 1, desc: 'ЛКМ — огонь, R — перезарядка.',
    icon: (g, s) => { g.save(); g.translate(s * 0.2, s * 0.55); g.scale(s / 26, s / 26); drawWeapon(g, 0, 0, 0, 'pistol', 0); g.restore(); } },
  revolver: { name: 'Револьвер .357', max: 1, type: 'gun', kind: 'revolver', ammo: 'ammo9', mag: 6, rof: 0.5, dmg: 46, spread: 0.04, rec: 1.5, desc: 'Бьёт больно, но шесть патронов и долгая перезарядка.',
    icon: (g, s) => { g.save(); g.translate(s * 0.18, s * 0.55); g.scale(s / 26, s / 26); drawWeapon(g, 0, 0, 0, 'revolver', 0); g.restore(); } },
  smg: { name: 'Пистолет-пулемёт', max: 1, type: 'gun', kind: 'smg', ammo: 'ammo9', mag: 32, rof: 0.075, dmg: 19, spread: 0.1, rec: 1.1, desc: 'Свинцовый душ в упор. Патроны кончаются мгновенно.',
    icon: (g, s) => { g.save(); g.translate(s * 0.14, s * 0.55); g.scale(s / 30, s / 30); drawWeapon(g, 0, 0, 0, 'smg', 0); g.restore(); } },
  shotgun: { name: 'Дробовик', max: 1, type: 'gun', kind: 'shotgun', ammo: 'buckshot', mag: 6, rof: 0.85, dmg: 17, pellets: 7, spread: 0.3, rec: 2.6, desc: 'Семь картечин за выстрел. В упор рвёт зомби пополам.',
    icon: (g, s) => { g.save(); g.translate(s * 0.12, s * 0.55); g.scale(s / 34, s / 34); drawWeapon(g, 0, 0, 0, 'shotgun', 0); g.restore(); } },
  sniper: { name: 'Снайперская винтовка', max: 1, type: 'gun', kind: 'sniper', ammo: 'ammo762', mag: 5, rof: 1.2, dmg: 95, spread: 0.012, rec: 3, desc: 'Один выстрел — один зомби. С оптикой.',
    icon: (g, s) => { g.save(); g.translate(s * 0.1, s * 0.6); g.scale(s / 38, s / 38); drawWeapon(g, 0, 0, 0, 'sniper', 0); g.restore(); } },
  rifle: { name: 'Автомат 5.45', max: 1, type: 'gun', kind: 'rifle', ammo: 'ammo545', mag: 30, rof: 0.1, dmg: 34, spread: 0.07, rec: 1.6, desc: 'Очередь. Держи ЛКМ.',
    icon: (g, s) => { g.save(); g.translate(s * 0.28, s * 0.5); g.scale(s / 46, s / 46); drawWeapon(g, 0, 0, 0, 'rifle', 0); g.restore(); } },
  mg: { name: 'Пулемёт 7.62', max: 1, type: 'gun', kind: 'mg', ammo: 'ammo762', mag: 100, rof: 0.075, dmg: 42, spread: 0.11, rec: 2.4, desc: 'Тяжёлый. Косит толпу.',
    icon: (g, s) => { g.save(); g.translate(s * 0.34, s * 0.5); g.scale(s / 58, s / 58); drawWeapon(g, 0, 0, 0, 'mg', 0); g.restore(); } },

  ammo9: { name: 'Патроны 9мм', max: 240, type: 'ammo', icon: ammoIcon('#b08a3c', 3) },
  sulfur_ore: { name: 'Серная руда', max: 500, type: 'res', desc: 'В печь — получится сера.', icon: ICON.lump('#8a7a34', '#c8b84a') },
  sulfur: { name: 'Сера', max: 500, type: 'res', desc: 'Половина пороха.', icon: ICON.lump('#c9b84c', '#e8dc82') },
  charcoal: { name: 'Древесный уголь', max: 1000, type: 'res', desc: 'Вторая половина пороха. Даёт печь из дерева.', icon: ICON.lump('#3a3a3e', '#5c5c62') },
  gunpowder: { name: 'Порох', max: 1000, type: 'res', desc: 'Из него делаются все патроны.', icon: ICON.lump('#4a4a52', '#6e6e78') },
  hqm_ore: { name: 'Руда HQM', max: 200, type: 'res', desc: 'Высококачественная руда. Редкая.', icon: ICON.lump('#5a6a7a', '#9ab0c4') },
  hqm: { name: 'Металл HQM', max: 200, type: 'res', desc: 'Лучший металл. Верстак 3 уровня и металлические постройки.', icon: ICON.bar('#8fa6bc', '#c2d6e8') },
  lowgrade: { name: 'Низкосортное топливо', max: 500, type: 'res', desc: 'Горючка для печей и лампы.', icon: ICON.lump('#8a6a2a', '#c8a44a') },
  buckshot: {
    name: 'Картечь 12к', max: 200, type: 'ammo', desc: 'Патрон для дробовика.',
    icon: (g, s) => {
      for (let i = 0; i < 3; i++) {
        const x = s * (0.22 + i * 0.22);
        g.fillStyle = '#a8352c'; g.beginPath(); g.roundRect(x, s * 0.34, s * 0.16, s * 0.34, s * 0.03); g.fill();
        g.fillStyle = '#b8a14a'; g.fillRect(x, s * 0.6, s * 0.16, s * 0.1);
      }
    }
  },
  ammo545: { name: 'Патроны 5.45', max: 300, type: 'ammo', icon: ammoIcon('#9a9a6a', 4) },
  ammo762: { name: 'Патроны 7.62', max: 400, type: 'ammo', icon: ammoIcon('#a8703c', 4) },
  zinc9: { name: 'Цинк 9мм (240)', max: 4, type: 'zinc', gives: ['ammo9', 240], icon: zincIcon('#6d6f57') },
  zinc545: { name: 'Цинк 5.45 (300)', max: 4, type: 'zinc', gives: ['ammo545', 300], icon: zincIcon('#5c6752') },
  zinc762: { name: 'Цинк 7.62 (400)', max: 4, type: 'zinc', gives: ['ammo762', 400], icon: zincIcon('#6b5a44') },

  dirt: { name: 'Земля', max: 200, type: 'place', mat: M.DIRT, icon: ICON.lump('#6f5238', '#8a6a48') },
  clay: { name: 'Глина', max: 200, type: 'place', mat: M.CLAY, icon: ICON.lump('#a86e4e', '#c08a68') },
  stone: { name: 'Камень', max: 200, type: 'place', mat: M.STONE, icon: ICON.lump('#7e8085', '#9a9ca1') },
  concrete: { name: 'Бетон', max: 200, type: 'place', mat: M.CONCRETE, icon: ICON.lump('#b0aea6', '#c8c6bd') },
  plank: { name: 'Доски', max: 200, type: 'place', mat: M.PLANK, icon: ICON.bar('#a87c4c', '#c49a66') },
  coal: { name: 'Уголь', max: 200, type: 'fuel', heat: 1, icon: ICON.lump('#2f2f33', '#494950') },
  iron_ore: { name: 'Железная руда', max: 200, type: 'mat', icon: ICON.lump('#8a7f7a', '#b4744a') },
  copper_ore: { name: 'Медная руда', max: 200, type: 'mat', icon: ICON.lump('#84867e', '#5f9c7c') },
  iron: { name: 'Железо', max: 200, type: 'mat', icon: ICON.bar('#8e9298', '#b6bac0') },
  copper: { name: 'Медь', max: 200, type: 'mat', icon: ICON.bar('#a4643c', '#c98a56') },
  scrap: { name: 'Металлолом', max: 200, type: 'mat', icon: ICON.lump('#75625a', '#9c8578') },
  wood: { name: 'Древесина', max: 200, type: 'mat', icon: (g, s) => {
    g.fillStyle = '#6b4d30'; g.beginPath(); g.roundRect(s * 0.22, s * 0.34, s * 0.56, s * 0.32, s * 0.1); g.fill();
    g.fillStyle = '#8a6640'; g.beginPath(); g.ellipse(s * 0.24, s * 0.5, s * 0.06, s * 0.15, 0, 0, 7); g.fill();
    g.strokeStyle = '#5a3f26'; g.lineWidth = s * 0.04; g.beginPath(); g.ellipse(s * 0.24, s * 0.5, s * 0.03, s * 0.08, 0, 0, 7); g.stroke(); } },
  stick: { name: 'Палка', max: 200, type: 'mat', icon: (g, s) => {
    g.strokeStyle = '#7b5c38'; g.lineWidth = s * 0.09; g.lineCap = 'round';
    g.beginPath(); g.moveTo(s * 0.22, s * 0.76); g.lineTo(s * 0.76, s * 0.24); g.stroke();
    g.beginPath(); g.moveTo(s * 0.5, s * 0.5); g.lineTo(s * 0.66, s * 0.56); g.stroke(); } },
  rag: { name: 'Тряпьё', max: 100, type: 'mat', icon: (g, s) => {
    g.fillStyle = '#8d8471'; g.beginPath(); g.moveTo(s * 0.2, s * 0.4); g.lineTo(s * 0.5, s * 0.26); g.lineTo(s * 0.8, s * 0.46);
    g.lineTo(s * 0.62, s * 0.74); g.lineTo(s * 0.3, s * 0.68); g.fill();
    g.fillStyle = '#6f6656'; g.fillRect(s * 0.36, s * 0.42, s * 0.3, s * 0.08); } },

  torch: { name: 'Факел', max: 30, type: 'light', icon: (g, s) => {
    g.strokeStyle = '#7b5c38'; g.lineWidth = s * 0.1; g.lineCap = 'round';
    g.beginPath(); g.moveTo(s * 0.42, s * 0.86); g.lineTo(s * 0.52, s * 0.44); g.stroke();
    const gr = g.createRadialGradient(s * 0.55, s * 0.32, 0, s * 0.55, s * 0.32, s * 0.24);
    gr.addColorStop(0, '#fff2b0'); gr.addColorStop(0.5, '#f0a03c'); gr.addColorStop(1, 'rgba(240,120,40,0)');
    g.fillStyle = gr; g.beginPath(); g.ellipse(s * 0.55, s * 0.3, s * 0.2, s * 0.26, 0, 0, 7); g.fill(); } },

  workbench: { name: 'Верстак', max: 10, type: 'machine', machine: 'workbench', w: 4, h: 3, desc: 'Крафт сложных вещей. Нужен рядом.' ,
    icon: (g, s) => { g.fillStyle = '#8a6134'; g.fillRect(s * 0.14, s * 0.36, s * 0.72, s * 0.12);
      g.fillStyle = '#6b4a26'; g.fillRect(s * 0.2, s * 0.48, s * 0.1, s * 0.34); g.fillRect(s * 0.7, s * 0.48, s * 0.1, s * 0.34);
      g.fillStyle = '#9aa0a6'; g.fillRect(s * 0.5, s * 0.26, s * 0.24, s * 0.08); } },
  furnace: { name: 'Печь', max: 10, type: 'machine', machine: 'furnace', w: 4, h: 4, desc: 'Плавит руду. Топится углём.',
    icon: (g, s) => { g.fillStyle = '#7b7d80'; g.beginPath(); g.roundRect(s * 0.18, s * 0.2, s * 0.64, s * 0.66, s * 0.08); g.fill();
      const gr = g.createRadialGradient(s * 0.5, s * 0.66, 0, s * 0.5, s * 0.66, s * 0.2);
      gr.addColorStop(0, '#ffd27a'); gr.addColorStop(1, '#d0521c');
      g.fillStyle = gr; g.beginPath(); g.roundRect(s * 0.34, s * 0.54, s * 0.32, s * 0.26, s * 0.05); g.fill(); } },
  campfire: { name: 'Костёр', max: 10, type: 'machine', machine: 'campfire', w: 4, h: 2, desc: 'Готовит еду, кипятит воду, греет психику.',
    icon: (g, s) => { g.strokeStyle = '#6b4a26'; g.lineWidth = s * 0.09;
      g.beginPath(); g.moveTo(s * 0.24, s * 0.8); g.lineTo(s * 0.76, s * 0.66); g.moveTo(s * 0.76, s * 0.8); g.lineTo(s * 0.24, s * 0.66); g.stroke();
      const gr = g.createRadialGradient(s * 0.5, s * 0.48, 0, s * 0.5, s * 0.48, s * 0.3);
      gr.addColorStop(0, '#fff3bb'); gr.addColorStop(0.45, '#f5a03c'); gr.addColorStop(1, 'rgba(240,110,30,0)');
      g.fillStyle = gr; g.beginPath(); g.ellipse(s * 0.5, s * 0.46, s * 0.24, s * 0.3, 0, 0, 7); g.fill(); } },
  drill: { name: 'Автобур', max: 10, type: 'machine', machine: 'drill', w: 4, h: 5, desc: 'Сам грызёт породу под собой. Работает на топливе с НПЗ.',
    icon: (g, s) => { g.fillStyle = '#5c6066'; g.beginPath(); g.roundRect(s * 0.24, s * 0.14, s * 0.52, s * 0.4, s * 0.06); g.fill();
      g.fillStyle = '#d0a13c'; g.fillRect(s * 0.3, s * 0.2, s * 0.4, s * 0.08);
      g.fillStyle = '#9aa0a6'; g.beginPath(); g.moveTo(s * 0.36, s * 0.54); g.lineTo(s * 0.64, s * 0.54); g.lineTo(s * 0.5, s * 0.92); g.fill(); } },
  refinery: { name: 'НПЗ', max: 5, type: 'machine', machine: 'refinery', w: 5, h: 4, desc: 'Гонит топливо из угля и дерева. Топливом кормится бур.',
    icon: (g, s) => {
      g.fillStyle = '#5c6167'; g.beginPath(); g.roundRect(s * 0.14, s * 0.4, s * 0.5, s * 0.46, s * 0.05); g.fill();
      g.fillStyle = '#43484e'; g.beginPath(); g.roundRect(s * 0.66, s * 0.2, s * 0.2, s * 0.66, s * 0.04); g.fill();
      g.fillStyle = '#8b9198'; g.fillRect(s * 0.18, s * 0.5, s * 0.42, s * 0.06);
      g.fillStyle = '#c24a2a'; g.beginPath(); g.arc(s * 0.34, s * 0.68, s * 0.08, 0, 7); g.fill();
      g.fillStyle = 'rgba(220,220,220,0.5)'; g.beginPath(); g.ellipse(s * 0.76, s * 0.14, s * 0.1, s * 0.06, 0, 0, 7); g.fill();
    }
  },
  farmplot: { name: 'Грядка', max: 20, type: 'machine', machine: 'farm', w: 3, h: 1, desc: 'Ставится на землю. Посади семена.',
    icon: (g, s) => { g.fillStyle = '#4a3423'; g.beginPath(); g.roundRect(s * 0.12, s * 0.56, s * 0.76, s * 0.28, s * 0.05); g.fill();
      g.strokeStyle = '#6f9a4a'; g.lineWidth = s * 0.07; g.lineCap = 'round';
      for (let i = 0; i < 3; i++) { const x = s * (0.3 + i * 0.2); g.beginPath(); g.moveTo(x, s * 0.56); g.lineTo(x + s * 0.04, s * 0.3); g.stroke(); } } },

  seeds: { name: 'Семена картофеля', max: 60, type: 'seed', grow: 55, yield: ['potato', 3], desc: 'Сажать в грядку.',
    icon: (g, s) => { g.fillStyle = '#8d7b4a'; for (let i = 0; i < 5; i++) { const a = i * 1.3;
      g.beginPath(); g.ellipse(s * (0.5 + Math.cos(a) * 0.18), s * (0.54 + Math.sin(a) * 0.16), s * 0.07, s * 0.05, a, 0, 7); g.fill(); } } },
  potato: { name: 'Картофель', max: 60, type: 'food', food: 12, water: 2, psy: -2, raw: true, desc: 'Сырой. Лучше запечь.',
    icon: (g, s) => { g.fillStyle = '#b8935c'; g.beginPath(); g.ellipse(s * 0.5, s * 0.54, s * 0.3, s * 0.24, 0.3, 0, 7); g.fill();
      g.fillStyle = '#8f6f42'; g.beginPath(); g.ellipse(s * 0.42, s * 0.48, s * 0.05, s * 0.04, 0, 0, 7); g.fill();
      g.beginPath(); g.ellipse(s * 0.6, s * 0.6, s * 0.04, s * 0.03, 0, 0, 7); g.fill(); } },
  potato_baked: { name: 'Печёный картофель', max: 60, type: 'food', food: 26, psy: 4, desc: 'Горячий. Даже вкусно.',
    icon: (g, s) => { g.fillStyle = '#8a6236'; g.beginPath(); g.ellipse(s * 0.5, s * 0.54, s * 0.3, s * 0.24, 0.3, 0, 7); g.fill();
      g.fillStyle = '#f2d79a'; g.beginPath(); g.ellipse(s * 0.5, s * 0.5, s * 0.16, s * 0.1, 0.3, 0, 7); g.fill(); } },
  can: { name: 'Тушёнка', max: 20, type: 'food', food: 34, psy: 6, desc: 'Срок годности вышел в прошлой эпохе.',
    icon: (g, s) => { g.fillStyle = '#9aa0a6'; g.beginPath(); g.roundRect(s * 0.28, s * 0.3, s * 0.44, s * 0.46, s * 0.05); g.fill();
      g.fillStyle = '#a8452f'; g.fillRect(s * 0.28, s * 0.44, s * 0.44, s * 0.18);
      g.fillStyle = '#c9ced3'; g.fillRect(s * 0.28, s * 0.3, s * 0.44, s * 0.06); } },
  meat_rot: { name: 'Гнилая плоть', max: 40, type: 'food', food: 8, psy: -14, hp: -6, desc: 'Ешь только от отчаяния.',
    icon: (g, s) => { g.fillStyle = '#7c4a4a'; g.beginPath(); g.ellipse(s * 0.5, s * 0.56, s * 0.28, s * 0.2, 0.2, 0, 7); g.fill();
      g.fillStyle = '#5c6b4a'; g.beginPath(); g.ellipse(s * 0.58, s * 0.5, s * 0.08, s * 0.06, 0, 0, 7); g.fill(); } },
  canteen: { name: 'Фляга (пусто)', max: 4, type: 'canteen', icon: canteenIcon('rgba(0,0,0,0)') },
  canteen_dirty: { name: 'Фляга (мутная вода)', max: 4, type: 'drink', water: 22, hp: -8, psy: -4, desc: 'Радиоактивная жижа. Лучше вскипятить.', icon: canteenIcon('#5c7a52') },
  canteen_clean: { name: 'Фляга (чистая вода)', max: 4, type: 'drink', water: 40, psy: 2, desc: 'Кипячёная. Безопасно.', icon: canteenIcon('#5f9ec4') },
  bandage: { name: 'Бинт', max: 20, type: 'med', heals: 2, hp: 8, desc: 'Лечит раны C1–C2, останавливает кровь.',
    icon: (g, s) => { g.fillStyle = '#e2ddcd'; g.beginPath(); g.roundRect(s * 0.22, s * 0.36, s * 0.56, s * 0.3, s * 0.06); g.fill();
      g.fillStyle = '#c9c2ac'; g.fillRect(s * 0.22, s * 0.46, s * 0.56, s * 0.06);
      g.strokeStyle = '#b9b09a'; g.lineWidth = s * 0.04; g.beginPath(); g.moveTo(s * 0.4, s * 0.36); g.lineTo(s * 0.4, s * 0.66); g.stroke(); } },
  splint: { name: 'Шина', max: 10, type: 'med', heals: 3, hp: 14, desc: 'Лечит раны до C3.',
    icon: (g, s) => { g.strokeStyle = '#8a6134'; g.lineWidth = s * 0.08;
      g.beginPath(); g.moveTo(s * 0.34, s * 0.2); g.lineTo(s * 0.34, s * 0.8); g.moveTo(s * 0.62, s * 0.2); g.lineTo(s * 0.62, s * 0.8); g.stroke();
      g.strokeStyle = '#e2ddcd'; g.lineWidth = s * 0.07;
      g.beginPath(); g.moveTo(s * 0.26, s * 0.4); g.lineTo(s * 0.7, s * 0.4); g.moveTo(s * 0.26, s * 0.62); g.lineTo(s * 0.7, s * 0.62); g.stroke(); } },
  medkit: { name: 'Аптечка', max: 6, type: 'med', heals: 4, hp: 40, psy: 6, desc: 'Вытаскивает даже из C4.',
    icon: (g, s) => { g.fillStyle = '#d8d2c2'; g.beginPath(); g.roundRect(s * 0.18, s * 0.28, s * 0.64, s * 0.5, s * 0.08); g.fill();
      g.fillStyle = '#b8392f'; g.fillRect(s * 0.44, s * 0.36, s * 0.12, s * 0.34); g.fillRect(s * 0.28, s * 0.47, s * 0.44, s * 0.12); } },
  antirad: { name: 'Антирад', max: 20, type: 'med', rad: 60, psy: -2, hp: -4, desc: 'Сбивает накопленную радиацию.',
    icon: (g, s) => { g.fillStyle = '#4a7a52'; g.beginPath(); g.roundRect(s * 0.3, s * 0.26, s * 0.4, s * 0.5, s * 0.14); g.fill();
      g.fillStyle = '#d8e0cc'; g.beginPath(); g.roundRect(s * 0.3, s * 0.26, s * 0.4, s * 0.24, s * 0.14); g.fill();
      g.fillStyle = '#2f4a34'; g.fillRect(s * 0.36, s * 0.55, s * 0.28, s * 0.06); } },
  map_caves: { name: 'Карта пещер', max: 1, type: 'quest', desc: 'Отмечены входы в подземные комплексы. Пока не читается.',
    icon: (g, s) => { g.fillStyle = '#cfc3a0'; g.beginPath(); g.moveTo(s * 0.16, s * 0.3); g.lineTo(s * 0.5, s * 0.24);
      g.lineTo(s * 0.84, s * 0.34); g.lineTo(s * 0.82, s * 0.76); g.lineTo(s * 0.48, s * 0.82); g.lineTo(s * 0.18, s * 0.72); g.fill();
      g.strokeStyle = '#8a7a52'; g.lineWidth = s * 0.04; g.beginPath(); g.moveTo(s * 0.5, s * 0.24); g.lineTo(s * 0.48, s * 0.82); g.stroke();
      g.fillStyle = '#a8392f'; g.beginPath(); g.arc(s * 0.66, s * 0.56, s * 0.05, 0, 7); g.fill(); } }
};

function ammoIcon(col, n) {
  return (g, s) => {
    for (let i = 0; i < n; i++) {
      const x = s * (0.22 + i * (0.56 / n));
      g.fillStyle = col; g.beginPath(); g.roundRect(x, s * 0.34, s * 0.1, s * 0.36, s * 0.04); g.fill();
      g.fillStyle = '#c9a95c'; g.beginPath(); g.moveTo(x, s * 0.34); g.lineTo(x + s * 0.05, s * 0.24); g.lineTo(x + s * 0.1, s * 0.34); g.fill();
    }
  };
}
function zincIcon(col) {
  return (g, s) => {
    g.fillStyle = col; g.beginPath(); g.roundRect(s * 0.12, s * 0.3, s * 0.76, s * 0.44, s * 0.05); g.fill();
    g.fillStyle = 'rgba(255,255,255,0.14)'; g.fillRect(s * 0.12, s * 0.34, s * 0.76, s * 0.06);
    g.fillStyle = '#2f2f2f'; g.fillRect(s * 0.26, s * 0.48, s * 0.48, s * 0.08);
    g.fillStyle = '#8a8a70'; g.fillRect(s * 0.4, s * 0.24, s * 0.2, s * 0.07);
  };
}
function canteenIcon(water) {
  return (g, s) => {
    g.fillStyle = '#5b5f4e'; g.beginPath(); g.roundRect(s * 0.28, s * 0.28, s * 0.44, s * 0.52, s * 0.1); g.fill();
    if (water !== 'rgba(0,0,0,0)') { g.fillStyle = water; g.beginPath(); g.roundRect(s * 0.32, s * 0.46, s * 0.36, s * 0.3, s * 0.06); g.fill(); }
    g.fillStyle = '#3d4034'; g.fillRect(s * 0.42, s * 0.2, s * 0.16, s * 0.1);
    g.fillStyle = '#7a7f66'; g.fillRect(s * 0.3, s * 0.36, s * 0.4, s * 0.04);
  };
}

// ---- рецепты ----
// station: null — руками, иначе имя машины рядом
const RECIPES = [
  { out: ['plank', 2], in: { wood: 1 }, station: null },
  { out: ['stick', 2], in: { wood: 1 }, station: null },
  { out: ['torch', 3], in: { stick: 1, coal: 1 }, station: null },
  { out: ['workbench', 1], in: { plank: 8 }, station: null },
  { out: ['pick_wood', 1], in: { stick: 3, plank: 2 }, station: null },
  { out: ['club', 1], in: { wood: 2, stick: 2 }, station: null },
  { out: ['ladder', 4], in: { plank: 2, stick: 2 }, station: null },
  { out: ['home_flag', 1], in: {}, station: null },
  { out: ['plan', 1], in: {}, station: null },
  { out: ['grenade', 2], in: { scrap: 4, iron: 3, coal: 6 }, station: 'workbench' },
  { out: ['c4', 1], in: { scrap: 14, iron: 10, coal: 16 }, station: 'workbench' },
  { out: ['grenade', 1], in: { iron: 3, scrap: 4, coal: 5 }, station: 'workbench' },
  { out: ['c4', 1], in: { iron: 10, scrap: 16, coal: 18, rag: 2 }, station: 'workbench' },
  { out: ['refinery', 1], in: { iron: 18, stone: 24, scrap: 10 }, station: 'workbench' },
  { out: ['hammer', 1], in: { wood: 10, stone: 4 }, station: null },
  { out: ['campfire', 1], in: { stick: 4, stone: 4 }, station: null },
  { out: ['canteen', 1], in: { scrap: 2 }, station: null },

  { out: ['furnace', 1], in: { stone: 20, clay: 8 }, station: 'workbench' },
  { out: ['pick', 1], in: { stick: 2, iron: 3 }, station: 'workbench' },
  { out: ['axe', 1], in: { stick: 2, iron: 3 }, station: 'workbench' },
  { out: ['farmplot', 1], in: { plank: 4, dirt: 6 }, station: 'workbench' },
  { out: ['drill', 1], in: { iron: 12, plank: 6, scrap: 4, copper: 4 }, station: 'workbench' },
  { out: ['filter', 1], in: { scrap: 2, clay: 2, coal: 1 }, station: 'workbench' },
  { out: ['bandage', 2], in: { rag: 3 }, station: 'workbench' },
  { out: ['splint', 1], in: { rag: 4, stick: 2 }, station: 'workbench' },
  { out: ['medkit', 1], in: { rag: 6, bandage: 2, copper: 2 }, station: 'workbench' },
  { out: ['antirad', 2], in: { clay: 4, copper: 1, coal: 2 }, station: 'workbench' },
  { out: ['pistol', 1], in: { iron: 8, scrap: 4, plank: 2 }, station: 'workbench' },

  { out: ['workbench2', 1], in: { scrap: 40, iron: 20, plank: 10 }, station: 'workbench' },
  { out: ['workbench3', 1], in: { scrap: 80, iron: 40, hqm: 10 }, station: 'workbench2' },

  { out: ['gunpowder', 10], in: { sulfur: 6, charcoal: 9 }, station: 'workbench' },
  { out: ['ammo9', 12], in: { gunpowder: 6, iron: 2 }, station: 'workbench' },
  { out: ['buckshot', 8], in: { gunpowder: 8, iron: 3 }, station: 'workbench' },
  { out: ['revolver', 1], in: { iron: 12, scrap: 8, plank: 2 }, station: 'workbench' },
  { out: ['shotgun', 1], in: { iron: 16, scrap: 12, plank: 6 }, station: 'workbench' },

  { out: ['ammo545', 12], in: { gunpowder: 8, iron: 3 }, station: 'workbench2' },
  { out: ['smg', 1], in: { iron: 24, scrap: 20, plank: 4 }, station: 'workbench2' },
  { out: ['rifle', 1], in: { iron: 30, scrap: 26, hqm: 2, plank: 4 }, station: 'workbench2' },

  { out: ['ammo762', 12], in: { gunpowder: 10, iron: 4 }, station: 'workbench3' },
  { out: ['sniper', 1], in: { iron: 40, scrap: 40, hqm: 8, plank: 6 }, station: 'workbench3' },
  { out: ['mg', 1], in: { iron: 60, scrap: 50, hqm: 14 }, station: 'workbench3' },

  { out: ['charcoal', 3], in: { wood: 2 }, station: 'furnace', fuel: 1 },
  { out: ['sulfur', 1], in: { sulfur_ore: 2 }, station: 'furnace', fuel: 1 },
  { out: ['hqm', 1], in: { hqm_ore: 4 }, station: 'furnace', fuel: 2 },
  { out: ['lowgrade', 4], in: { charcoal: 3, clay: 1 }, station: 'furnace', fuel: 1 },
  { out: ['iron', 1], in: { iron_ore: 2 }, station: 'furnace', fuel: 1 },
  { out: ['copper', 1], in: { copper_ore: 2 }, station: 'furnace', fuel: 1 },
  { out: ['concrete', 4], in: { stone: 4, clay: 2 }, station: 'furnace', fuel: 1 },

  { out: ['potato_baked', 1], in: { potato: 1 }, station: 'campfire' },
  { out: ['canteen_clean', 1], in: { canteen_dirty: 1 }, station: 'campfire' },
  { out: ['seeds', 2], in: { potato: 1 }, station: 'campfire' }
];

// ---- инвентарь ----
class Inventory {
  constructor(size) { this.size = size; this.slots = new Array(size).fill(null); }
  add(id, n) {
    const max = ITEMS[id].max;
    for (let i = 0; i < this.size && n > 0; i++) {
      const s = this.slots[i];
      if (s && s.id === id && s.n < max) { const c = Math.min(max - s.n, n); s.n += c; n -= c; }
    }
    for (let i = 0; i < this.size && n > 0; i++) {
      if (!this.slots[i]) { const c = Math.min(max, n); this.slots[i] = { id, n: c }; n -= c; }
    }
    return n; // не влезло
  }
  count(id) { let c = 0; for (const s of this.slots) if (s && s.id === id) c += s.n; return c; }
  remove(id, n) {
    for (let i = this.size - 1; i >= 0 && n > 0; i--) {
      const s = this.slots[i];
      if (s && s.id === id) { const c = Math.min(s.n, n); s.n -= c; n -= c; if (s.n <= 0) this.slots[i] = null; }
    }
    return n === 0;
  }
  has(map) { for (const k in map) if (this.count(k) < map[k]) return false; return true; }
  takeFrom(i, n) {
    const s = this.slots[i]; if (!s) return null;
    const c = Math.min(s.n, n); s.n -= c; const out = { id: s.id, n: c };
    if (s.n <= 0) this.slots[i] = null;
    return out;
  }
  isFull() { return this.slots.every(s => s !== null); }
}
