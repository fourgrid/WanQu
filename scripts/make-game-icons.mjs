// make-game-icons.mjs — 玩趣：程序化绘制 8 个游戏专属图标（统一设计语言）
// 设计：圆角方形渐变底(签名色) + 白色游戏核心元素微缩 + 柔和投影
// 用法: node make-game-icons.mjs <outdir>
import zlib from 'node:zlib';
import fs from 'node:fs';
import path from 'node:path';

// ---------- PNG 编码 ----------
function crc32(buf) {
  let c, table = crc32.table;
  if (!table) {
    table = crc32.table = [];
    for (let n = 0; n < 256; n++) {
      c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
      table[n] = c >>> 0;
    }
  }
  c = 0xFFFFFFFF;
  for (let i = 0; i < buf.length; i++) c = table[(c ^ buf[i]) & 0xFF] ^ (c >>> 8);
  return (c ^ 0xFFFFFFFF) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function png(w, h, rgba) {
  const sig = Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 6;
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  }
  return Buffer.concat([sig, chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}

// ---------- 绘图基元（S=尺寸, 画布 [0,1] 归一化坐标） ----------
const clamp01 = v => Math.max(0, Math.min(1, v));
function mix(a, b, t) {
  return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
}
function rrAA(px, py, x, y, w, h, r) { // 归一化坐标圆角矩形覆盖度
  const cx = clamp01(Math.min(Math.max(px, x + r), x + w - r));
  const cy = Math.min(Math.max(py, y + r), y + h - r);
  const dx = px - cx, dy = py - cy;
  const d2 = dx * dx + dy * dy;
  const e = 0.004;
  if (d2 <= (r - e) * (r - e)) return 1;
  if (d2 >= (r + e) * (r + e)) {
    if (px >= x && px <= x + w && py >= y && py <= y + h) {
      const near = Math.min(px - x, x + w - px, py - y, y + h - py);
      if (near > e) return 1;
    }
    return 0;
  }
  const d = Math.sqrt(d2);
  return clamp01((r + e - d) / (2 * e));
}
function circleAA(px, py, cx, cy, r) {
  const dx = px - cx, dy = py - cy;
  const d2 = dx * dx + dy * dy;
  const e = 0.004;
  if (d2 <= (r - e) * (r - e)) return 1;
  if (d2 >= (r + e) * (r + e)) return 0;
  const d = Math.sqrt(d2);
  return clamp01((r + e - d) / (2 * e));
}
function segAA(px, py, x1, y1, x2, y2, thick) { // 线段(粗细=半径)
  const vx = x2 - x1, vy = y2 - y1;
  const len2 = vx * vx + vy * vy;
  let t = len2 > 0 ? ((px - x1) * vx + (py - y1) * vy) / len2 : 0;
  t = clamp01(t);
  const qx = x1 + t * vx, qy = y1 + t * vy;
  const d = Math.sqrt((px - qx) ** 2 + (py - qy) ** 2);
  const e = 0.004;
  if (d <= thick - e) return 1;
  if (d >= thick + e) return 0;
  return clamp01((thick + e - d) / (2 * e));
}

// ---------- 图标画布 ----------
const S = 256;
const WHITE = [255, 255, 255];

function canvas(topColor, botColor) {
  const px = new Float32Array(S * S * 3);
  for (let y = 0; y < S; y++) {
    for (let x = 0; x < S; x++) {
      const ny = y / S;
      const nx = x / S;
      let c = mix(topColor, botColor, ny * 0.9 + nx * 0.1);
      // 顶部高光弧
      c = mix(c, WHITE, Math.max(0, 0.22 - ny) * 1.1);
      const i = (y * S + x) * 3;
      px[i] = c[0]; px[i + 1] = c[1]; px[i + 2] = c[2];
    }
  }
  return px;
}
function over(px, x, y, cov, color, alpha = 1) {
  if (cov <= 0) return;
  const i = (Math.floor(y) * S + Math.floor(x)) * 3;
  if (i < 0 || i >= px.length - 2) return;
  const t = cov * alpha;
  px[i] = px[i] + (color[0] - px[i]) * t;
  px[i + 1] = px[i + 1] + (color[1] - px[i + 1]) * t;
  px[i + 2] = px[i + 2] + (color[2] - px[i + 2]) * t;
}
function render(px, out) {
  const buf = Buffer.alloc(S * S * 4);
  for (let y = 0; y < S; y++) {
    for (let x = 0; x < S; x++) {
      const i = (y * S + x) * 3;
      const o = (y * S + x) * 4;
      buf[o] = Math.round(px[i]); buf[o + 1] = Math.round(px[i + 1]); buf[o + 2] = Math.round(px[i + 2]);
      buf[o + 3] = 255;
    }
  }
  fs.writeFileSync(out, png(S, S, buf));
  console.log('✔', path.basename(out));
}

const shadow = (px, pxn, pyn, w, h, r = 0.04) => { // 底部柔影
  for (let y = 0; y < S; y++) {
    for (let x = 0; x < S; x++) {
      const cov = rrAA(x / S, y / S, pxn, pyn + 0.012, w, h, r);
      if (cov > 0) over(px, x, y, cov * 0.25, [20, 20, 30]);
    }
  }
};

// ---------- 8 个游戏图标 ----------
function iconScrew() {
  const px = canvas([66, 133, 244], [26, 71, 148]); // 蓝
  shadow(px, 0.16, 0.30, 0.68, 0.40, 0.05);
  // 板件
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    const cov = rrAA(x / S, y / S, 0.16, 0.30, 0.68, 0.40, 0.05);
    over(px, x, y, cov, [214, 219, 228]);
  }
  // 螺丝 ×4（错落色）
  const screws = [[0.30, 0.42, [192, 57, 43]], [0.50, 0.42, [39, 174, 96]], [0.70, 0.42, [241, 196, 15]], [0.42, 0.60, [142, 68, 173]]];
  for (const sc of screws) {
    for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
      let cov = circleAA(x / S, y / S, sc[0], sc[1], 0.055);
      over(px, x, y, cov, sc[2]);
      // 十字槽
      cov = Math.max(segAA(x / S, y / S, sc[0] - 0.035, sc[1], sc[0] + 0.035, sc[1], 0.009),
        segAA(x / S, y / S, sc[0], sc[1] - 0.035, sc[0], sc[1] + 0.035, 0.009));
      over(px, x, y, cov, [255, 255, 255], 0.85);
    }
  }
  // 下坠的第二块板
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    const cov = rrAA(x / S, y / S, 0.30, 0.74, 0.34, 0.16, 0.03);
    over(px, x, y, cov, [176, 183, 197]);
  }
  return px;
}

function iconSudoku() {
  const px = canvas([46, 204, 113], [24, 110, 66]); // 绿
  shadow(px, 0.18, 0.18, 0.64, 0.64, 0.06);
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    const cov = rrAA(x / S, y / S, 0.18, 0.18, 0.64, 0.64, 0.06);
    over(px, x, y, cov, [253, 252, 248]);
  }
  // 数字块（色块代替数字）+ 一格朱红高亮
  const filled = [[0, 0], [1, 0], [2, 1], [0, 2], [2, 2], [1, 1, 'hl']];
  for (const f of filled) {
    const cx = 0.18 + f[0] * 0.64 / 3 + 0.64 / 6;
    const cy = 0.18 + f[1] * 0.64 / 3 + 0.64 / 6;
    const color = f[2] === 'hl' ? [192, 57, 43] : [52, 73, 94];
    for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
      const cov = rrAA(x / S, y / S, cx - 0.075, cy - 0.075, 0.15, 0.15, 0.03);
      over(px, x, y, cov, color);
    }
  }
  // 宫格线
  for (let g = 1; g < 3; g++) {
    const pos = 0.18 + g * 0.64 / 3;
    for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
      over(px, x, y, segAA(x / S, y / S, pos, 0.18, pos, 0.82, 0.008), [52, 73, 94], 0.5);
      over(px, x, y, segAA(x / S, y / S, 0.18, pos, 0.82, pos, 0.008), [52, 73, 94], 0.5);
    }
  }
  return px;
}

function iconLink() {
  const px = canvas([155, 89, 182], [106, 44, 140]); // 紫
  const tiles = [[0.18, 0.62], [0.70, 0.20]];
  const pts = [[0.28, 0.67], [0.28, 0.28], [0.75, 0.28], [0.75, 0.33]];
  shadow(px, 0.18, 0.62, 0.22, 0.22, 0.05);
  shadow(px, 0.70, 0.20, 0.22, 0.22, 0.05);
  // 连线（两折）
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    let cov = 0;
    for (let i = 0; i < pts.length - 1; i++) {
      cov = Math.max(cov, segAA(x / S, y / S, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], 0.016));
    }
    over(px, x, y, cov, [255, 236, 179]);
  }
  // 两块牌
  const tileColors = [[241, 196, 15], [241, 196, 15]];
  for (let i = 0; i < 2; i++) {
    for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
      let cov = rrAA(x / S, y / S, tiles[i][0], tiles[i][1], 0.22, 0.22, 0.05);
      over(px, x, y, cov, [253, 252, 248]);
      cov = rrAA(x / S, y / S, tiles[i][0] + 0.05, tiles[i][1] + 0.05, 0.12, 0.12, 0.03);
      over(px, x, y, cov, tileColors[i]);
    }
  }
  return px;
}

function iconBlock() {
  const px = canvas([52, 152, 219], [30, 95, 158]); // 深蓝
  shadow(px, 0.16, 0.22, 0.68, 0.68, 0.05);
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    over(px, x, y, rrAA(x / S, y / S, 0.16, 0.22, 0.68, 0.68, 0.05), [236, 240, 246]);
  }
  // 已填格
  const cells = [[0, 0], [1, 0], [2, 0], [3, 0], [0, 1], [3, 1], [0, 2], [3, 2], [0, 3], [1, 3], [2, 3], [3, 3]];
  for (const c of cells) {
    const cx = 0.20 + c[0] * 0.15, cy = 0.26 + c[1] * 0.15;
    for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
      over(px, x, y, rrAA(x / S, y / S, cx, cy, 0.11, 0.11, 0.025), [93, 109, 126]);
    }
  }
  // 消除行（金色横排）
  for (let x = 0; x < 4; x++) {
    const cx = 0.20 + x * 0.15, cy = 0.26 + 1 * 0.15;
    for (let y = 0; y < S; y++) for (let xx = 0; xx < S; xx++) {
      over(px, xx, y, rrAA(xx / S, y / S, cx, cy, 0.11, 0.11, 0.025), [241, 196, 15]);
    }
  }
  // 下落中的块
  for (let x = 0; x < 2; x++) {
    const cx = 0.36 + x * 0.15, cy = 0.06;
    for (let y = 0; y < S; y++) for (let xx = 0; xx < S; xx++) {
      over(px, xx, y, rrAA(xx / S, y / S, cx, cy, 0.11, 0.11, 0.025), [231, 76, 60]);
    }
  }
  return px;
}

function iconBallSort() {
  const px = canvas([230, 126, 34], [168, 82, 20]); // 橙
  const tubes = [[0.20, [192, 57, 43, 39, 174, 96]], [0.44, [41, 128, 185, 41, 128, 185]], [0.68, [0, 0, 0, 241, 196, 15]]];
  for (const tb of tubes) {
    shadow(px, tb[0], 0.20, 0.14, 0.62, 0.05);
    // 试管（半透明白）
    for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
      over(px, x, y, rrAA(x / S, y / S, tb[0], 0.20, 0.14, 0.62, 0.05), [253, 252, 248], 0.55);
    }
    // 球
    const balls = tb[1];
    for (let b = 0; b < 3; b++) {
      const color = balls[b * 3] === 0 ? null : [balls[b * 3], balls[b * 3 + 1], balls[b * 3 + 2]];
      if (!color) continue;
      const cx = tb[0] + 0.07, cy = 0.72 - b * 0.155;
      for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
        over(px, x, y, circleAA(x / S, y / S, cx, cy, 0.055), color);
      }
    }
  }
  return px;
}

function iconNonogram() {
  const px = canvas([26, 188, 156], [17, 122, 101]); // 青
  shadow(px, 0.20, 0.20, 0.60, 0.60, 0.05);
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    over(px, x, y, rrAA(x / S, y / S, 0.20, 0.20, 0.60, 0.60, 0.05), [253, 252, 248]);
  }
  // 像素画（心形）
  const heart = [[1, 0], [2, 0], [0, 1], [1, 1], [2, 1], [3, 1], [1, 2], [2, 2], [1, 3], [2, 3], [0.5, 1.5]];
  for (const h of heart) {
    const cx = 0.22 + h[0] * 0.14, cy = 0.22 + h[1] * 0.14;
    for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
      over(px, x, y, rrAA(x / S, y / S, cx, cy, 0.115, 0.115, 0.015), [44, 62, 80]);
    }
  }
  // 线索
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    over(px, x, y, circleAA(x / S, y / S, 0.10, 0.36, 0.014), [192, 57, 43]);
    over(px, x, y, circleAA(x / S, y / S, 0.36, 0.10, 0.014), [192, 57, 43]);
  }
  return px;
}

function iconParking() {
  const px = canvas([231, 76, 60], [155, 40, 27]); // 红
  // 停车位格线
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    over(px, x, y, rrAA(x / S, y / S, 0.10, 0.16, 0.66, 0.68, 0.04), [253, 252, 248], 0.25);
  }
  // 红车
  shadow(px, 0.18, 0.36, 0.46, 0.28, 0.06);
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    over(px, x, y, rrAA(x / S, y / S, 0.18, 0.36, 0.46, 0.28, 0.06), [46, 64, 82]);
  }
  // 车窗
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    over(px, x, y, rrAA(x / S, y / S, 0.24, 0.40, 0.16, 0.20, 0.025), [174, 214, 241]);
  }
  // 车轮
  for (const wx of [0.26, 0.50]) {
    for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
      over(px, x, y, circleAA(x / S, y / S, wx, 0.66, 0.045), [30, 32, 36]);
    }
  }
  // 出口箭头
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    let cov = segAA(x / S, y / S, 0.72, 0.50, 0.86, 0.50, 0.020);
    cov = Math.max(cov, segAA(x / S, y / S, 0.80, 0.43, 0.88, 0.50, 0.020));
    cov = Math.max(cov, segAA(x / S, y / S, 0.80, 0.57, 0.88, 0.50, 0.020));
    over(px, x, y, cov, [255, 236, 179]);
  }
  return px;
}

function iconKlotski() {
  const px = canvas([241, 196, 15], [194, 148, 8]); // 金
  shadow(px, 0.14, 0.14, 0.72, 0.72, 0.05);
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    over(px, x, y, rrAA(x / S, y / S, 0.14, 0.14, 0.72, 0.72, 0.05), [91, 63, 30]);
  }
  const pieces = [
    [0.18, 0.18, 0.32, 0.32, [192, 57, 43]],   // 曹操 2x2
    [0.54, 0.18, 0.14, 0.32, [93, 109, 126]],  // 竖将
    [0.54, 0.54, 0.28, 0.14, [52, 152, 219]],  // 横将
    [0.18, 0.54, 0.14, 0.14, [236, 240, 246]], // 兵
    [0.36, 0.72, 0.14, 0.14, [236, 240, 246]], // 兵
  ];
  for (const p of pieces) {
    for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
      over(px, x, y, rrAA(x / S, y / S, p[0], p[1], p[2], p[3], 0.02), p[4]);
      const cov = rrAA(x / S, y / S, p[0] + 0.015, p[1] + 0.015, p[2] - 0.03, p[3] - 0.03, 0.015);
      over(px, x, y, cov, [255, 255, 255], 0.18);
    }
  }
  return px;
}

const ICONS = {
  'game_screw': iconScrew,
  'game_sudoku': iconSudoku,
  'game_link': iconLink,
  'game_block': iconBlock,
  'game_ballsort': iconBallSort,
  'game_nonogram': iconNonogram,
  'game_parking': iconParking,
  'game_klotski': iconKlotski,
};

const outdir = process.argv[2] ?? '../entry/src/main/resources/base/media';
fs.mkdirSync(outdir, { recursive: true });
for (const [name, fn] of Object.entries(ICONS)) {
  render(fn(), path.join(outdir, `${name}.png`));
}
console.log('全部图标已生成 →', outdir);
