/**
 * 连连看 · 产品级
 * 特色：两折路径连线动画 · 牌面设计（底座+图案+高光）· 选中浮起 ·
 *       消除缩放消散 · 连击计分 · 震动反馈 · 时间条 · 提示/洗牌道具 · 星级通关
 */
import { makeBoard, findPath, findHintPair, isDead, reshuffle, remaining, Pt } from './LinkEngine'
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
}

const LEVELS: LevelSpec[] = [
  { rows: 6, cols: 6, kinds: 8, time: 150 },
  { rows: 6, cols: 7, kinds: 12, time: 170 },
  { rows: 7, cols: 8, kinds: 14, time: 200 },
  { rows: 8, cols: 8, kinds: 16, time: 230 },
  { rows: 9, cols: 8, kinds: 18, time: 250 },
  { rows: 10, cols: 8, kinds: 20, time: 280 },
  { rows: 10, cols: 8, kinds: 22, time: 300 },
  { rows: 10, cols: 8, kinds: 24, time: 320 },
]

@Component
export struct LinkPage {
  @State tiles: number[] = []
  @State level: number = 1
  @State totalSeconds: number = 1
  @State seconds: number = 0
  @State selected: number = -1
  @State dying: number[] = []          // 消除动画中的格
  @State hintCount: number = 3
  @State shuffleCount: number = 3
  @State bombCount: number = 3
  @State hintPair: number[] = []
  @State wrongIdx: number = -1
  @State score: number = 0
  @State combo: number = 0
  @State win: boolean = false
  @State over: boolean = false
  @State playing: boolean = false
  @State notice: string = ''
  // 连线特效：逐段生长 + 双层发光 + 端点/拐点金点
  @State lineSegs: string[] = []      // 每段 'M x y L x y'
  @State lineDots: number[][] = []    // 各节点 [x, y, 是否端点(1/0)]
  @State segShow: number = 0          // 已显示段数
  private pathStack: NavPathStack | null = null
  private timerId: number = -1
  private pathTimers: number[] = []
  private noticeTimerId: number = -1
  private rows: number = 6
  private cols: number = 6
  private lastMatchAt: number = 0   // 连击窗口（经典规则：4 秒内连续消除）

  aboutToDisappear(): void {
    this.stopTimers()
  }

  build() {
    NavDestination() {
      Column({ space: 12 }) {
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
      .padding({ left: 16, right: 16, bottom: 10 })
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
        .width(120)
        .height(120)
        .borderRadius(28)
        .shadow({ radius: 12, color: 'rgba(43,38,32,0.18)', offsetY: 5 })
      Text('连连看')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
      Text('点选两张相同图案，连线不超过两个弯即消除。\n连击加分；道具有限，慎用；时间将尽时条会变红。')
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

  /** 时间条 */
  @Builder
  TimeBar() {
    Column({ space: 4 }) {
      Row() {
        Text(`⏱ ${this.seconds}s`)
          .fontSize(11)
          .fontColor(this.timeRatio() < 0.25 ? $r('app.color.cinnabar') : $r('app.color.ink_light'))
        Blank()
        Text(`剩 ${remaining(this.tiles) / 2} 对`)
          .fontSize(11)
          .fontColor($r('app.color.ink_light'))
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
    // 牌宽收敛：保证整板（含页边距）远离左侧系统侧滑返回手势区
    if (this.cols <= 6) {
      return 44
    }
    if (this.cols === 7) {
      return 39
    }
    return 34
  }

  @Builder
  Board() {
    Column({ space: 6 }) {
      // 经典绿台呢棋盘
      Column() {
        Stack() {
          this.Grid()
          // 连线特效层：逐段生长 + 双层发光（旋转矩形拼线，坐标完全确定）
          ForEach(this.lineSegs, (seg: string, i: number) => {
            if (i < this.segShow) {
              this.LineSeg(seg, i, 10, 0.26, '#FFD54F')
              this.LineSeg(seg, i, 4.5, 0.97, i === this.lineSegs.length - 1 ? '#FFE082' : '#FFD54F')
            }
          }, (seg: string, i: number) => `seg-${i}-${seg}-${i < this.segShow}`)
          // 节点金点：端点大、拐点小，随段生长亮起
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
      .padding(Math.round(this.cell() / 2) + 5)
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

  /**
   * 单段连线：定位在起点的圆角矩形，绕起点旋转 atan2 角度。
   * 高度=线宽，宽度=两点距离；双层调用形成光晕+亮芯。
   */
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
  Grid() {
    Column() {
      ForEach(this.range(this.rows), (r: number) => {
        Row() {
          ForEach(this.range(this.cols), (c: number) => {
            this.TileCell(r * this.cols + c)
          }, (c: number) => `tc-${r}-${c}-${this.tiles[r * this.cols + c]}-${this.dying.indexOf(r * this.cols + c) >= 0 ? 'd' : 'a'}-${this.selected === r * this.cols + c ? 's' : 'n'}`)
        }
      }, (r: number) => `tr-${r}`)
    }
    .width(this.cols * this.cell())
    .height(this.rows * this.cell())
  }

  /**
   * 牌格（经典样式）：固定尺寸 Stack。绿呢暗槽 + 象牙白 3D 小牌（上亮边）+
   * 居中图案；选中金环/消散/✕ 全为叠加层，绝不改变布局尺寸。
   */
  @Builder
  TileCell(idx: number) {
    Stack() {
      // 槽位（台呢上的凹槽，命中区域恒定）
      Column()
        .width(this.cell() - 4)
        .height(this.cell() - 4)
        .borderRadius(8)
        .backgroundColor('#245C41')
      // 象牙牌：底面（侧影）
      if (this.tiles[idx] >= 0 && this.dying.indexOf(idx) < 0) {
        Column()
          .width(this.cell() - 7)
          .height(this.cell() - 7)
          .borderRadius(8)
          .backgroundColor('#B8AE93')
          .offset({ y: 2 })
      }
      // 象牙牌：牌面 + 顶部高光（3D 斜边）
      if (this.tiles[idx] >= 0 && this.dying.indexOf(idx) < 0) {
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
        .offset({ y: this.selected === idx ? -3 : 0 })
        .animation({ duration: 130, curve: Curve.FastOutSlowIn })
      }
      // 图案（存活居中；消散时放大淡出）
      if (this.tiles[idx] >= 0) {
        Text(EMOJIS[this.tiles[idx] % EMOJIS.length])
          .fontSize(this.cell() * 0.48)
          .offset({ y: this.selected === idx ? -2 : 0 })
          .animation({ duration: 130 })
          .scale(this.dying.indexOf(idx) >= 0 ? { x: 1.5, y: 1.5 } : { x: 1, y: 1 })
          .opacity(this.dying.indexOf(idx) >= 0 ? 0 : 1)
          .animation({ duration: 220, curve: Curve.Friction })
      }
      // 选中/提示：金色发光描边（叠加层）
      if (this.selected === idx || this.hintPair.indexOf(idx) >= 0) {
        Column()
          .width(this.cell() - 2)
          .height(this.cell() - 2)
          .borderRadius(9)
          .border({ width: 2.5, color: '#FFD54F' })
          .shadow({ radius: 6, color: '#FFD54F99', offsetY: 0, offsetX: 0 })
          .hitTestBehavior(HitTestMode.Transparent)
      }
      // 不可连/错误反馈（叠加层）
      if (this.wrongIdx === idx) {
        Text('✕')
          .fontSize(this.cell() * 0.42)
          .fontWeight(FontWeight.Bold)
          .fontColor('#E74C3C')
          .opacity(0.92)
      }
    }
    .width(this.cell())
    .height(this.cell())
    .onClick(() => this.tap(idx))
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
    this.totalSeconds = spec.time
    this.seconds = spec.time
    this.tiles = makeBoard(spec.rows, spec.cols, spec.kinds, () => Math.random())
    this.selected = -1
    this.dying = []
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

  private tap(idx: number): void {
    if (this.tiles[idx] < 0 || this.over) {
      return
    }
    // 消除动画期间：仅封锁正在消散的两张牌，其余照常可点
    if (this.dying.indexOf(idx) >= 0) {
      return
    }
    if (this.selected < 0) {
      this.selected = idx
      this.wrongIdx = -1
      return
    }
    if (this.selected === idx) {
      this.selected = -1
      return
    }
    const a = this.selected
    if (this.tiles[a] !== this.tiles[idx]) {
      // 不同图案：切换选中并给出错误反馈
      this.wrongIdx = idx
      setTimeout(() => {
        this.wrongIdx = -1
      }, 260)
      this.selected = idx
      this.combo = 0
      return
    }
    const pa: Pt = { x: a % this.cols, y: Math.floor(a / this.cols) }
    const pb: Pt = { x: idx % this.cols, y: Math.floor(idx / this.cols) }
    const path = findPath(this.tiles, this.rows, this.cols, pa, pb)
    if (path.length === 0) {
      // 不可连：提示
      this.wrongIdx = idx
      setTimeout(() => {
        this.wrongIdx = -1
      }, 260)
      this.selected = idx
      this.combo = 0
      return
    }
    this.doMatch(a, idx, path)
  }

  private doMatch(a: number, b: number, path: Pt[]): void {
    // 经典连击规则：距上次消除超过 4 秒则重新计数
    const now = Date.now()
    if (now - this.lastMatchAt > 4000) {
      this.combo = 0
    }
    this.lastMatchAt = now
    this.combo++
    this.score += 10 + (this.combo - 1) * 2
    this.selected = -1
    this.dying = [a, b]
    if (path.length > 0) {
      this.showPath(path)
    }
    this.buzz()
    setTimeout(() => {
      const next = this.tiles.slice()
      next[a] = -1
      next[b] = -1
      this.tiles = next
      this.dying = []
      if (remaining(this.tiles) === 0) {
        this.clearLevel()
      } else if (isDead(this.tiles, this.rows, this.cols)) {
        this.autoReshuffle()
      }
    }, 220)
  }

  /** 炸弹道具（经典三件套之一）：对选中牌与其同图案搭档直接消除，无需连线 */
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
    // 无路径直接消除（不触发连击加成，基础分 10）
    this.score += 10
    this.selected = -1
    this.dying = [a, b]
    this.buzz()
    setTimeout(() => {
      const next = this.tiles.slice()
      next[a] = -1
      next[b] = -1
      this.tiles = next
      this.dying = []
      if (remaining(this.tiles) === 0) {
        this.clearLevel()
      } else if (isDead(this.tiles, this.rows, this.cols)) {
        this.autoReshuffle()
      }
    }, 220)
  }

  private showToast(msg: string): void {
    this.notice = msg
    if (this.noticeTimerId >= 0) {
      clearTimeout(this.noticeTimerId)
    }
    this.noticeTimerId = setTimeout(() => {
      this.notice = ''
    }, 1400)
  }

  /**
   * 连线特效：格点 → 分段命令 + 节点金点，逐段生长显示后整体消隐。
   * 每段 65ms 生长，全程显示 ~360ms。
   */
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
    // 逐段生长
    for (let k = 2; k <= segs.length; k++) {
      const kk = k
      this.pathTimers.push(setTimeout(() => {
        this.segShow = kk
      }, (kk - 1) * 65))
    }
    // 全程展示后消隐
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

  private autoReshuffle(): void {
    this.reshuffleNow('无可连对，自动洗牌')
  }

  private reshuffleNow(msg: string): void {
    const next = this.tiles.slice()
    reshuffle(next, this.rows, this.cols, () => Math.random())
    this.tiles = next
    this.selected = -1
    this.notice = msg
    if (this.noticeTimerId >= 0) {
      clearTimeout(this.noticeTimerId)
    }
    this.noticeTimerId = setTimeout(() => {
      this.notice = ''
    }, 1600)
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
