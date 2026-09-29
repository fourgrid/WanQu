// make-icon.mjs — 玩趣图标：宣纸底 + 金框 + 2×2 四色游戏块 + 右下朱砂印
// 用法: node make-icon.mjs <size> <out.png ...>
import zlib from 'node:zlib';
import fs from 'node:fs';

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

function png(width, height, rgba) {
  const sig = Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0); ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; ihdr[9] = 6;
  const raw = Buffer.alloc((width * 4 + 1) * height);
  for (let y = 0; y < height; y++) {
    raw[y * (width * 4 + 1)] = 0;
    rgba.copy(raw, y * (width * 4 + 1) + 1, y * width * 4, (y + 1) * width * 4);
  }
  return Buffer.concat([sig, chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}

function inRR(px, py, x, y, w, h, r) {
  const cx = Math.min(Math.max(px, x + r), x + w - r);
  const cy = Math.min(Math.max(py, y + r), y + h - r);
  const dx = px - cx, dy = py - cy;
  const d2 = dx * dx + dy * dy;
  if (d2 <= (r - 0.75) * (r - 0.75)) return 1;
  if (d2 <= (r + 0.75) * (r + 0.75)) {
    const d = Math.sqrt(d2);
    return Math.min(1, Math.max(0, (r + 0.75 - d) / 1.5));
  }
  const inBox = px >= x && px <= x + w && py >= y && py <= y + h;
  if (inBox) {
    const nearEdge = Math.min(px - x, x + w - px, py - y, y + h - py);
    if (nearEdge > 0.75) return 1;
  }
  return 0;
}

const PAPER = [246, 241, 231];
const GOLD = [185, 143, 69];
const RED = [168, 63, 57];
const QUADS = [[192, 57, 43], [41, 128, 185], [39, 174, 96], [142, 68, 173]];

function mix(c1, c2, t) {
  return [Math.round(c1[0] + (c2[0] - c1[0]) * t), Math.round(c1[1] + (c2[1] - c1[1]) * t), Math.round(c1[2] + (c2[2] - c1[2]) * t)];
}

function drawIcon(S) {
  const buf = Buffer.alloc(S * S * 4);
  const frame = S * 0.011;
  const inset = S * 0.052;
  const zone = S * 0.44;           // 四色块区边长
  const zx = (S - zone) / 2 - S * 0.02;
  const zy = (S - zone) / 2 - S * 0.02;
  const gap = zone * 0.1;
  const q = (zone - gap) / 2;
  const seal = S * 0.1;
  for (let y = 0; y < S; y++) {
    for (let x = 0; x < S; x++) {
      let c = PAPER.slice();
      // 暗角
      const dxn = (x / S - 0.5) * 2, dyn = (y / S - 0.5) * 2;
      const dist = Math.sqrt(dxn * dxn + dyn * dyn) / Math.SQRT2;
      c = mix(c, [150, 140, 120], Math.min(0.3, dist * dist * 0.35));
      // 金框
      const fAA = inRR(x, y, inset, inset, S - 2 * inset, S - 2 * inset, S * 0.06);
      const fHole = inRR(x, y, inset + frame, inset + frame, S - 2 * inset - 2 * frame, S - 2 * inset - 2 * frame, S * 0.055);
      const fCov = Math.max(0, fAA - fHole);
      if (fCov > 0) c = mix(c, GOLD, fCov * 0.9);
      // 四色块
      for (let i = 0; i < 4; i++) {
        const qx = zx + (i % 2) * (q + gap);
        const qy = zy + Math.floor(i / 2) * (q + gap);
        const cov = inRR(x, y, qx, qy, q, q, q * 0.3);
        if (cov > 0) c = mix(c, QUADS[i], cov);
      }
      // 朱砂印
      const sx = S - inset - frame * 2.2 - seal, sy = S - inset - frame * 2.2 - seal;
      const sAA = inRR(x, y, sx, sy, seal, seal, seal * 0.16);
      if (sAA > 0) c = mix(c, RED, sAA);
      const o = (y * S + x) * 4;
      buf[o] = c[0]; buf[o + 1] = c[1]; buf[o + 2] = c[2]; buf[o + 3] = 255;
    }
  }
  return png(S, S, buf);
}

const size = Number(process.argv[2] ?? 216);
const outs = process.argv.slice(3);
if (!outs.length) { console.error('用法: node make-icon.mjs <size> <out.png ...>'); process.exit(1); }
const bin = drawIcon(size);
for (const p of outs) { fs.writeFileSync(p, bin); console.log('✔', p, bin.length, 'bytes'); }
