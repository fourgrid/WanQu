/**
 * 数织引擎：随机图案 + 行解法器校验（保证可逻辑推演出）
 */

export interface NonogramPuzzle {
  size: number
  solution: number[]      // 0/1，idx = r*size+c
  rowClues: number[][]
  colClues: number[][]
}

/** 由行/列生成线索 */
export function cluesOf(line: number[]): number[] {
  const out: number[] = []
  let run = 0
  for (const v of line) {
    if (v === 1) {
      run++
    } else if (run > 0) {
      out.push(run)
      run = 0
    }
  }
  if (run > 0) {
    out.push(run)
  }
  if (out.length === 0) {
    out.push(0)
  }
  return out
}

/** 枚举一行所有符合线索的填法，与 known（-1未知 0空 1填）一致 */
function allFills(clue: number[], len: number, known: number[]): number[][] {
  const results: number[][] = []
  const build = (pos: number, ci: number, acc: number[]): void => {
    if (ci === clue.length) {
      for (let i = pos; i < len; i++) {
        if (known[i] === 1) {
          return
        }
        acc.push(0)
      }
      results.push(acc.slice())
      return
    }
    const need = clue[ci] + (ci < clue.length - 1 ? 1 : 0)
    for (let start = pos; start + need <= len; start++) {
      let ok = true
      const trial = acc.slice()
      for (let i = pos; i < start; i++) {
        if (known[i] === 1) {
          ok = false
          break
        }
        trial.push(0)
      }
      if (!ok) {
        continue
      }
      let ok2 = true
      for (let k = 0; k < clue[ci]; k++) {
        if (known[start + k] === 0) {
          ok2 = false
          break
        }
        trial.push(1)
      }
      if (!ok2) {
        continue
      }
      if (ci < clue.length - 1) {
        trial.push(0)
        build(start + clue[ci] + 1, ci + 1, trial)
      } else {
        build(start + clue[ci], ci + 1, trial)
      }
    }
  }
  build(0, 0, [])
  return results
}

/** 行解法器：逐行/列推进推理，判断是否可全解 */
export function lineSolvable(size: number, solution: number[]): boolean {
  const state: number[] = new Array(size * size).fill(-1)
  let progress = true
  let guard = 0
  while (progress && guard++ < 200) {
    progress = false
    // 行
    for (let r = 0; r < size; r++) {
      const rowClue = cluesOf(thisLine(solution, r, true, size))
      const known: number[] = []
      for (let c = 0; c < size; c++) {
        known.push(state[r * size + c])
      }
      if (doneLine(known)) {
        continue
      }
      const fills = allFills(rowClue, size, known)
      if (fills.length === 0) {
        return false
      }
      for (let c = 0; c < size; c++) {
        let all1 = true
        let all0 = true
        for (const f of fills) {
          if (f[c] === 0) {
            all1 = false
          } else {
            all0 = false
          }
        }
        if (all1 && state[r * size + c] === -1) {
          state[r * size + c] = 1
          progress = true
        }
        if (all0 && state[r * size + c] === -1) {
          state[r * size + c] = 0
          progress = true
        }
      }
    }
    // 列
    for (let c = 0; c < size; c++) {
      const colClue = cluesOf(thisLine(solution, c, false, size))
      const known: number[] = []
      for (let r = 0; r < size; r++) {
        known.push(state[r * size + c])
      }
      if (doneLine(known)) {
        continue
      }
      const fills = allFills(colClue, size, known)
      if (fills.length === 0) {
        return false
      }
      for (let r = 0; r < size; r++) {
        let all1 = true
        let all0 = true
        for (const f of fills) {
          if (f[r] === 0) {
            all1 = false
          } else {
            all0 = false
          }
        }
        if (all1 && state[r * size + c] === -1) {
          state[r * size + c] = 1
          progress = true
        }
        if (all0 && state[r * size + c] === -1) {
          state[r * size + c] = 0
          progress = true
        }
      }
    }
  }
  for (const v of state) {
    if (v === -1) {
      return false
    }
  }
  return true
}

function thisLine(grid: number[], idx: number, isRow: boolean, size: number): number[] {
  const out: number[] = []
  if (isRow) {
    for (let c = 0; c < size; c++) {
      out.push(grid[idx * size + c])
    }
  } else {
    for (let r = 0; r < size; r++) {
      out.push(grid[r * size + idx])
    }
  }
  return out
}

function doneLine(known: number[]): boolean {
  for (const v of known) {
    if (v === -1) {
      return false
    }
  }
  return true
}

/** 生成一关（限制尝试次数） */
export function makeNonogram(size: number, rnd: () => number, tries: number): NonogramPuzzle | null {
  for (let t = 0; t < tries; t++) {
    const sol: number[] = []
    for (let i = 0; i < size * size; i++) {
      sol.push(rnd() < 0.55 ? 1 : 0)
    }
    if (lineSolvable(size, sol)) {
      const rowClues: number[][] = []
      const colClues: number[][] = []
      for (let r = 0; r < size; r++) {
        rowClues.push(cluesOf(thisLine(sol, r, true, size)))
      }
      for (let c = 0; c < size; c++) {
        colClues.push(cluesOf(thisLine(sol, c, false, size)))
      }
      return { size: size, solution: sol, rowClues: rowClues, colClues: colClues }
    }
  }
  return null
}

/** 行/列当前填法是否符合线索（只看 filled=1，其余视为 0） */
export function lineMatches(cells: number[], clue: number[]): boolean {
  const filled: number[] = []
  for (const v of cells) {
    filled.push(v === 1 ? 1 : 0)
  }
  const got = cluesOf(filled)
  if (got.length !== clue.length) {
    return false
  }
  for (let i = 0; i < got.length; i++) {
    if (got[i] !== clue[i]) {
      return false
    }
  }
  return true
}
