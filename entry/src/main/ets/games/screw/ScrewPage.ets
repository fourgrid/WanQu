/**
 * 拧螺丝页：层叠板件 / 点螺丝入盒 / 板件坠落动画 / 关卡推进
 */
import { ScrewLevel, Plate, Screw, makeLevelRetry, covered, takeScrew, allDone, binCounts, plateOf, SCREW_COLORS } from './ScrewEngine'
import { GameTopBar, PrimaryBtn, GhostBtn, ResultOverlay, Tag } from '../../components/Common'
import { GameStore } from '../../store/GameStore'

@Component
export struct ScrewPage {
  @State levelNo: number = 1
  @State level: ScrewLevel | null = null
  @State moves: number = 0
  @State falling: number[] = []       // 坠落中的板 id
  @State playing: boolean = false
  @State over: boolean = false
  @State win: boolean = false
  @State binPulse: number = -1        // 最近入盒颜色
  private pathStack: NavPathStack | null = null

  build() {
    NavDestination() {
      Column({ space: 12 }) {
        GameTopBar({
          title: `拧螺丝 · 第${this.levelNo}关`,
          stat: this.playing ? `已拧 ${this.moves} 颗` : '',
          onBack: () => this.quit(),
        })
        if (!this.playing || this.level === null) {
          Column({ space: 14 }) {
            Text('🔩')
              .fontSize(46)
            Text('拧螺丝')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
            Text('点选亮着的螺丝拧下，按颜色飞入收纳盒；\n板上的螺丝拧完，板件就会坠落露出下层。')
              .fontSize(12)
              .fontColor($r('app.color.ink_light'))
              .textAlign(TextAlign.Center)
              .lineHeight(19)
            PrimaryBtn({ label: '开始第 1 关', onTap: () => this.startLevel(1) })
            Blank()
          }
          .width('100%')
          .layoutWeight(1)
        } else {
          this.Board()
          this.Bins()
          Blank()
        }
        ResultOverlay({
          visible: this.over,
          win: this.win,
          title: this.win ? `第${this.levelNo}关完成` : '生成失败',
          detail: this.win ? `${this.moves} 颗螺丝归位` : '请重试',
          primaryLabel: this.win ? '下一关' : '重新生成',
          secondaryLabel: this.win ? '返回大厅' : '',
          onPrimary: () => this.startLevel(this.win ? this.levelNo + 1 : this.levelNo),
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

  private cell(): number {
    return 54
  }

  @Builder
  Board() {
    Stack() {
      // 板件层
      ForEach(this.visiblePlates(), (p: Plate) => {
        this.PlateView(p)
      }, (p: Plate) => `plate-${p.id}-${p.fallen ? 'f' : 'a'}`)
      // 螺丝层
      ForEach(this.level!.screws, (s: Screw) => {
        this.ScrewView(s)
      }, (s: Screw) => `screw-${s.id}-${s.taken ? 't' : 'n'}`)
    }
    .width(this.level!.cols * this.cell())
    .height(this.level!.rows * this.cell())
    .alignContent(Alignment.TopStart)
  }

  private visiblePlates(): Plate[] {
    const out: Plate[] = []
    if (!this.level) {
      return out
    }
    for (const p of this.level.plates) {
      if (!p.fallen || this.falling.indexOf(p.id) >= 0) {
        out.push(p)
      }
    }
    return out
  }

  private plateBounds(p: Plate): number[] {
    const cols = this.level!.cols
    let minR = 99
    let minC = 99
    let maxR = 0
    let maxC = 0
    for (const c of p.cells) {
      const r = Math.floor(c / cols)
      const cc = c % cols
      minR = Math.min(minR, r)
      minC = Math.min(minC, cc)
      maxR = Math.max(maxR, r)
      maxC = Math.max(maxC, cc)
    }
    return [minC, minR, maxC - minC + 1, maxR - minR + 1]
  }

  @Builder
  PlateView(p: Plate) {
    Column()
      .width(this.plateBounds(p)[2] * this.cell() - 8)
      .height(this.plateBounds(p)[3] * this.cell() - 8)
      .position({
        x: this.plateBounds(p)[0] * this.cell() + 4,
        y: this.plateBounds(p)[1] * this.cell() + 4,
      })
      .backgroundColor(this.falling.indexOf(p.id) >= 0 ? Color.Transparent : this.plateColor(p.layer))
      .borderRadius(10)
      .border({ width: 1, color: $r('app.color.divider') })
      .opacity(this.falling.indexOf(p.id) >= 0 ? 0.15 : 1)
      .offset({ y: this.falling.indexOf(p.id) >= 0 ? 90 : 0 })
      .rotate({ angle: this.falling.indexOf(p.id) >= 0 ? 14 : 0 })
      .animation({ duration: 320, curve: Curve.Friction })
  }

  private plateColor(layer: number): ResourceColor {
    if (layer === 0) {
      return '#D9CDB8'
    }
    if (layer === 1) {
      return '#CBBFA8'
    }
    return '#BFB29A'
  }

  @Builder
  ScrewView(s: Screw) {
    if (!s.taken) {
      Stack() {
        Circle()
          .width(24)
          .height(24)
          .fill(SCREW_COLORS[s.color % SCREW_COLORS.length])
        Text('+')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFFCC')
      }
      .width(28)
      .height(28)
      .position({
        x: (s.cell % this.level!.cols) * this.cell() + this.cell() / 2 - 14,
        y: Math.floor(s.cell / this.level!.cols) * this.cell() + this.cell() / 2 - 14,
      })
      .opacity(this.tappable(s) ? 1 : 0.25)
      .scale(this.tappable(s) ? { x: 1, y: 1 } : { x: 0.85, y: 0.85 })
      .animation({ duration: 160 })
      .onClick(() => this.tapScrew(s))
    }
  }

  private tappable(s: Screw): boolean {
    if (!this.level || s.taken) {
      return false
    }
    const plate = plateOf(this.level, s)
    if (!plate) {
      return false
    }
    return !covered(this.level, s.cell, plate.layer)
  }

  @Builder
  Bins() {
    if (this.level) {
      Row({ space: 10 }) {
        ForEach(binCounts(this.level), (cnt: number, ci: number) => {
          Column({ space: 3 }) {
            Text(`${cnt}/${this.level!.bins[ci]}`)
              .fontSize(10)
              .fontColor(cnt >= this.level!.bins[ci] ? $r('app.color.jade_ok') : $r('app.color.ink_light'))
            Row({ space: 3 }) {
              ForEach(this.range(4), (k: number) => {
                Circle()
                  .width(11)
                  .height(11)
                  .fill(k < cnt ? SCREW_COLORS[ci % SCREW_COLORS.length] : $r('app.color.wash'))
                  .border({ width: 1, color: $r('app.color.divider') })
              }, (k: number) => `bd-${ci}-${k}-${k < cnt}`)
            }
          }
          .alignItems(HorizontalAlign.Center)
          .padding({ left: 8, right: 8, top: 6, bottom: 6 })
          .backgroundColor(this.binPulse === ci ? $r('app.color.gold') : $r('app.color.card'))
          .borderRadius(12)
          .border({ width: 1, color: $r('app.color.divider') })
          .animation({ duration: 200 })
        }, (cnt: number, ci: number) => `bin-${ci}-${cnt}`)
        Blank()
        Tag({ label: `第${this.levelNo}关`, tone: 'red' })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
  }

  private range(n: number): number[] {
    const r: number[] = []
    for (let i = 0; i < n; i++) {
      r.push(i)
    }
    return r
  }

  private tapScrew(s: Screw): void {
    if (!this.level || this.over || !this.tappable(s)) {
      return
    }
    const fallen = takeScrew(this.level, s)
    this.moves++
    this.binPulse = s.color
    // 深拷贝触发刷新
    this.level = this.cloneLevel(this.level)
    if (fallen.length > 0) {
      this.falling = fallen.slice()
      setTimeout(() => {
        this.falling = []
      }, 340)
    }
    setTimeout(() => {
      this.binPulse = -1
    }, 220)
    if (allDone(this.level)) {
      this.win = true
      this.over = true
      GameStore.recordScore('screw', this.moves, this.levelNo)
      GameStore.recordPlay('screw')
    }
  }

  private cloneLevel(lv: ScrewLevel): ScrewLevel {
    const plates: Plate[] = lv.plates.map((p: Plate): Plate => {
      return { id: p.id, cells: p.cells.slice(), layer: p.layer, fallen: p.fallen }
    })
    const screws: Screw[] = lv.screws.map((s: Screw): Screw => {
      return { id: s.id, cell: s.cell, plateId: s.plateId, color: s.color, taken: s.taken }
    })
    return { rows: lv.rows, cols: lv.cols, plates: plates, screws: screws, bins: lv.bins.slice(), colorCount: lv.colorCount }
  }

  private startLevel(n: number): void {
    const lv = makeLevelRetry(n, () => Math.random(), 20)
    if (lv === null) {
      this.playing = true
      this.win = false
      this.over = true
      return
    }
    this.levelNo = n
    this.level = lv
    this.moves = 0
    this.falling = []
    this.playing = true
    this.over = false
    this.win = false
    GameStore.recordPlay('screw')
  }

  private quit(): void {
    if (this.pathStack) {
      this.pathStack.pop()
    }
  }
}
