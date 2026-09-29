/**
 * 连连看页：关卡递增 / 两折连通动画 / 提示与洗牌道具 / 倒计时
 */
import { makeBoard, findPath, findHintPair, isDead, reshuffle, remaining, Pt } from './LinkEngine'
import { GameTopBar, PrimaryBtn, ResultOverlay, Tag } from '../../components/Common'
import { GameStore } from '../../store/GameStore'

const EMOJIS: string[] = ['🀄', '🍎', '🍌', '🍇', '🍉', '🍓', '🍒', '🥝', '🍍', '🥕', '🌽', '🍄',
  '🐶', '🐱', '🐼', '🐯', '🦁', '🐸', '🐵', '🦄', '🐔', '🦋', '🐙', '🦀']

interface LevelSpec {
  rows: number
  cols: number
  kinds: number
  time: number
}

const LEVELS: LevelSpec[] = [
  { rows: 6, cols: 6, kinds: 10, time: 150 },
  { rows: 6, cols: 7, kinds: 14, time: 180 },
  { rows: 7, cols: 8, kinds: 18, time: 210 },
  { rows: 8, cols: 8, kinds: 22, time: 240 },
  { rows: 9, cols: 8, kinds: 24, time: 260 },
  { rows: 10, cols: 8, kinds: 24, time: 300 },
]

@Component
export struct LinkPage {
  @State tiles: number[] = []
  @State level: number = 1
  @State selected: number = -1
  @State pathCmds: string = ''
  @State flashPair: number[] = []
  @State seconds: number = 0
  @State hintCount: number = 3
  @State shuffleCount: number = 3
  @State score: number = 0
  @State win: boolean = false
  @State over: boolean = false
  @State playing: boolean = false
  private pathStack: NavPathStack | null = null
  private timerId: number = -1
  private pathTimerId: number = -1
  private rows: number = 6
  private cols: number = 6

  aboutToDisappear(): void {
    this.stopTimers()
  }

  build() {
    NavDestination() {
      Column({ space: 12 }) {
        GameTopBar({
          title: `连连看 · 第${this.level}关`,
          stat: this.playing ? `⏱${this.seconds}  剩${remaining(this.tiles)}` : '',
          onBack: () => this.quit(),
        })
        if (!this.playing) {
          Column({ space: 14 }) {
            Text('🔗')
              .fontSize(46)
            Text('连连看')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
            Text('点选两张相同图案，连线不超过两个弯即可消除；\n消除全部过关，道具有限慎用。')
              .fontSize(12)
              .fontColor($r('app.color.ink_light'))
              .textAlign(TextAlign.Center)
              .lineHeight(19)
            PrimaryBtn({ label: '开始游戏', onTap: () => this.startLevel(1, 0) })
            Blank()
          }
          .width('100%')
          .layoutWeight(1)
        } else {
          this.Board()
          this.ToolBar()
          Blank()
        }
        ResultOverlay({
          visible: this.over,
          win: this.win,
          title: this.win ? `第${this.level}关通过！` : '时间到',
          detail: this.win ? `当前 ${this.score + this.seconds} 分` : `消除了 ${this.score} 分`,
          primaryLabel: this.win ? '下一关' : '再来一局',
          secondaryLabel: '返回大厅',
          onPrimary: () => {
            if (this.win) {
              this.startLevel(this.level + 1, this.score)
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
  Board() {
    Column() {
      ForEach(this.range(this.rows), (r: number) => {
        Row() {
          ForEach(this.range(this.cols), (c: number) => {
            this.TileCell(r * this.cols + c)
          }, (c: number) => `tc-${r}-${c}-${this.tiles[r * this.cols + c]}`)
        }
      }, (r: number) => `tr-${r}-${r}`)
    }
    .width('100%')
  }

  @Builder
  TileCell(idx: number) {
    Column() {
      if (this.tiles[idx] >= 0) {
        Text(EMOJIS[this.tiles[idx] % EMOJIS.length])
          .fontSize(this.cellSize() * 0.52)
          .scale(this.flashPair.indexOf(idx) >= 0 ? { x: 1.25, y: 1.25 } : { x: 1, y: 1 })
          .opacity(this.flashPair.indexOf(idx) >= 0 ? 0.4 : 1)
          .animation({ duration: 180 })
      }
    }
    .justifyContent(FlexAlign.Center)
    .width(this.cellSize())
    .height(this.cellSize())
    .margin(1.5)
    .backgroundColor(this.selected === idx ? $r('app.color.gold') : $r('app.color.card'))
    .borderRadius(10)
    .border({
      width: this.selected === idx ? 2 : 1,
      color: this.selected === idx ? $r('app.color.cinnabar') : $r('app.color.divider'),
    })
    .onClick(() => this.tap(idx))
  }

  @Builder
  ToolBar() {
    Row({ space: 10 }) {
      Tag({ label: `第${this.level}关`, tone: 'red' })
      Text(`💡提示 ×${this.hintCount}`)
        .fontSize(12)
        .fontColor($r('app.color.ink'))
        .padding({ left: 12, right: 12, top: 7, bottom: 7 })
        .backgroundColor($r('app.color.wash'))
        .borderRadius(10)
        .onClick(() => this.useHint())
      Text(`🔀洗牌 ×${this.shuffleCount}`)
        .fontSize(12)
        .fontColor($r('app.color.ink'))
        .padding({ left: 12, right: 12, top: 7, bottom: 7 })
        .backgroundColor($r('app.color.wash'))
        .borderRadius(10)
        .onClick(() => this.useShuffle())
      Blank()
      Text(`连击 ${this.combo}`)
        .fontSize(12)
        .fontColor($r('app.color.gold'))
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @State combo: number = 0

  private range(n: number): number[] {
    const r: number[] = []
    for (let i = 0; i < n; i++) {
      r.push(i)
    }
    return r
  }

  private cellSize(): number {
    const total = 360 - 32
    const s = Math.floor(total / this.cols) - 3
    return Math.min(48, s)
  }

  private spec(): LevelSpec {
    return LEVELS[Math.min(this.level - 1, LEVELS.length - 1)]
  }

  private startLevel(level: number, carryScore: number): void {
    const spec = LEVELS[Math.min(level - 1, LEVELS.length - 1)]
    this.level = level
    this.rows = spec.rows
    this.cols = spec.cols
    this.tiles = makeBoard(spec.rows, spec.cols, spec.kinds, () => Math.random())
    this.selected = -1
    this.pathCmds = ''
    this.flashPair = []
    this.seconds = spec.time
    this.hintCount = 3
    this.shuffleCount = 3
    this.combo = 0
    this.score = carryScore
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
    if (this.selected < 0) {
      this.selected = idx
      return
    }
    if (this.selected === idx) {
      this.selected = -1
      return
    }
    const a = this.selected
    if (this.tiles[a] !== this.tiles[idx]) {
      this.selected = idx
      this.combo = 0
      return
    }
    const pa: Pt = { x: a % this.cols, y: Math.floor(a / this.cols) }
    const pb: Pt = { x: idx % this.cols, y: Math.floor(idx / this.cols) }
    const path = findPath(this.tiles, this.rows, this.cols, pa, pb)
    if (path.length === 0) {
      this.selected = idx
      return
    }
    // 消除
    const next = this.tiles.slice()
    next[a] = -1
    next[idx] = -1
    this.tiles = next
    this.selected = -1
    this.combo++
    this.score += 10 + (this.combo - 1) * 2
    this.showPath(path)
    this.flashPair = [a, idx]
    setTimeout(() => {
      this.flashPair = []
    }, 240)
    if (remaining(this.tiles) === 0) {
      this.clearLevel()
    } else if (isDead(this.tiles, this.rows, this.cols)) {
      this.reshuffleNow()
    }
  }

  /** 展示连线（把格坐标转成路径命令，叠层 Path 无法便捷叠加在网格上，用闪光替代） */
  private showPath(_path: Pt[]): void {
    // v1 以闪光反馈替代线绘制
  }

  private useHint(): void {
    if (this.hintCount <= 0 || this.over) {
      return
    }
    const pair = findHintPair(this.tiles, this.rows, this.cols)
    if (pair.length === 2) {
      this.hintCount--
      this.selected = -1
      const idxA = pair[0].y * this.cols + pair[0].x
      this.flashPair = [idxA, pair[1].y * this.cols + pair[1].x]
      setTimeout(() => {
        this.flashPair = []
      }, 600)
    }
  }

  private useShuffle(): void {
    if (this.shuffleCount <= 0 || this.over) {
      return
    }
    this.shuffleCount--
    this.reshuffleNow()
  }

  private reshuffleNow(): void {
    const next = this.tiles.slice()
    reshuffle(next, this.rows, this.cols, () => Math.random())
    this.tiles = next
    this.selected = -1
  }

  private clearLevel(): void {
    this.stopTimers()
    this.score += this.seconds   // 时间奖励
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
    if (this.pathTimerId >= 0) {
      clearTimeout(this.pathTimerId)
      this.pathTimerId = -1
    }
  }

  private quit(): void {
    this.stopTimers()
    if (this.pathStack) {
      this.pathStack.pop()
    }
  }
}
