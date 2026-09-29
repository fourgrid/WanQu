/**
 * 连连看引擎：可解洗牌 + ≤2 折点连通判定 + 路径点序列
 */

export interface LinkCell {
  id: number        // 唯一键
  tile: number      // 图案编号（相同的可连）
  removed: boolean
}

export interface Pt {
  x: number         // 格坐标，含边界：-1..cols
  y: number
}

/** 生成牌面：成对图案，保证初始可解（重试策略） */
export function makeBoard(rows: number, cols: number, kinds: number, seedFn: () => number): number[] {
  // 返回 tile 数组（rows*cols，偶数个），尝试直到可解
  for (let attempt = 0; attempt < 60; attempt++) {
    const tiles: number[] = []
    const total = rows * cols
    for (let i = 0; i < total / 2; i++) {
      const t = Math.floor(seedFn() * kinds)
      tiles.push(t)
      tiles.push(t)
    }
    shuffle(tiles, seedFn)
    if (boardSolvable(tiles, rows, cols)) {
      return tiles
    }
  }
  // 兜底：全部同图案（必可解）
  const tiles: number[] = []
  for (let i = 0; i < rows * cols / 2; i++) {
    tiles.push(0)
    tiles.push(0)
  }
  return tiles
}

function shuffle(a: number[], seedFn: () => number): void {
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(seedFn() * (i + 1))
    const t = a[i]
    a[i] = a[j]
    a[j] = t
  }
}

/** 模拟全自动消除，判断局面是否可解 */
export function boardSolvable(tiles: number[], rows: number, cols: number): boolean {
  const alive: number[] = tiles.slice()
  let guard = 0
  while (guard++ < 10000) {
    let removedAny = false
    outer: for (let a = 0; a < alive.length; a++) {
      if (alive[a] < 0) {
        continue
      }
      for (let b = a + 1; b < alive.length; b++) {
        if (alive[b] === alive[a] && alive[b] >= 0) {
          const pa: Pt = { x: a % cols, y: Math.floor(a / cols) }
          const pb: Pt = { x: b % cols, y: Math.floor(b / cols) }
          if (findPath(alive, rows, cols, pa, pb).length > 0) {
            alive[a] = -1
            alive[b] = -1
            removedAny = true
            break outer
          }
        }
      }
    }
    if (!removedAny) {
      break
    }
  }
  for (const v of alive) {
    if (v >= 0) {
      return false
    }
  }
  return true
}

/** 剩余牌数 */
export function remaining(tiles: number[]): number {
  let n = 0
  for (const v of tiles) {
    if (v >= 0) {
      n++
    }
  }
  return n
}

/**
 * 找 a→b 的 ≤2 折点路径，返回经过的格点序列（含起终点），无路返回空数组
 * tiles: 已消除为 -1；边界（环绕一圈）视为空。
 */
export function findPath(tiles: number[], rows: number, cols: number, a: Pt, b: Pt): Pt[] {
  // 空闲判定：越界一圈内视为空，格内有牌则不空
  const isEmpty = (x: number, y: number): boolean => {
    if (x < -1 || y < -1 || x > cols || y > rows) {
      return false
    }
    if (x === -1 || y === -1 || x === cols || y === rows) {
      return true   // 边界通道
    }
    return tiles[y * cols + x] < 0
  }
  const samePoint = (p: Pt, q: Pt): boolean => p.x === q.x && p.y === q.y
  const clearLine = (p: Pt, q: Pt): boolean => {
    if (p.x === q.x) {
      const from = Math.min(p.y, q.y) + 1
      const to = Math.max(p.y, q.y)
      for (let y = from; y <= to; y++) {
        if (!isEmpty(p.x, y)) {
          return false
        }
      }
      return true
    }
    if (p.y === q.y) {
      const from = Math.min(p.x, q.x) + 1
      const to = Math.max(p.x, q.x)
      for (let x = from; x <= to; x++) {
        if (!isEmpty(x, p.y)) {
          return false
        }
      }
      return true
    }
    return false
  }
  // 0 折
  if (clearLine(a, b)) {
    return [a, b]
  }
  // 1 折：拐点 c
  const c1: Pt = { x: a.x, y: b.y }
  if (isEmpty(c1.x, c1.y) && clearLine(a, c1) && clearLine(c1, b)) {
    return [a, c1, b]
  }
  const c2: Pt = { x: b.x, y: a.y }
  if (isEmpty(c2.x, c2.y) && clearLine(a, c2) && clearLine(c2, b)) {
    return [a, c2, b]
  }
  // 2 折：沿 a 的四个方向扫描中间点 m，再 1 折到 b
  for (let d = -1; d <= cols; d++) {
    // 水平方向
    const m1: Pt = { x: d, y: a.y }
    if (!samePoint(m1, a) && isEmpty(m1.x, m1.y) && clearLine(a, m1)) {
      const m2: Pt = { x: d, y: b.y }
      if (!samePoint(m2, b) && !samePoint(m2, m1) && isEmpty(m2.x, m2.y) && clearLine(m1, m2) && clearLine(m2, b)) {
        return [a, m1, m2, b]
      }
    }
  }
  for (let d = -1; d <= rows; d++) {
    // 垂直方向
    const m1: Pt = { x: a.x, y: d }
    if (!samePoint(m1, a) && isEmpty(m1.x, m1.y) && clearLine(a, m1)) {
      const m2: Pt = { x: b.x, y: d }
      if (!samePoint(m2, b) && !samePoint(m2, m1) && isEmpty(m2.x, m2.y) && clearLine(m1, m2) && clearLine(m2, b)) {
        return [a, m1, m2, b]
      }
    }
  }
  return []
}

/** 提示：找一对可连的牌 */
export function findHintPair(tiles: number[], rows: number, cols: number): Pt[] {
  for (let a = 0; a < tiles.length; a++) {
    if (tiles[a] < 0) {
      continue
    }
    for (let b = a + 1; b < tiles.length; b++) {
      if (tiles[b] === tiles[a] && tiles[b] >= 0) {
        const pa: Pt = { x: a % cols, y: Math.floor(a / cols) }
        const pb: Pt = { x: b % cols, y: Math.floor(b / cols) }
        if (findPath(tiles, rows, cols, pa, pb).length > 0) {
          return [pa, pb]
        }
      }
    }
  }
  return []
}

/** 死局检测：无任何可连对 */
export function isDead(tiles: number[], rows: number, cols: number): boolean {
  return remaining(tiles) > 0 && findHintPair(tiles, rows, cols).length === 0
}

/** 洗牌（保留剩余牌，重排位置），直到可解或尝试上限 */
export function reshuffle(tiles: number[], rows: number, cols: number, seedFn: () => number): void {
  const aliveIdx: number[] = []
  const aliveVal: number[] = []
  for (let i = 0; i < tiles.length; i++) {
    if (tiles[i] >= 0) {
      aliveIdx.push(i)
      aliveVal.push(tiles[i])
    }
  }
  for (let attempt = 0; attempt < 80; attempt++) {
    shuffle(aliveVal, seedFn)
    const next = tiles.slice()
    for (let k = 0; k < aliveIdx.length; k++) {
      next[aliveIdx[k]] = aliveVal[k]
    }
    if (boardSolvable(next, rows, cols)) {
      for (let k = 0; k < aliveIdx.length; k++) {
        tiles[aliveIdx[k]] = aliveVal[k]
      }
      return
    }
  }
  // 兜底：直接应用最后一次
  for (let k = 0; k < aliveIdx.length; k++) {
    tiles[aliveIdx[k]] = aliveVal[k]
  }
}
