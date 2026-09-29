/**
 * 拧螺丝引擎：层叠板件 + 螺丝分色 + 顶部可拧 / 板件坠落
 * 板件覆盖单元格集合；某格螺丝是否可拧取决于其上方是否还有未坠落的板件。
 */

export interface Plate {
  id: number
  cells: number[]      // 占据的格 idx（row*COLS+col）
  layer: number        // 层号，越大越上
  fallen: boolean
}

export interface Screw {
  id: number
  cell: number
  plateId: number
  color: number        // 颜色编号 0..K-1
  taken: boolean
}

export interface ScrewLevel {
  rows: number
  cols: number
  plates: Plate[]
  screws: Screw[]
  bins: number[]       // 每色容量（≤4）
  colorCount: number
}

/** 形状：0=1x1 1=2x1横 2=1x2竖 3=3x1横 4=2x2 */
function shapeWH(kind: number): number[] {
  if (kind === 1) {
    return [2, 1]
  }
  if (kind === 2) {
    return [1, 2]
  }
  if (kind === 3) {
    return [3, 1]
  }
  if (kind === 4) {
    return [2, 2]
  }
  return [1, 1]
}

function shuffle(a: number[], rnd: () => number): void {
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1))
    const t = a[i]
    a[i] = a[j]
    a[j] = t
  }
}

/** 尝试生成一关（可能失败返回 null，调用方重试） */
export function makeLevel(level: number, rnd: () => number): ScrewLevel | null {
  const rows = 7
  const cols = 6
  const layerCount = level <= 2 ? 2 : 3
  const plateTarget = 4 + Math.min(5, level)
  const plates: Plate[] = []
  const screws: Screw[] = []
  const occupied: number[][] = []
  for (let z = 0; z < layerCount; z++) {
    occupied.push([])
  }
  let plateId = 0
  let screwId = 0
  let guard = 0
  while (plates.length < plateTarget && guard++ < 500) {
    const layer = Math.floor(rnd() * layerCount)
    const wh = shapeWH(Math.floor(rnd() * 5))
    const w = wh[0]
    const h = wh[1]
    const r0 = Math.floor(rnd() * (rows - h + 1))
    const c0 = Math.floor(rnd() * (cols - w + 1))
    const cells: number[] = []
    let clash = false
    for (let r = r0; r < r0 + h; r++) {
      for (let c = c0; c < c0 + w; c++) {
        const idx = r * cols + c
        if (occupied[layer].indexOf(idx) >= 0) {
          clash = true
        }
        cells.push(idx)
      }
    }
    if (clash) {
      continue
    }
    for (const c of cells) {
      occupied[layer].push(c)
    }
    const plate: Plate = { id: plateId++, cells: cells, layer: layer, fallen: false }
    plates.push(plate)
    const useN = Math.min(2 + Math.floor(rnd() * 3), cells.length)
    const shuffledCells = cells.slice()
    shuffle(shuffledCells, rnd)
    for (let k = 0; k < useN; k++) {
      screws.push({ id: screwId++, cell: shuffledCells[k], plateId: plate.id, color: 0, taken: false })
    }
  }
  if (plates.length < 4 || screws.length < 8) {
    return null
  }

  // 颜色数与每色容量（每色 2~4 颗），总容量即总螺丝数
  let colorCount = 3
  if (level >= 3) {
    colorCount = 4
  }
  if (level >= 7) {
    colorCount = 5
  }
  if (level >= 12) {
    colorCount = 6
  }
  colorCount = Math.max(3, Math.min(colorCount, Math.floor(screws.length / 2)))
  let total = screws.length
  while (colorCount * 4 < total) {
    // 超容量：削减螺丝（不破坏板件存活：只从螺丝数 ≥2 的板借）
    let donor = -1
    for (let i = screws.length - 1; i >= 0; i--) {
      let cnt = 0
      for (const s of screws) {
        if (s.plateId === screws[i].plateId) {
          cnt++
        }
      }
      if (cnt >= 2) {
        donor = i
        break
      }
    }
    if (donor < 0) {
      break
    }
    screws.splice(donor, 1)
    total--
  }
  const caps: number[] = []
  let assigned = 0
  for (let i = 0; i < colorCount; i++) {
    const cap = Math.min(4, total - assigned - 2 * (colorCount - i - 1))
    caps.push(cap)
    assigned += cap
  }
  const colorIds: number[] = []
  for (let ci = 0; ci < caps.length; ci++) {
    for (let k = 0; k < caps[ci]; k++) {
      colorIds.push(ci)
    }
  }
  shuffle(colorIds, rnd)
  for (let i = 0; i < screws.length; i++) {
    screws[i].color = colorIds[i]
  }
  return { rows: rows, cols: cols, plates: plates, screws: screws, bins: caps, colorCount: caps.length }
}

/** 某格上方（更高层）是否有未坠落板件覆盖 */
export function covered(level: ScrewLevel, cell: number, layer: number): boolean {
  for (const p of level.plates) {
    if (p.fallen || p.layer <= layer) {
      continue
    }
    if (p.cells.indexOf(cell) >= 0) {
      return true
    }
  }
  return false
}

/** 螺丝所属板件 */
export function plateOf(level: ScrewLevel, screw: Screw): Plate | undefined {
  for (const p of level.plates) {
    if (p.id === screw.plateId) {
      return p
    }
  }
  return undefined
}

/** 拧走一颗螺丝，返回坠落的板 id 列表（无螺丝则坠） */
export function takeScrew(level: ScrewLevel, screw: Screw): number[] {
  screw.taken = true
  const fallenIds: number[] = []
  const plate = plateOf(level, screw)
  if (!plate) {
    return fallenIds
  }
  let remain = 0
  for (const s of level.screws) {
    if (s.plateId === plate.id && !s.taken) {
      remain++
    }
  }
  if (remain === 0) {
    plate.fallen = true
    fallenIds.push(plate.id)
  }
  return fallenIds
}

export function allDone(level: ScrewLevel): boolean {
  for (const s of level.screws) {
    if (!s.taken) {
      return false
    }
  }
  return true
}

/** 每色已收数量 */
export function binCounts(level: ScrewLevel): number[] {
  const counts: number[] = new Array(level.colorCount).fill(0)
  for (const s of level.screws) {
    if (s.taken) {
      counts[s.color]++
    }
  }
  return counts
}

/** 生成器重试外壳 */
export function makeLevelRetry(level: number, rnd: () => number, tries: number): ScrewLevel | null {
  for (let i = 0; i < tries; i++) {
    const lv = makeLevel(level, rnd)
    if (lv) {
      return lv
    }
  }
  return null
}

export const SCREW_COLORS: string[] = ['#C0392B', '#2980B9', '#27AE60', '#8E44AD', '#D4AC0D', '#E67E22']
