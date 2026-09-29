/**
 * 球球排序引擎：同色入管 / 容量 4 / 逆向打乱保证必可解
 */

export interface Move {
  from: number
  to: number
  n: number       // 倒了几颗
}

export interface SortLevel {
  tubes: number[][]
  colors: number
  capacity: number
}

/** 从已解局面出发做随机合法倒灌 N 次 → 局面必可解（逆序即解） */
export function makeSortLevel(level: number, rnd: () => number): SortLevel {
  let colors = 3
  let spare = 2
  if (level >= 3) {
    colors = 4
  }
  if (level >= 6) {
    colors = 5
    spare = 2
  }
  if (level >= 10) {
    colors = 6
    spare = 1
  }
  if (level >= 15) {
    colors = 7
    spare = 1
  }
  if (level >= 22) {
    colors = 8
    spare = 1
  }
  const capacity = 4
  const total = colors + spare
  const tubes: number[][] = []
  for (let i = 0; i < colors; i++) {
    tubes.push([i, i, i, i])
  }
  for (let i = 0; i < spare; i++) {
    tubes.push([])
  }
  const scrambleSteps = 14 + Math.min(26, level * 2)
  let lastFrom = -1
  let lastTo = -1
  for (let s = 0; s < scrambleSteps; s++) {
    // 选一次合法倒灌（打乱方向与游玩方向相同；同色成组倒入）
    const cands: number[][] = []
    for (let a = 0; a < total; a++) {
      for (let b = 0; b < total; b++) {
        if (a === b || a === lastTo && b === lastFrom) {
          continue
        }
        if (canPour(tubes, a, b, capacity)) {
          cands.push([a, b])
        }
      }
    }
    if (cands.length === 0) {
      break
    }
    const pick = cands[Math.floor(rnd() * cands.length)]
    doPour(tubes, pick[0], pick[1], capacity)
    lastFrom = pick[0]
    lastTo = pick[1]
  }
  return { tubes: tubes, colors: colors, capacity: capacity }
}

/** a 顶部同色连续段长度 */
export function topGroup(tubes: number[][], a: number): number {
  const t = tubes[a]
  if (t.length === 0) {
    return 0
  }
  const c = t[t.length - 1]
  let n = 1
  for (let i = t.length - 2; i >= 0; i--) {
    if (t[i] === c) {
      n++
    } else {
      break
    }
  }
  return n
}

export function canPour(tubes: number[][], a: number, b: number, capacity: number): boolean {
  const ta = tubes[a]
  const tb = tubes[b]
  if (ta.length === 0) {
    return false
  }
  if (b === a) {
    return false
  }
  // 目标已满或顶色不同 → 不可
  if (tb.length >= capacity) {
    return false
  }
  if (tb.length === 0) {
    // 倒入空管：源管不是纯色才算有意义的挪动（打乱与游玩一致：允许，但纯色满管倒入空管无意义）
    if (topGroup(tubes, a) === ta.length && isUniform(ta)) {
      return false
    }
    return true
  }
  return tb[tb.length - 1] === ta[ta.length - 1]
}

export function doPour(tubes: number[][], a: number, b: number, capacity: number): Move {
  const groupN = topGroup(tubes, a)
  const space = capacity - tubes[b].length
  const n = Math.min(groupN, space)
  const color = tubes[a][tubes[a].length - 1]
  for (let i = 0; i < n; i++) {
    tubes[a].pop()
    tubes[b].push(color)
  }
  return { from: a, to: b, n: n }
}

export function isUniform(t: number[]): boolean {
  if (t.length === 0) {
    return true
  }
  for (const v of t) {
    if (v !== t[0]) {
      return false
    }
  }
  return true
}

/** 胜利：所有非空管都是纯色（允许未满） */
export function isSolved(tubes: number[][], capacity: number): boolean {
  void capacity
  for (const t of tubes) {
    if (t.length === 0) {
      continue
    }
    if (!isUniform(t)) {
      return false
    }
  }
  return true
}

/** 撤销一步 */
export function undoMove(tubes: number[][], m: Move): void {
  for (let i = 0; i < m.n; i++) {
    const v = tubes[m.to].pop()
    if (v !== undefined) {
      tubes[m.from].push(v)
    }
  }
}

export const BALL_COLORS: string[] = ['#C0392B', '#2980B9', '#27AE60', '#8E44AD', '#D4AC0D', '#E67E22', '#16A085', '#2C3E50']
