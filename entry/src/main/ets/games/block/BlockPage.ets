/**
 * 方块消除页：8×8 盘 / 点选方块再点盘放置 / 消除动画 / 死局判定
 */
import { Piece, newGrid, canPlace, place, fullLines, clearLines, scoreFor, anyPlaceable, randomPieces, SIZE } from './BlockEngine'
import { GameTopBar, PrimaryBtn, ResultOverlay, Tag } from '../../components/Common'
import { GameStore } from '../../store/GameStore'

@Component
export struct BlockPage {
  @State grid: number[] = newGrid()
  @State queue: (Piece | null)[] = []
  @State selected: number = -1          // 队列下标
  @State score: number = 0
  @State combo: number = 0
  @State over: boolean = false
  @State playing: boolean = false
  @State clearing: number[] = []        // 消除中的格
  private pathStack: NavPathStack | null = null

  build() {
    NavDestination() {
      Column({ space: 12 }) {
        GameTopBar({
          title: '方块消除',
          stat: this.playing ? `${this.score} 分` : '',
          onBack: () => this.quit(),
        })
        if (!this.playing) {
          Column({ space: 14 }) {
            Text('🧱')
              .fontSize(46)
            Text('方块消除')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
            Text('点选下方方块，再点棋盘放置（点击位置为其左上角）；\n填满整行或整列即消除，连续消除有连击加成；\n三个方块都无处可放则结束。')
              .fontSize(12)
              .fontColor($r('app.color.ink_light'))
              .textAlign(TextAlign.Center)
              .lineHeight(19)
            Text(`历史最佳：${this.bestOf()} 分`)
              .fontSize(13)
              .fontColor($r('app.color.gold'))
            PrimaryBtn({ label: '开始游戏', onTap: () => this.start() })
            Blank()
          }
          .width('100%')
          .layoutWeight(1)
        } else {
          this.Board()
          this.Queue()
          Blank()
        }
        ResultOverlay({
          visible: this.over,
          win: false,
          title: '无处可放',
          detail: `本局 ${this.score} 分 · 最佳 ${Math.max(this.bestOf(), this.score)} 分`,
          primaryLabel: '再来一局',
          secondaryLabel: '返回大厅',
          onPrimary: () => this.start(),
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

  private bestOf(): number {
    return GameStore.get('block').bestScore
  }

  private cell(): number {
    return 41
  }

  @Builder
  Board() {
    Column() {
      ForEach(this.range(SIZE), (r: number) => {
        Row() {
          ForEach(this.range(SIZE), (c: number) => {
            this.BoardCell(r * SIZE + c)
          }, (c: number) => `bc-${r}-${c}-${this.grid[r * SIZE + c]}`)
        }
      }, (r: number) => `br-${r}`)
    }
    .backgroundColor($r('app.color.divider'))
    .borderRadius(10)
  }

  @Builder
  BoardCell(idx: number) {
    Column()
      .width(this.cell() - 2)
      .height(this.cell() - 2)
      .margin(1)
      .borderRadius(6)
      .backgroundColor(this.cellBg(idx))
      .animation({ duration: 180 })
      .onClick(() => this.tapCell(idx))
  }

  private cellBg(idx: number): ResourceColor {
    if (this.clearing.indexOf(idx) >= 0) {
      return $r('app.color.gold')
    }
    if (this.grid[idx] === 1) {
      return '#7A9BB5'
    }
    return $r('app.color.wash')
  }

  @Builder
  Queue() {
    Row({ space: 14 }) {
      ForEach(this.queue, (p: Piece | null, i: number) => {
        Column({ space: 4 }) {
          if (p) {
            this.PieceView(p)
          } else {
            Text('—')
              .fontSize(18)
              .fontColor($r('app.color.ink_faint'))
          }
        }
        .padding(8)
        .borderRadius(12)
        .border({
          width: this.selected === i ? 2 : 1,
          color: this.selected === i ? $r('app.color.cinnabar') : $r('app.color.divider'),
        })
        .backgroundColor(this.selected === i ? $r('app.color.wash') : Color.Transparent)
        .onClick(() => {
          if (p) {
            this.selected = this.selected === i ? -1 : i
          }
        })
      }, (p: Piece | null, i: number) => `q-${i}-${p ? p.name : 'none'}`)
      Blank()
      Tag({ label: `连击 ×${this.combo}`, tone: 'gold' })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  PieceView(p: Piece) {
    Column({ space: 1 }) {
      ForEach(this.range(p.h), (r: number) => {
        Row({ space: 1 }) {
          ForEach(this.range(p.w), (c: number) => {
            Stack() {
              if (p.cells.indexOf(r * 10 + c) >= 0) {
                Column()
                  .width(11)
                  .height(11)
                  .borderRadius(3)
                  .backgroundColor('#7A9BB5')
              } else {
                Column().width(11).height(11)
              }
            }
          }, (c: number) => `pc-${r}-${c}`)
        }
      }, (r: number) => `pr-${r}`)
    }
  }

  private range(n: number): number[] {
    const r: number[] = []
    for (let i = 0; i < n; i++) {
      r.push(i)
    }
    return r
  }

  private tapCell(idx: number): void {
    if (this.over || this.selected < 0) {
      return
    }
    const piece = this.queue[this.selected]
    if (!piece) {
      return
    }
    const r = Math.floor(idx / SIZE)
    const c = idx % SIZE
    if (!canPlace(this.grid, piece, r, c)) {
      return
    }
    let grid = place(this.grid, piece, r, c)
    const lines = fullLines(grid)
    const lineCount = lines[0].length + lines[1].length
    this.score += scoreFor(piece.cells.length, lineCount, lineCount > 0 ? this.combo : 0)
    if (lineCount > 0) {
      this.combo++
    } else {
      this.combo = 0
    }
    const q = this.queue.slice()
    q[this.selected] = null
    this.queue = q
    this.selected = -1
    if (lineCount > 0) {
      const clearedSet: number[] = []
      for (const rr of lines[0]) {
        for (let cc = 0; cc < SIZE; cc++) {
          clearedSet.push(rr * SIZE + cc)
        }
      }
      for (const cc of lines[1]) {
        for (let rr = 0; rr < SIZE; rr++) {
          clearedSet.push(rr * SIZE + cc)
        }
      }
      this.grid = grid
      this.clearing = clearedSet
      setTimeout(() => {
        grid = clearLines(grid, lines[0], lines[1])
        this.grid = grid
        this.clearing = []
        this.afterMove()
      }, 200)
    } else {
      this.grid = grid
      this.afterMove()
    }
  }

  private afterMove(): void {
    if (this.queue.every((p: Piece | null) => p === null)) {
      this.queue = randomPieces(3)
    }
    if (!anyPlaceable(this.grid, this.queue)) {
      this.over = true
      GameStore.recordScore('block', this.score)
    }
  }

  private start(): void {
    this.grid = newGrid()
    this.queue = randomPieces(3)
    this.selected = -1
    this.score = 0
    this.combo = 0
    this.clearing = []
    this.over = false
    this.playing = true
    GameStore.recordPlay('block')
  }

  private quit(): void {
    if (this.pathStack) {
      this.pathStack.pop()
    }
  }
}
