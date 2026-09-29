/**
 * 数独引擎：随机终盘生成 + 挖洞（唯一解校验）+ 求解计数
 * 表示：number[81]，0 为空格；行 r 列 c → idx = r*9+c
 */

/** 确定性随机（每日一题用） */
export class Rand {
  private a: number

  constructor(seed: number) {
    this.a = seed >>> 0
  }

  next(): number {
    let a = this.a
    a = (a + 0x6D2B79F5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    this.a = a
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }

  int(n: number): number {
    return Math.floor(this.next() * n)
  }
}

/** 求解并计数（最多到 cap 个解就停） */
export function countSolutions(grid: number[], cap: number): number {
  const g = grid.slice()
  let count = 0

  const solve = (): boolean => {
    let best = -1
    let bestCands: number[] = []
    // 找候选最少的空格（提速）
    for (let i = 0; i < 81; i++) {
      if (g[i] === 0) {
        const cands: number[] = []
        for (let v = 1; v <= 9; v++) {
          if (okAt(g, i, v)) {
            cands.push(v)
          }
        }
        if (cands.length === 0) {
          return false
        }
        if (best < 0 || cands.length < bestCands.length) {
          best = i
          bestCands = cands
          if (cands.length === 1) {
            break
          }
        }
      }
    }
    if (best < 0) {
      count++
      return count >= cap
    }
    for (const v of bestCands) {
      g[best] = v
      if (solve()) {
        g[best] = 0
        return true
      }
      g[best] = 0
    }
    return false
  }

  solve()
  return count
}

function okAt(g: number[], idx: number, v: number): boolean {
  const r = Math.floor(idx / 9)
  const c = idx % 9
  for (let i = 0; i < 9; i++) {
    if (g[r * 9 + i] === v || g[i * 9 + c] === v) {
      return false
    }
  }
  const br = Math.floor(r / 3) * 3
  const bc = Math.floor(c / 3) * 3
  for (let i = 0; i < 3; i++) {
    for (let j = 0; j < 3; j++) {
      if (g[(br + i) * 9 + bc + j] === v) {
        return false
      }
    }
  }
  return true
}

/** 生成随机终盘 */
export function generateFull(rand: Rand): number[] {
  const g: number[] = new Array(81).fill(0)
  const fill = (pos: number): boolean => {
    if (pos === 81) {
      return true
    }
    const nums: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9]
    for (let i = nums.length - 1; i > 0; i--) {
      const j = rand.int(i + 1)
      const t = nums[i]
      nums[i] = nums[j]
      nums[j] = t
    }
    for (const v of nums) {
      if (okAt(g, pos, v)) {
        g[pos] = v
        if (fill(pos + 1)) {
          return true
        }
        g[pos] = 0
      }
    }
    return false
  }
  fill(0)
  return g
}

export interface SudokuPuzzle {
  puzzle: number[]    // 0 为空
  solution: number[]  // 终盘
  clues: number
}

/** 挖洞生成谜题：目标提示数 targetClues，保证唯一解 */
export function makePuzzle(rand: Rand, targetClues: number): SudokuPuzzle {
  const full = generateFull(rand)
  const puzzle = full.slice()
  const order: number[] = []
  for (let i = 0; i < 81; i++) {
    order.push(i)
  }
  for (let i = order.length - 1; i > 0; i--) {
    const j = rand.int(i + 1)
    const t = order[i]
    order[i] = order[j]
    order[j] = t
  }
  let clues = 81
  for (const idx of order) {
    if (clues <= targetClues) {
      break
    }
    const backup = puzzle[idx]
    puzzle[idx] = 0
    if (countSolutions(puzzle, 2) !== 1) {
      puzzle[idx] = backup
    } else {
      clues--
    }
  }
  return { puzzle: puzzle, solution: full, clues: clues }
}

/** 难度 → 提示数 */
export function cluesOfDifficulty(level: number): number {
  if (level === 0) {
    return 42   // 入门
  }
  if (level === 1) {
    return 34   // 进阶
  }
  if (level === 2) {
    return 28   // 困难
  }
  return 24     // 大师
}

export const DIFF_NAMES: string[] = ['入门', '进阶', '困难', '大师']

/** 某格与已填值是否冲突（同行/列/宫） */
export function cellConflicts(values: number[], idx: number): number[] {
  const out: number[] = []
  const v = values[idx]
  if (v === 0) {
    return out
  }
  const r = Math.floor(idx / 9)
  const c = idx % 9
  for (let i = 0; i < 9; i++) {
    const ri = r * 9 + i
    const ci = i * 9 + c
    if (ri !== idx && values[ri] === v) {
      out.push(ri)
    }
    if (ci !== idx && values[ci] === v) {
      out.push(ci)
    }
  }
  const br = Math.floor(r / 3) * 3
  const bc = Math.floor(c / 3) * 3
  for (let i = 0; i < 3; i++) {
    for (let j = 0; j < 3; j++) {
      const bi = (br + i) * 9 + bc + j
      if (bi !== idx && values[bi] === v) {
        out.push(bi)
      }
    }
  }
  return out
}
