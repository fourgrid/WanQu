/**
 * 挪车出道引擎：滑块移车 / BFS 求解保证可解 / 红车出库即胜
 */

export interface Car {
  id: number        // 0 = 红车（主车）
  r: number
  c: number
  len: number
  horiz: boolean
}

export interface ParkLevel {
  rows: number
  cols: number
  exitRow: number
  cars: Car[]
  par: number       // 最少步数（BFS）
}

export function makeParkLevel(level: number, rnd: () => number, tries: number): ParkLevel | null {
  for (let t = 0; t < tries; t++) {
    const lv = tryOne(level, rnd)
    if (lv) {
      return lv
    }
  }
  return null
}

function tryOne(level: number, rnd: () => number): ParkLevel | null {
  const rows = 5
  const cols = 6
  const exitRow = 2
  const cars: Car[] = []
  const grid = (): number[][] => {
    const g: number[][] = []
    for (let r = 0; r < rows; r++) {
      g.push(new Array(cols).fill(-1))
    }
    for (const car of cars) {
      for (let k = 0; k < car.len; k++) {
        if (car.horiz) {
          g[car.r][car.c + k] = car.id
        } else {
          g[car.r + k][car.c] = car.id
        }
      }
    }
    return g
  }
  // 红车 1x2 横放在出口行
  const redC = Math.floor(rnd() * 2)
  cars.push({ id: 0, r: exitRow, c: redC, len: 2, horiz: true })
  // 其它车 4~6 辆（难度渐进）
  const carN = Math.min(4 + Math.floor(level / 2), 7)
  let id = 1
  let guard = 0
  while (id <= carN && guard++ < 200) {
    const horiz = rnd() < 0.6
    const len = rnd() < 0.5 ? 2 : 3
    const r = Math.floor(rnd() * (horiz ? rows : rows - len + 1))
    const c = Math.floor(rnd() * (horiz ? cols - len + 1 : cols))
    let clash = false
    const g = grid()
    for (let k = 0; k < len; k++) {
      const rr = horiz ? r : r + k
      const cc = horiz ? c + k : c
      if (g[rr][cc] >= 0) {
        clash = true
      }
    }
    if (clash) {
      continue
    }
    cars.push({ id: id, r: r, c: c, len: len, horiz: horiz })
    id++
  }
  const par = solve(cars, rows, cols, exitRow)
  if (par > Math.min(4 + level, 18) || par < 3) {
    return null
  }
  return { rows: rows, cols: cols, exitRow: exitRow, cars: cars, par: par }
}

/** BFS：返回红车出库最少步数，无解返回 -1 */
export function solve(cars: Car[], rows: number, cols: number, exitRow: number): number {
  const keyOf = (cs: Car[]): string => {
    const parts: string[] = []
    for (const c of cs) {
      parts.push(`${c.r},${c.c}`)
    }
    return parts.join('|')
  }
  const cloneCars = (cs: Car[]): Car[] => {
    return cs.map((c: Car): Car => {
      return { id: c.id, r: c.r, c: c.c, len: c.len, horiz: c.horiz }
    })
  }
  const occupied = (cs: Car[], r: number, c: number): boolean => {
    for (const car of cs) {
      for (let k = 0; k < car.len; k++) {
        const rr = car.horiz ? car.r : car.r + k
        const cc = car.horiz ? car.c + k : car.c
        if (rr === r && cc === c) {
          return true
        }
      }
    }
    return false
  }
  const start = cloneCars(cars)
  const visited: Record<string, number> = {}
  visited[keyOf(start)] = 0
  const queue: Car[][] = [start]
  let head = 0
  while (head < queue.length) {
    const cur = queue[head]
    head++
    const steps = visited[keyOf(cur)]
    // 红车可出（右侧无阻挡直至边界）
    const red = cur[0]
    let free = true
    for (let c = red.c + red.len; c < cols; c++) {
      if (occupied(cur, red.r, c)) {
        free = false
        break
      }
    }
    if (free) {
      return steps + 1
    }
    // 每车尝试单格滑动
    for (let i = 0; i < cur.length; i++) {
      const car = cur[i]
      for (const d of [-1, 1]) {
        const next = cloneCars(cur)
        const nc = next[i]
        if (car.horiz) {
          const nc2 = nc.c + d
          if (nc2 < 0 || nc2 + car.len > cols) {
            continue
          }
          const probeC = d > 0 ? nc2 + car.len - 1 : nc2
          if (occupied(cur, car.r, probeC)) {
            continue
          }
          nc.c = nc2
        } else {
          const nr2 = nc.r + d
          if (nr2 < 0 || nr2 + car.len > rows) {
            continue
          }
          const probeR = d > 0 ? nr2 + car.len - 1 : nr2
          if (occupied(cur, probeR, car.c)) {
            continue
          }
          nc.r = nr2
        }
        const key = keyOf(next)
        if (visited[key] === undefined) {
          visited[key] = steps + 1
          queue.push(next)
        }
      }
    }
  }
  return -1
}

/** 尝试移动某车 ±1 格（返回是否移动） */
export function slide(cars: Car[], carId: number, d: number, rows: number, cols: number): boolean {
  const car = cars.find((c: Car): boolean => c.id === carId)
  if (!car) {
    return false
  }
  const blocked = (r: number, c: number): boolean => {
    for (const other of cars) {
      if (other.id === car.id) {
        continue
      }
      for (let k = 0; k < other.len; k++) {
        const rr = other.horiz ? other.r : other.r + k
        const cc = other.horiz ? other.c + k : other.c
        if (rr === r && cc === c) {
          return true
        }
      }
    }
    return false
  }
  if (car.horiz) {
    const nc = car.c + d
    if (nc < 0 || nc + car.len > cols) {
      return false
    }
    const probeC = d > 0 ? nc + car.len - 1 : nc
    if (blocked(car.r, probeC)) {
      return false
    }
    car.c = nc
    return true
  }
  const nr = car.r + d
  if (nr < 0 || nr + car.len > rows) {
    return false
  }
  const probeR = d > 0 ? nr + car.len - 1 : nr
  if (blocked(probeR, car.c)) {
    return false
  }
  car.r = nr
  return true
}

/** 红车是否紧邻出口且右侧通畅 */
export function redCanExit(cars: Car[], cols: number): boolean {
  const red = cars[0]
  for (let c = red.c + red.len; c < cols; c++) {
    for (const car of cars) {
      if (car.id === 0) {
        continue
      }
      for (let k = 0; k < car.len; k++) {
        const cc = car.horiz ? car.c + k : car.c
        const rr = car.horiz ? car.r : car.r + k
        if (rr === red.r && cc === c) {
          return false
        }
      }
    }
  }
  return true
}

export const CAR_COLORS: string[] = ['#C0392B', '#2980B9', '#27AE60', '#8E44AD', '#D4AC0D', '#E67E22', '#16A085', '#2C3E50']
