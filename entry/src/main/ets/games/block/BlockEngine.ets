/**
 * 方块消除引擎：8×8 盘 / 三块候选 / 整行整列消除 / 连击计分
 */

export interface Piece {
  cells: number[]     // 相对坐标 r*10+c（上限 10 列足够）
  w: number
  h: number
  name: string
}

/** 用坐标串定义形状 */
function shape(name: string, coords: number[][]): Piece {
  let maxR = 0
  let maxC = 0
  const cells: number[] = []
  for (const rc of coords) {
    maxR = Math.max(maxR, rc[0])
    maxC = Math.max(maxC, rc[1])
    cells.push(rc[0] * 10 + rc[1])
  }
  return { cells: cells, w: maxC + 1, h: maxR + 1, name: name }
}

export const SHAPES: Piece[] = [
  shape('I2h', [[0, 0], [0, 1]]),
  shape('I2v', [[0, 0], [1, 0]]),
  shape('I3h', [[0, 0], [0, 1], [0, 2]]),
  shape('I3v', [[0, 0], [1, 0], [2, 0]]),
  shape('I4h', [[0, 0], [0, 1], [0, 2], [0, 3]]),
  shape('I4v', [[0, 0], [1, 0], [2, 0], [3, 0]]),
  shape('I5h', [[0, 0], [0, 1], [0, 2], [0, 3], [0, 4]]),
  shape('I5v', [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]]),
  shape('O', [[0, 0], [0, 1], [1, 0], [1, 1]]),
  shape('R23', [[0, 0], [0, 1], [0, 2], [1, 0], [1, 1], [1, 2]]),
  shape('R32', [[0, 0], [0, 1], [1, 0], [1, 1], [2, 0], [2, 1]]),
  shape('L4a', [[0, 0], [1, 0], [1, 1], [1, 2]]),
  shape('L4b', [[0, 0], [0, 1], [0, 2], [1, 2]]),
  shape('L4c', [[0, 0], [0, 1], [0, 2], [1, 0]]),
  shape('L4d', [[0, 2], [1, 0], [1, 1], [1, 2]]),
  shape('T4a', [[0, 0], [0, 1], [0, 2], [1, 1]]),
  shape('T4b', [[0, 1], [1, 0], [1, 1], [2, 1]]),
  shape('S', [[0, 1], [0, 2], [1, 0], [1, 1]]),
  shape('Z', [[0, 0], [0, 1], [1, 1], [1, 2]]),
]

export const SIZE = 8

export function newGrid(): number[] {
  return new Array(SIZE * SIZE).fill(0)
}

export function canPlace(grid: number[], piece: Piece, r: number, c: number): boolean {
  if (r < 0 || c < 0 || r + piece.h > SIZE || c + piece.w > SIZE) {
    return false
  }
  for (const cell of piece.cells) {
    const rr = r + Math.floor(cell / 10)
    const cc = c + (cell % 10)
    if (grid[rr * SIZE + cc] !== 0) {
      return false
    }
  }
  return true
}

export function place(grid: number[], piece: Piece, r: number, c: number): number[] {
  const next = grid.slice()
  for (const cell of piece.cells) {
    const rr = r + Math.floor(cell / 10)
    const cc = c + (cell % 10)
    next[rr * SIZE + cc] = 1
  }
  return next
}

/** 已满的行号与列号 */
export function fullLines(grid: number[]): number[][] {
  const rows: number[] = []
  const cols: number[] = []
  for (let r = 0; r < SIZE; r++) {
    let full = true
    for (let c = 0; c < SIZE; c++) {
      if (grid[r * SIZE + c] === 0) {
        full = false
      }
    }
    if (full) {
      rows.push(r)
    }
  }
  for (let c = 0; c < SIZE; c++) {
    let full = true
    for (let r = 0; r < SIZE; r++) {
      if (grid[r * SIZE + c] === 0) {
        full = false
      }
    }
    if (full) {
      cols.push(c)
    }
  }
  return [rows, cols]
}

/** 消除指定行列，返回新盘面与消除格集合 */
export function clearLines(grid: number[], rows: number[], cols: number[]): number[] {
  const next = grid.slice()
  const cells: number[] = []
  for (const r of rows) {
    for (let c = 0; c < SIZE; c++) {
      next[r * SIZE + c] = 0
      cells.push(r * SIZE + c)
    }
  }
  for (const c of cols) {
    for (let r = 0; r < SIZE; r++) {
      if (next[r * SIZE + c] !== 0) {
        cells.push(r * SIZE + c)
      }
      next[r * SIZE + c] = 0
    }
  }
  void cells
  return next
}

/** 本步得分：放置格数 + 行列消除分 + 连击加成 */
export function scoreFor(placed: number, lines: number, combo: number): number {
  let s = placed
  if (lines > 0) {
    s += lines * 10
    if (lines > 1) {
      s += (lines - 1) * 20
    }
    s += combo * 10
  }
  return s
}

/** 任意 piece 是否还可放置（判死局） */
export function anyPlaceable(grid: number[], pieces: (Piece | null)[]): boolean {
  for (const p of pieces) {
    if (!p) {
      continue
    }
    for (let r = 0; r <= SIZE - p.h; r++) {
      for (let c = 0; c <= SIZE - p.w; c++) {
        if (canPlace(grid, p, r, c)) {
          return true
        }
      }
    }
  }
  return false
}

export function randomPieces(n: number): (Piece | null)[] {
  const out: (Piece | null)[] = []
  for (let i = 0; i < n; i++) {
    out.push(SHAPES[Math.floor(Math.random() * SHAPES.length)])
  }
  return out
}
