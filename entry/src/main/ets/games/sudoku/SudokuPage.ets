/**
 * 数独页：四档难度 / 每日一题 / 笔记 / 提示 / 计时 / 冲突高亮
 */
import { makePuzzle, cluesOfDifficulty, DIFF_NAMES, cellConflicts, Rand, SudokuPuzzle } from './SudokuEngine'
import { GameTopBar, PrimaryBtn, GhostBtn, ResultOverlay, Tag } from '../../components/Common'
import { GameStore } from '../../store/GameStore'

const PAD: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9]

@Component
export struct SudokuPage {
  @State puzzle: number[] = []
  @State solution: number[] = []
  @State values: number[] = []        // 当前盘面（含用户填写）
  @State given: boolean[] = []        // 是否题面给定
  @State notes: string[] = []         // 每格笔记 "1359"
  @State selected: number = -1
  @State pencil: boolean = false
  @State mistakes: number = 0
  @State seconds: number = 0
  @State diff: number = 1
  @State mode: string = 'normal'      // normal | daily
  @State finished: boolean = false
  @State showSetup: boolean = true
  @State generating: boolean = false
  private pathStack: NavPathStack | null = null
  private timerId: number = -1

  aboutToDisappear(): void {
    this.stopTimer()
  }

  build() {
    NavDestination() {
      Column({ space: 12 }) {
        GameTopBar({
          title: this.mode === 'daily' ? '数独 · 每日一题' : '数独',
          stat: this.showSetup ? '' : `${this.mmss()}`,
          onBack: () => this.quit(),
        })
        if (this.showSetup) {
          this.Setup()
        } else {
          this.Board()
          this.Stats()
          this.Pad()
          Blank()
        }
        ResultOverlay({
          visible: this.finished,
          win: true,
          title: '完成！',
          detail: `${DIFF_NAMES[this.diff]} · 用时 ${this.mmss()} · 失误 ${this.mistakes} 次`,
          primaryLabel: '再来一局',
          secondaryLabel: '返回大厅',
          onPrimary: () => this.start(this.diff, this.mode),
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
  Setup() {
    Column({ space: 14 }) {
      Column({ space: 10 }) {
        Text('每日一题')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text('按日期固定，全球同题')
          .fontSize(11)
          .fontColor($r('app.color.ink_light'))
        GhostBtn({ label: '开始今日题', onTap: () => this.start(2, 'daily') })
      }
      .width('100%')
      .padding(18)
      .backgroundColor($r('app.color.card'))
      .borderRadius(18)
      .border({ width: 1, color: $r('app.color.divider') })

      Column({ space: 12 }) {
        Text('自由挑战')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Row({ space: 8 }) {
          ForEach(DIFF_NAMES, (n: string, i: number) => {
            Text(n)
              .fontSize(13)
              .fontColor(this.diff === i ? Color.White : $r('app.color.ink_light'))
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .borderRadius(11)
              .backgroundColor(this.diff === i ? $r('app.color.cinnabar') : $r('app.color.wash'))
              .onClick(() => {
                this.diff = i
              })
          }, (n: string) => `d-${n}`)
        }
        if (this.generating) {
          Text('生成中…（唯一解校验需要一点时间）')
            .fontSize(11)
            .fontColor($r('app.color.gold'))
        } else {
          PrimaryBtn({ label: '开始', onTap: () => this.start(this.diff, 'normal') })
        }
      }
      .width('100%')
      .padding(18)
      .backgroundColor($r('app.color.card'))
      .borderRadius(18)
      .border({ width: 1, color: $r('app.color.divider') })
      Blank()
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  Board() {
    Column() {
      ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8], (r: number) => {
        Row() {
          ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8], (c: number) => {
            this.Cell(r * 9 + c)
          }, (c: number) => `c-${r}-${c}-${this.values[r * 9 + c]}-${this.notes[r * 9 + c] ?? ''}`)
        }
      }, (r: number) => `r-${r}`)
    }
    .backgroundColor($r('app.color.divider'))
    .borderRadius(8)
  }

  @Builder
  Cell(idx: number) {
    Column() {
      if (this.values[idx] > 0) {
        Text(this.values[idx].toString())
          .fontSize(19)
          .fontWeight(this.given[idx] ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.isConflict(idx) ? $r('app.color.cinnabar')
            : (this.given[idx] ? $r('app.color.ink') : $r('app.color.jade_ok')))
      } else if (this.notes[idx] !== '') {
        Text(this.notes[idx].split('').join(' '))
          .fontSize(8)
          .fontColor($r('app.color.ink_light'))
          .textAlign(TextAlign.Center)
      }
    }
    .justifyContent(FlexAlign.Center)
    .width(this.cellW())
    .height(this.cellW())
    .backgroundColor(this.selected === idx ? $r('app.color.gold') : $r('app.color.card'))
    .borderRadius(this.boxBorder(idx) ? 0 : 2)
    .border({
      width: 0.5,
      color: $r('app.color.divider'),
    })
    .margin(this.cellMargin(idx))
    .onClick(() => {
      if (!this.given[idx]) {
        this.selected = idx
      }
    })
  }

  private cellW(): number {
    return 36
  }

  private boxBorder(idx: number): boolean {
    return false
  }

  /** 用 margin 模拟宫线：每 3 列/行后加粗间隙 */
  private cellMargin(idx: number): Margin {
    const r = Math.floor(idx / 9)
    const c = idx % 9
    const m = 0.5
    const big = 2.2
    const left = c % 3 === 0 ? big : m
    const right = c % 3 === 2 ? big : m
    const top = r % 3 === 0 ? big : m
    const bottom = r % 3 === 2 ? big : m
    return { left: left, right: right, top: top, bottom: bottom }
  }

  private isConflict(idx: number): boolean {
    if (this.values[idx] === 0) {
      return false
    }
    return cellConflicts(this.values, idx).length > 0
  }

  @Builder
  Stats() {
    Row({ space: 10 }) {
      Tag({ label: DIFF_NAMES[this.diff], tone: 'red' })
      Tag({ label: `失误 ${this.mistakes}`, tone: 'plain' })
      Blank()
      Text(this.pencil ? '✏️ 笔记开' : '✏️ 笔记')
        .fontSize(12)
        .fontColor(this.pencil ? Color.White : $r('app.color.ink_light'))
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius(10)
        .backgroundColor(this.pencil ? $r('app.color.gold') : $r('app.color.wash'))
        .onClick(() => {
          this.pencil = !this.pencil
        })
      Text('💡 提示')
        .fontSize(12)
        .fontColor($r('app.color.cinnabar'))
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor($r('app.color.wash'))
        .borderRadius(10)
        .onClick(() => this.hint())
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  Pad() {
    Row({ space: 6 }) {
      ForEach(PAD, (v: number) => {
        Text(v.toString())
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .width(34)
          .height(42)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.card'))
          .borderRadius(10)
          .border({ width: 1, color: $r('app.color.divider') })
          .onClick(() => this.input(v))
      }, (v: number) => `pad-${v}`)
      Text('⌫')
        .fontSize(18)
        .fontColor($r('app.color.cinnabar'))
        .width(34)
        .height(42)
        .textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.wash'))
        .borderRadius(10)
        .onClick(() => this.input(0))
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  private input(v: number): void {
    if (this.selected < 0 || this.given[this.selected] || this.finished) {
      return
    }
    const idx = this.selected
    if (v === 0) {
      this.values[idx] = 0
      this.notes[idx] = ''
      this.refreshArrays()
      return
    }
    if (this.pencil) {
      const cur = this.notes[idx]
      const s = v.toString()
      this.notes[idx] = cur.includes(s) ? cur.replace(s, '') : (cur + s).split('').sort().join('')
      this.refreshArrays()
      return
    }
    if (this.values[idx] === v) {
      return
    }
    this.values[idx] = v
    this.notes[idx] = ''
    if (v !== this.solution[idx]) {
      this.mistakes++
    }
    this.refreshArrays()
    this.checkWin()
  }

  /** 强制数组引用刷新（@State 数组内容变更需重新赋值） */
  private refreshArrays(): void {
    const v2 = this.values.slice()
    this.values = v2
    const n2 = this.notes.slice()
    this.notes = n2
    const g2 = this.given.slice()
    this.given = g2
  }

  private hint(): void {
    let idx = this.selected
    if (idx < 0 || this.given[idx] || this.values[idx] === this.solution[idx]) {
      for (let i = 0; i < 81; i++) {
        if (this.values[i] !== this.solution[i]) {
          idx = i
          break
        }
      }
    }
    if (idx >= 0 && idx < 81) {
      this.values[idx] = this.solution[idx]
      this.notes[idx] = ''
      this.selected = idx
      this.refreshArrays()
      this.checkWin()
    }
  }

  private checkWin(): void {
    for (let i = 0; i < 81; i++) {
      if (this.values[i] !== this.solution[i]) {
        return
      }
    }
    this.finished = true
    this.stopTimer()
    GameStore.recordPlay('sudoku', this.mmss())
  }

  private start(diff: number, mode: string): void {
    this.generating = true
    this.showSetup = false
    // 生成放在下一帧，让 UI 先刷新出「生成中」
    setTimeout(() => {
      let rand: Rand
      if (mode === 'daily') {
        const d = new Date()
        const seed = Math.floor(d.getTime() / 86400000)
        rand = new Rand(seed * 7919 + 17)
      } else {
        rand = new Rand(Math.floor(Math.random() * 2147483647))
      }
      const p: SudokuPuzzle = makePuzzle(rand, cluesOfDifficulty(diff))
      this.puzzle = p.puzzle
      this.solution = p.solution
      this.values = p.puzzle.slice()
      const g: boolean[] = []
      const n: string[] = []
      for (let i = 0; i < 81; i++) {
        g.push(p.puzzle[i] !== 0)
        n.push('')
      }
      this.given = g
      this.notes = n
      this.selected = -1
      this.mistakes = 0
      this.diff = diff
      this.mode = mode
      this.finished = false
      this.generating = false
      this.seconds = 0
      this.startTimer()
      GameStore.recordPlay('sudoku')
    }, 50)
  }

  private startTimer(): void {
    this.stopTimer()
    this.timerId = setInterval(() => {
      this.seconds++
    }, 1000)
  }

  private stopTimer(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  private mmss(): string {
    const m = Math.floor(this.seconds / 60)
    const s = this.seconds % 60
    return `${m < 10 ? '0' : ''}${m}:${s < 10 ? '0' : ''}${s}`
  }

  private quit(): void {
    this.stopTimer()
    if (this.pathStack) {
      this.pathStack.pop()
    }
  }
}
