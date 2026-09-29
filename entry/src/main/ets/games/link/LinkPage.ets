/**
 * 连连看 · 产品级（含经典重力关卡模式）
 * 关卡方向：L1 经典静止 → L2 下落 → L3 上升 → L4 左移 → L5 右移 → L6+ 向中间靠拢
 * 牌实体（身份固定、绝对定位）使重力塌落有真实滑动动画。
 */
import { makeBoard, findPath, findHintPair, isDead, reshuffle, remaining, Pt, TileEnt, applyGravity, GRAVITY_NAMES } from './LinkEngine'
import { GameTopBar, PrimaryBtn, GhostBtn, ResultOverlay } from '../../components/Common'
import { GameStore } from '../../store/GameStore'
import vibrator from '@ohos.vibrator'

const EMOJIS: string[] = ['🍎', '🍌', '🍇', '🍉', '🍓', '🍒', '🥝', '🍍', '🥥', '🥕',
  '🌽', '🍄', '🐶', '🐱', '🐼', '🐯', '🦁', '🐸', '🐵', '🦊', '🐔', '🦋', '🐙', '🦀']

interface LevelSpec {
  rows: number
  cols: number
  kinds: number
  time: number
  dir: string      // 本关重力方向
}

const LEVELS: LevelSpec[] = [
  { rows: 6, cols: 6, kinds: 8, time: 150, dir: 'none' },
  { rows: 6, cols: 7, kinds: 12, time: 170, dir: 'down' },
  { rows: 7, cols: 8, kinds: 14, time: 200, dir: 'up' },
  { rows: 7, cols: 8, kinds: 16, time: 210, dir: 'left' },
  { rows: 8, cols: 8, kinds: 16, time: 230, dir: 'right' },
  { rows: 8, cols: 8, kinds: 18, time: 250, dir: 'inward' },
  { rows: 9, cols: 8, kinds: 20, time: 270, dir: 'down' },
  { rows: 10, cols: 8, kinds: 22, time: 300, dir: 'inward' },
]

@Component
export struct LinkPage {
  @State ents: TileEnt[] = []          // 牌实体（渲染与动画）
  @State tiles: number[] = []          // 棋盘（连通判定）
  @State level: number = 1
  @State totalSeconds: number = 1
  @State seconds: number = 0
  @State selected: number = -1         // 选中的 cell
  @State hintPair: number[] = []       // 提示的 cell
  @State wrongIdx: number = -1
  @State hintCount: number = 3
  @State shuffleCount: number = 3
  @State bombCount: number = 3
  @State score: number = 0
  @State combo: number = 0
  @State win: boolean = false
  @State over: boolean = false
  @State playing: boolean = false
  @State notice: string = ''
  @State lineSegs: string[] = []
  @State lineDots: number[][] = []
  @State segShow: number = 0
  private pathStack: NavPathStack | null = null
  private timerId: number = -1
  private pathTimers: number[] = []
  private noticeTimerId: number = -1
  private rows: number = 6
  private cols: number = 6
  private dir: string = 'none'
  private lastMatchAt: number = 0
  private nextId: number = 1

  aboutToDisappear(): void {
    this.stopTimers()
  }

  build() {
    NavDestination() {
      Stack() {
        Column({ space: 10 }) {
          GameTopBar({
            title: `连连看 · 第${this.level}关`,
            stat: this.playing ? `${this.score} 分` : '',
            onBack: () => this.quit(),
          })
          if (!this.playing) {
            this.Intro()
          } else {
            this.TimeBar()
            this.Board()
            this.ToolBar()
            Blank()
          }
        }
        .width('100%')
        .height('100%')
        .padding({ left: 10, right: 10, bottom: 10 })

        ResultOverlay({
          visible: this.over,
          win: this.win,
          title: this.win ? `${'⭐'.repeat(this.stars())} 第${this.level}关通过` : '时间到',
          detail: this.win ? `得分 ${this.score + this.seconds * 2} · 剩余 ${this.seconds}s` : `本局 ${this.score} 分`,
          primaryLabel: this.win ? '下一关' : '再来一局',
          secondaryLabel: '返回大厅',
          onPrimary: () => {
            if (this.win) {
              this.startLevel(this.level + 1, this.score + this.seconds * 2)
            } else {
              this.startLevel(1, 0)
            }
          },
          onSecondary: () => this.quit(),
        })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.paper'))
    .onReady((ctx: NavDestinationContext) => {
      this.pathStack = ctx.pathStack
    })
  }

  @Builder
  Intro() {
    Column({ space: 14 }) {
      Image($r('app.media.game_link'))
        .width(110)
        .height(110)
        .borderRadius(26)
        .shadow({ radius: 12, color: 'rgba(36,92,65,0.30)', offsetY: 5 })
      Text('连连看')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
      Text('点选两张相同图案，连线不超过两个弯即消除。\n关卡模式：第 2 关起，每次消除后牌面按本关方向塌落，\n连通关系随时变化——下落、上升、左右移、向中间靠拢。')
        .fontSize(12)
        .fontColor($r('app.color.ink_light'))
        .textAlign(TextAlign.Center)
        .lineHeight(19)
      Text(this.bestText())
        .fontSize(13)
        .fontColor($r('app.color.gold'))
      PrimaryBtn({ label: '开始游戏', onTap: () => this.startLevel(1, 0) })
      Blank()
    }
    .width('100%')
    .layoutWeight(1)
  }

  private bestText(): string {
    const r = GameStore.get('link')
    if (r.playCount === 0) {
      return ''
    }
    return `已到第 ${r.bestLevel} 关 · 最高 ${r.bestScore} 分`
  }

  @Builder
  TimeBar() {
    Column({ space: 4 }) {
      Row() {
        Text(`⏱ ${this.seconds}s`)
          .fontSize(11)
          .fontColor(this.timeRatio() < 0.25 ? $r('app.color.cinnabar') : $r('app.color.ink_light'))
        Blank()
        Text(`${GRAVITY_NAMES[this.dir] ?? '经典'} · 剩 ${remaining(this.tiles) / 2} 对`)
          .fontSize(11)
          .fontColor($r('app.color.gold'))
      }
      .width('100%')
      Stack({ alignContent: Alignment.Start }) {
        Column()
          .width('100%')
          .height(7)
          .borderRadius(4)
          .backgroundColor($r('app.color.wash'))
        Column()
          .width(`${Math.max(0, Math.round(this.timeRatio() * 100))}%`)
          .height(7)
          .borderRadius(4)
          .backgroundColor(this.timeRatio() < 0.25 ? $r('app.color.cinnabar') : $r('app.color.jade_ok'))
          .animation({ duration: 300 })
      }
      .width('100%')
    }
    .width('100%')
  }

  private timeRatio(): number {
    return this.totalSeconds > 0 ? this.seconds / this.totalSeconds : 0
  }

  private cell(): number {
    if (this.cols <= 6) {
      return 48
    }
    if (this.cols === 7) {
      return 42
    }
    return 37
  }

  @Builder
  Board() {
    Column({ space: 6 }) {
      // 经典绿台呢棋盘
      Column() {
        Stack() {
          this.Slots()
          this.Tiles()
          // 连线特效层
          ForEach(this.lineSegs, (seg: string, i: number) => {
            if (i < this.segShow) {
              this.LineSeg(seg, i, 10, 0.26, '#FFD54F')
              this.LineSeg(seg, i, 4.5, 0.97, i === this.lineSegs.length - 1 ? '#FFE082' : '#FFD54F')
            }
          }, (seg: string, i: number) => `seg-${i}-${seg}-${i < this.segShow}`)
          ForEach(this.lineDots, (d: number[], i: number) => {
            if (i <= this.segShow) {
              Circle()
                .width(d[2] > 0 ? 13 : 8)
                .height(d[2] > 0 ? 13 : 8)
                .fill(d[2] > 0 ? '#FFE082' : '#FFD54F')
                .shadow({ radius: 6, color: '#FFD54FAA', offsetY: 0, offsetX: 0 })
                .position({ x: d[0] - (d[2] > 0 ? 6.5 : 4), y: d[1] - (d[2] > 0 ? 6.5 : 4) })
                .hitTestBehavior(HitTestMode.Transparent)
            }
          }, (d: number[], i: number) => `dot-${i}-${d[0]}-${d[1]}-${i <= this.segShow}`)
        }
        .width(this.cols * this.cell())
        .height(this.rows * this.cell())
        .alignContent(Alignment.TopStart)
      }
      .padding(Math.round(this.cell() / 2) + 3)
      .clip(true)
      .borderRadius(14)
      .backgroundColor('#2F6E4F')
      .border({ width: 2, color: '#245C41' })
      .shadow({ radius: 10, color: 'rgba(36,92,65,0.45)', offsetY: 4 })
      if (this.notice !== '') {
        Text(this.notice)
          .fontSize(11)
          .fontColor($r('app.color.gold'))
          .padding({ top: 2 })
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  /** 槽位层（静态暗槽） */
  @Builder
  Slots() {
    Column() {
      ForEach(this.range(this.rows), (r: number) => {
        Row() {
          ForEach(this.range(this.cols), (c: number) => {
            Column()
              .width(this.cell() - 4)
              .height(this.cell() - 4)
              .borderRadius(8)
              .backgroundColor('#245C41')
          }, (c: number) => `slot-${r}-${c}`)
        }
      }, (r: number) => `slotr-${r}`)
    }
    .width(this.cols * this.cell())
    .height(this.rows * this.cell())
    .hitTestBehavior(HitTestMode.None)
  }

  /** 牌层：按实体绝对定位，重力塌落时滑动动画 */
  @Builder
  Tiles() {
    ForEach(this.ents, (e: TileEnt) => {
      this.TileView(e)
    }, (e: TileEnt) => `ent-${e.id}-${e.cell}-${e.kind}-${e.dying ? 'd' : 'a'}-${this.selected === e.cell ? 's' : 'n'}-${this.hintPair.indexOf(e.cell) >= 0 ? 'h' : 'x'}`)
  }

  @Builder
  TileView(e: TileEnt) {
    Stack() {
      if (!e.dying) {
        // 底面
        Column()
          .width(this.cell() - 7)
          .height(this.cell() - 7)
          .borderRadius(8)
          .backgroundColor('#B8AE93')
          .offset({ y: 2 })
        // 象牙牌面 + 高光
        Stack() {
          Column()
            .width('100%')
            .height('100%')
            .borderRadius(8)
            .backgroundColor('#FBF7ED')
          Column()
            .width('100%')
            .height('42%')
            .borderRadius({ topLeft: 8, topRight: 8 })
            .backgroundColor('#FFFFFF99')
        }
        .width(this.cell() - 7)
        .height(this.cell() - 7)
        .offset({ y: this.selected === e.cell ? -3 : 0 })
        .animation({ duration: 130, curve: Curve.FastOutSlowIn })
      }
      // 图案
      Text(EMOJIS[e.kind % EMOJIS.length])
        .fontSize(this.cell() * 0.48)
        .offset({ y: this.selected === e.cell ? -2 : 0 })
        .animation({ duration: 130 })
        .scale(e.dying ? { x: 1.5, y: 1.5 } : { x: 1, y: 1 })
        .opacity(e.dying ? 0 : 1)
        .animation({ duration: 220, curve: Curve.Friction })
      // 选中/提示金环
      if (!e.dying && (this.selected === e.cell || this.hintPair.indexOf(e.cell) >= 0)) {
        Column()
          .width(this.cell() - 2)
          .height(this.cell() - 2)
          .borderRadius(9)
          .border({ width: 2.5, color: '#FFD54F' })
          .shadow({ radius: 6, color: '#FFD54F99', offsetY: 0, offsetX: 0 })
          .hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .width(this.cell())
    .height(this.cell())
    .position({
      x: (e.cell % this.cols) * this.cell(),
      y: Math.floor(e.cell / this.cols) * this.cell(),
    })
    .animation({ duration: 260, curve: Curve.Friction })   // 重力塌落滑动
    .onClick(() => this.tap(e.cell))
  }

  /** 解析 'M x1 y1 L x2 y2' → [x1, y1, x2, y2] */
  private segXY(seg: string): number[] {
    const nums = seg.replace('M', ' ').replace('L', ' ').trim().split(/\s+/)
    return [Number(nums[0]), Number(nums[1]), Number(nums[2]), Number(nums[3])]
  }

  private segLen(seg: string): number {
    const p = this.segXY(seg)
    const dx = p[2] - p[0]
    const dy = p[3] - p[1]
    return Math.sqrt(dx * dx + dy * dy)
  }

  private segDeg(seg: string): number {
    const p = this.segXY(seg)
    return Math.atan2(p[3] - p[1], p[2] - p[0]) * 180 / Math.PI
  }

  @Builder
  LineSeg(seg: string, i: number, thick: number, alpha: number, color: string) {
    Column()
      .width(this.segLen(seg) + thick)
      .height(thick)
      .borderRadius(thick / 2)
      .backgroundColor(color)
      .opacity(alpha)
      .position({ x: this.segXY(seg)[0] - thick / 2, y: this.segXY(seg)[1] - thick / 2 })
      .rotate({ angle: this.segDeg(seg), centerX: thick / 2, centerY: thick / 2 })
      .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  ToolBar() {
    Row({ space: 8 }) {
      GhostBtn({ label: `💡${this.hintCount}`, onTap: () => this.useHint() })
      GhostBtn({ label: `🔀${this.shuffleCount}`, onTap: () => this.useShuffle() })
      GhostBtn({ label: `💣${this.bombCount}`, onTap: () => this.useBomb() })
      Blank()
      if (this.combo >= 2) {
        Text(`连击 ×${this.combo}`)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.cinnabar'))
          .scale({ x: 1 + Math.min(this.combo, 8) * 0.04, y: 1 + Math.min(this.combo, 8) * 0.04 })
          .animation({ duration: 160 })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  private range(n: number): number[] {
    const r: number[] = []
    for (let i = 0; i < n; i++) {
      r.push(i)
    }
    return r
  }

  private spec(): LevelSpec {
    return LEVELS[Math.min(this.level - 1, LEVELS.length - 1)]
  }

  private startLevel(level: number, carryScore: number): void {
    const spec = LEVELS[Math.min(level - 1, LEVELS.length - 1)]
    this.level = level
    this.rows = spec.rows
    this.cols = spec.cols
    this.dir = spec.dir
    this.totalSeconds = spec.time
    this.seconds = spec.time
    this.tiles = makeBoard(spec.rows, spec.cols, spec.kinds, () => Math.random())
    const ents: TileEnt[] = []
    let id = 1
    for (let i = 0; i < this.tiles.length; i++) {
      if (this.tiles[i] >= 0) {
        ents.push({ id: id, cell: i, kind: this.tiles[i], dying: false })
        id++
      }
    }
    this.nextId = id
    this.ents = ents
    this.selected = -1
    this.hintPair = []
    this.wrongIdx = -1
    this.hintCount = 3
    this.shuffleCount = 3
    this.bombCount = 3
    this.combo = 0
    this.lastMatchAt = 0
    this.score = carryScore
    this.notice = ''
    this.segShow = 0
    this.lineSegs = []
    this.lineDots = []
    this.win = false
    this.over = false
    this.playing = true
    GameStore.recordPlay('link')
    this.stopTimers()
    this.timerId = setInterval(() => {
      this.seconds--
      if (this.seconds <= 0) {
        this.fail()
      }
    }, 1000)
  }

  private entAt(cell: number): TileEnt | undefined {
    for (const e of this.ents) {
      if (e.cell === cell && !e.dying) {
        return e
      }
    }
    return undefined
  }

  private tap(cell: number): void {
    if (this.tiles[cell] < 0 || this.over) {
      return
    }
    const ent = this.entAt(cell)
    if (!ent) {
      return
    }
    if (ent.dying) {
      return
    }
    if (this.selected < 0) {
      this.selected = cell
      this.wrongIdx = -1
      return
    }
    if (this.selected === cell) {
      this.selected = -1
      return
    }
    const a = this.selected
    if (this.tiles[a] !== this.tiles[cell]) {
      this.wrongIdx = cell
      setTimeout(() => {
        this.wrongIdx = -1
      }, 260)
      this.selected = cell
      this.combo = 0
      return
    }
    const pa: Pt = { x: a % this.cols, y: Math.floor(a / this.cols) }
    const pb: Pt = { x: cell % this.cols, y: Math.floor(cell / this.cols) }
    const path = findPath(this.tiles, this.rows, this.cols, pa, pb)
    if (path.length === 0) {
      this.wrongIdx = cell
      setTimeout(() => {
        this.wrongIdx = -1
      }, 260)
      this.selected = cell
      this.combo = 0
      return
    }
    this.doMatch(a, cell, path)
  }

  private doMatch(a: number, b: number, path: Pt[]): void {
    const now = Date.now()
    if (now - this.lastMatchAt > 4000) {
      this.combo = 0
    }
    this.lastMatchAt = now
    this.combo++
    this.score += 10 + (this.combo - 1) * 2
    this.selected = -1
    // 标记消散
    const ea = this.entAt(a)
    const eb = this.entAt(b)
    const marked = this.ents.map((e: TileEnt): TileEnt => {
      if ((ea && e.id === ea.id) || (eb && e.id === eb.id)) {
        return { id: e.id, cell: e.cell, kind: e.kind, dying: true }
      }
      return e
    })
    this.ents = marked
    this.showPath(path)
    this.buzz()
    // 消散后：移除 → 重力塌落 → 胜负/死局检测
    setTimeout(() => {
      const nextBoard = this.tiles.slice()
      nextBoard[a] = -1
      nextBoard[b] = -1
      const alive = this.ents.filter((e: TileEnt): boolean => !e.dying)
      // 应用重力
      const after = applyGravity(alive, nextBoard, this.rows, this.cols, this.dir)
      this.ents = after
      this.tiles = nextBoard
      if (remaining(this.tiles) === 0) {
        this.clearLevel()
      } else if (isDead(this.tiles, this.rows, this.cols)) {
        this.autoReshuffle()
      }
    }, 240)
  }

  private showPath(path: Pt[]): void {
    this.clearPathTimers()
    const cs = this.cell()
    const segs: string[] = []
    const dots: number[][] = []
    const pts: number[][] = []
    for (let i = 0; i < path.length; i++) {
      pts.push([Math.round(path[i].x * cs + cs / 2), Math.round(path[i].y * cs + cs / 2)])
      if (i > 0) {
        segs.push(`M${pts[i - 1][0]} ${pts[i - 1][1]} L${pts[i][0]} ${pts[i][1]}`)
      }
    }
    for (let i = 0; i < pts.length; i++) {
      const isEnd = i === 0 || i === pts.length - 1
      dots.push([pts[i][0], pts[i][1], isEnd ? 1 : 0])
    }
    this.lineSegs = segs
    this.lineDots = dots
    this.segShow = 1
    for (let k = 2; k <= segs.length; k++) {
      const kk = k
      this.pathTimers.push(setTimeout(() => {
        this.segShow = kk
      }, (kk - 1) * 65))
    }
    const hold = segs.length * 65 + 300
    this.pathTimers.push(setTimeout(() => {
      this.segShow = 0
      this.lineSegs = []
      this.lineDots = []
    }, hold))
  }

  private clearPathTimers(): void {
    for (const t of this.pathTimers) {
      clearTimeout(t)
    }
    this.pathTimers = []
  }

  private buzz(): void {
    try {
      vibrator.startVibration({ type: 'time', duration: 28 }, { id: 0, usage: 'touch' })
    } catch (e) {
      // 无权限或不支持时静默
    }
  }

  private useHint(): void {
    if (this.hintCount <= 0 || this.over) {
      return
    }
    const pair = findHintPair(this.tiles, this.rows, this.cols)
    if (pair.length === 2) {
      this.hintCount--
      this.selected = -1
      this.hintPair = [pair[0].y * this.cols + pair[0].x, pair[1].y * this.cols + pair[1].x]
      setTimeout(() => {
        this.hintPair = []
      }, 900)
    }
  }

  private useShuffle(): void {
    if (this.shuffleCount <= 0 || this.over) {
      return
    }
    this.shuffleCount--
    this.reshuffleNow('已洗牌')
  }

  /** 炸弹：对选中牌与其同图案搭档直接消除（无需可连） */
  private useBomb(): void {
    if (this.bombCount <= 0 || this.over) {
      return
    }
    const a = this.selected
    if (a < 0 || this.tiles[a] < 0) {
      this.showToast('先点选一张牌，再用炸弹')
      return
    }
    let b = -1
    for (let i = 0; i < this.tiles.length; i++) {
      if (i !== a && this.tiles[i] === this.tiles[a]) {
        b = i
        break
      }
    }
    if (b < 0) {
      return
    }
    this.bombCount--
    this.score += 10
    this.doMatch(a, b, [])
  }

  private autoReshuffle(): void {
    this.reshuffleNow('无可连对，自动洗牌')
  }

  private reshuffleNow(msg: string): void {
    const next = this.tiles.slice()
    reshuffle(next, this.rows, this.cols, () => Math.random())
    this.tiles = next
    // 实体按新棋盘重绑图案（保持位置）
    const ents = this.ents.map((e: TileEnt): TileEnt => {
      return { id: e.id, cell: e.cell, kind: next[e.cell], dying: false }
    })
    this.ents = ents.filter((e: TileEnt): boolean => e.kind >= 0)
    this.selected = -1
    this.showToast(msg)
  }

  private showToast(msg: string): void {
    this.notice = msg
    if (this.noticeTimerId >= 0) {
      clearTimeout(this.noticeTimerId)
    }
    this.noticeTimerId = setTimeout(() => {
      this.notice = ''
    }, 1500)
  }

  private stars(): number {
    const ratio = this.timeRatio()
    if (ratio >= 0.5) {
      return 3
    }
    if (ratio >= 0.25) {
      return 2
    }
    return 1
  }

  private clearLevel(): void {
    this.stopTimers()
    this.score += this.seconds * 2
    this.win = true
    this.over = true
    GameStore.recordScore('link', this.score, this.level)
  }

  private fail(): void {
    this.stopTimers()
    this.win = false
    this.over = true
    GameStore.recordScore('link', this.score, this.level)
  }

  private stopTimers(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
    this.clearPathTimers()
    if (this.noticeTimerId >= 0) {
      clearTimeout(this.noticeTimerId)
      this.noticeTimerId = -1
    }
  }

  private quit(): void {
    this.stopTimers()
    if (this.pathStack) {
      this.pathStack.pop()
    }
  }
}
