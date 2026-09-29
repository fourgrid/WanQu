/**
 * 华容道引擎：经典布局库 + 单步滑动 + 曹操出底口判定
 * 棋盘 4 列 × 5 行；曹操 2×2；出口在底部中间两格。
 * 布局用字符画定义：K=曹操 2x2，V=竖将 1x2，H=横将 2x1，S=小兵 1x1
 */

export interface KPiece {
  id: number
  name: string
  r: number
  c: number
  w: number
  h: number
}

export interface KLayout {
  name: string
  par: number          // 通行最少步数（经典研究值，作参考）
  cells: string[]      // 5 行 × 4 列字符画
}

export const LAYOUTS: KLayout[] = [
  {
    name: '横刀立马',
    par: 81,
    cells: [
      'KVVK',
      'KVVK',
      'SHHS',
      'SVVS',
      'S..S',
    ],
  },
  {
    name: '指挥若定',
    par: 70,
    cells: [
      'KVVK',
      'KVVK',
      'SHHS',
      'SVVS',
      '..S.',
    ],
  },
  {
    name: '兵分三路',
    par: 72,
    cells: [
      'KVVK',
      'KVVK',
      'S..S',
      'SVVS',
      'SHHS',
    ],
  },
  {
    name: '雨声淅沥',
    par: 80,
    cells: [
      'KVVK',
      'KVVK',
      'SVVS',
      'S..S',
      'SHHS',
    ],
  },
  {
    name: '一路顺风',
    par: 90,
    cells: [
      'KKVV',
      'KKVV',
      'SHHS',
      'SVVS',
      'S..S',
    ],
  },
]

const PIECE_SPEC: Record<string, number[]> = {
  'K': [2, 2],
  'V': [1, 2],
  'H': [2, 1],
  'S': [1, 1],
}

export function parseLayout(layout: KLayout): KPiece[] {
  const pieces: KPiece[] = []
  const seen: Record<string, number> = {}
  for (let r = 0; r < layout.cells.length; r++) {
    const row = layout.cells[r]
    for (let c = 0; c < row.length; c++) {
      const ch = row[c]
      if (ch === '.' || ch === ' ') {
        continue
      }
      if (seen[`${r},${c}`]) {
        continue
      }
      const spec = PIECE_SPEC[ch]
      const w = spec[0]
      const h = spec[1]
      const id = pieces.length
      for (let dr = 0; dr < h; dr++) {
        for (let dc = 0; dc < w; dc++) {
          seen[`${r + dr},${c + dc}`] = 1
        }
      }
      const names: Record<string, string> = { 'K': '曹操', 'V': '武将', 'H': '关羽', 'S': '兵' }
      pieces.push({ id: id, name: names[ch] ?? '?', r: r, c: c, w: w, h: h })
    }
  }
  return pieces
}

/** 尝试向 d 方向移动一格（dr/dc），成功返回 true */
export function movePiece(pieces: KPiece[], id: number, dr: number, dc: number): boolean {
  const p = pieces.find((x: KPiece): boolean => x.id === id)
  if (!p) {
    return false
  }
  const nr = p.r + dr
  const nc = p.c + dc
  if (nr < 0 || nc < 0 || nr + p.h > 5 || nc + p.w > 4) {
    return false
  }
  // 目标区域是否为空（不含自身）
  for (const other of pieces) {
    if (other.id === p.id) {
      continue
    }
    const overlap = nr < other.r + other.h && nr + p.h > other.r &&
      nc < other.c + other.w && nc + p.w > other.c
    if (overlap) {
      return false
    }
  }
  p.r = nr
  p.c = nc
  return true
}

/** 曹操是否到达出口（底部中间 2 格） */
export function caocaoFree(pieces: KPiece[]): boolean {
  const k = pieces[0]
  return k.r === 3 && k.c === 1
}
