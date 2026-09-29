/**
 * 数织页：行列线索推理 / 填与标两态 / 完成行线索置灰
 */
import { NonogramPuzzle, makeNonogram, lineMatches } from './NonogramEngine'
import { GameTopBar, PrimaryBtn, GhostBtn, ResultOverlay, Tag } from '../../components/Common'
import { GameStore } from '../../store/GameStore'

@Component
export struct NonogramPage {
  @State puzzle: NonogramPuzzle | null = null
  @State cells: number[] = []        // 0未知 1填 2标空
  @State mode: number = 1            // 1填 2标
  @State level: number = 1
  @State mistakes: number = 0
  @State over: boolean = false
  @State playing: boolean = false
  @State generating: boolean = false
  private pathStack: NavPathStack | null = null

  build() {
    NavDestination() {
      Column({ space: 12 }) {
        GameTopBar({
          title: `数织 · 第${this.level}关`,
          stat: this.playing ? (this.gridSize() === 5 ? '5×5' : '10×10') : '',
          onBack: () => this.quit(),
        })
        if (!this.playing) {
          Column({ space: 14 }) {
            Text('🖼️')
              .fontSize(46)
            Text('数织')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
            Text('按行列数字推理：数字表示该行/列连续涂黑段的长度；\n双模式点格：✏️涂黑 / ❌标空；全部吻合即还原像素画。\n所有谜题经行解法器校验，可纯逻辑推出。')
              .fontSize(12)
              .fontColor($r('app.color.ink_light'))
              .textAlign(TextAlign.Center)
              .lineHeight(19)
            if (this.generating) {
              Text('生成中…')
                .fontSize(12)
                .fontColor($r('app.color.gold'))
            } else {
              PrimaryBtn({ label: '开始第 1 关', onTap: () => this.startLevel(1) })
            }
            Blank()
          }
          .width('100%')
          .layoutWeight(1)
        } else {
          this.PuzzleView()
          Row({ space: 10 }) {
            Tag({ label: `第${this.level}关`, tone: 'red' })
            Text(this.mode === 1 ? '✏️ 涂黑中' : '❌ 标空中')
              .fontSize(12)
              .fontColor(this.mode === 1 ? Color.White : $r('app.color.ink'))
              .padding({ left: 14, right: 14, top: 7, bottom: 7 })
              .borderRadius(10)
              .backgroundColor(this.mode === 1 ? $r('app.color.cinnabar') : $r('app.color.wash'))
              .onClick(() => {
                this.mode = this.mode === 1 ? 2 : 1
              })
            GhostBtn({ label: '换一题', onTap: () => this.startLevel(this.level) })
            Blank()
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          Blank()
        }
        ResultOverlay({
          visible: this.over,
          win: true,
          title: '还原成功！',
          detail: `第${this.level}关 · 标空修正 ${this.mistakes} 次`,
          primaryLabel: '下一关',
          secondaryLabel: '返回大厅',
          onPrimary: () => this.startLevel(this.level + 1),
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

  private gridSize(): number {
    return this.puzzle ? this.puzzle.size : 5
  }

  private cellPx(): number {
    return this.gridSize() === 5 ? 46 : 26
  }

  @Builder
  PuzzleView() {
    if (this.puzzle) {
      Column({ space: 2 }) {
        // 顶部列线索
        Row({ space: 2 }) {
          Column().width(this.clueW()).height(this.clueH())
          ForEach(this.puzzle.colClues, (clue: number[], c: number) => {
            Column({ space: 1 }) {
              ForEach(clue, (v: number) => {
                Text(v === 0 ? '·' : v.toString())
                  .fontSize(this.gridSize() === 5 ? 13 : 10)
                  .fontColor(this.colDone(c) ? $r('app.color.ink_faint') : $r('app.color.ink'))
                  .fontWeight(this.colDone(c) ? FontWeight.Normal : FontWeight.Medium)
              }, (v: number) => `cc-${c}-${v}-${this.colDone(c)}`)
            }
            .justifyContent(FlexAlign.End)
            .width(this.cellPx())
            .height(this.clueH())
          }, (clue: number[], c: number) => `colc-${c}-${this.colDone(c)}`)
        }
        .alignItems(VerticalAlign.Bottom)
        // 行
        ForEach(this.range(this.gridSize()), (r: number) => {
          Row({ space: 2 }) {
            Row({ space: 3 }) {
              ForEach(this.puzzle!.rowClues[r], (v: number) => {
                Text(v === 0 ? '·' : v.toString())
                  .fontSize(this.gridSize() === 5 ? 13 : 10)
                  .fontColor(this.rowDone(r) ? $r('app.color.ink_faint') : $r('app.color.ink'))
                  .fontWeight(this.rowDone(r) ? FontWeight.Normal : FontWeight.Medium)
              }, (v: number) => `rc-${r}-${v}-${this.rowDone(r)}`)
            }
            .justifyContent(FlexAlign.End)
            .width(this.clueW())
            .height(this.cellPx())
            ForEach(this.range(this.gridSize()), (c: number) => {
              this.CellView(r * this.gridSize() + c)
            }, (c: number) => `nc-${r}-${c}-${this.cells[r * this.gridSize() + c]}`)
          }
          .alignItems(VerticalAlign.Center)
        }, (r: number) => `nr-${r}-${this.rowDone(r)}`)
      }
    }
  }

  @Builder
  CellView(idx: number) {
    Column()
      .width(this.cellPx() - 2)
      .height(this.cellPx() - 2)
      .borderRadius(4)
      .backgroundColor(this.cells[idx] === 1 ? $r('app.color.ink') : $r('app.color.wash'))
      .border({ width: 0.5, color: $r('app.color.divider') })
      .onClick(() => this.tapCell(idx))
  }

  private clueW(): number {
    return this.gridSize() === 5 ? 52 : 40
  }

  private clueH(): number {
    return this.gridSize() === 5 ? 52 : 40
  }

  private tapCell(idx: number): void {
    if (this.over) {
      return
    }
    const next = this.cells.slice()
    next[idx] = next[idx] === this.mode ? 0 : this.mode
    this.cells = next
    if (this.mode === 1 && next[idx] === 1 && this.puzzle) {
      // 涂黑即时校验：错误直接标红并计失误
      if (this.puzzle.solution[idx] !== 1) {
        this.mistakes++
      }
    }
    this.checkWin()
  }

  private rowDone(r: number): boolean {
    if (!this.puzzle) {
      return false
    }
    const cells: number[] = []
    for (let c = 0; c < this.gridSize(); c++) {
      cells.push(this.cells[r * this.gridSize() + c])
    }
    return lineMatches(cells, this.puzzle.rowClues[r])
  }

  private colDone(c: number): boolean {
    if (!this.puzzle) {
      return false
    }
    const cells: number[] = []
    for (let r = 0; r < this.gridSize(); r++) {
      cells.push(this.cells[r * this.gridSize() + c])
    }
    return lineMatches(cells, this.puzzle.colClues[c])
  }

  private checkWin(): void {
    if (!this.puzzle) {
      return
    }
    for (let i = 0; i < this.puzzle.solution.length; i++) {
      const filled = this.cells[i] === 1 ? 1 : 0
      if (filled !== this.puzzle.solution[i]) {
        return
      }
    }
    this.over = true
    GameStore.recordScore('nonogram', this.level * 100 - this.mistakes, this.level)
    GameStore.recordPlay('nonogram')
  }

  private range(n: number): number[] {
    const r: number[] = []
    for (let i = 0; i < n; i++) {
      r.push(i)
    }
    return r
  }

  private startLevel(n: number): void {
    this.generating = true
    setTimeout(() => {
      const size = n <= 2 ? 5 : 10
      const p = makeNonogram(size, () => Math.random(), 40)
      if (p) {
        this.puzzle = p
        this.cells = new Array(size * size).fill(0)
        this.level = n
        this.mistakes = 0
        this.over = false
        this.playing = true
        GameStore.recordPlay('nonogram')
      }
      this.generating = false
    }, 50)
  }

  private quit(): void {
    if (this.pathStack) {
      this.pathStack.pop()
    }
  }
}
