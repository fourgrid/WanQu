/**
 * 挪车出道页：点车选中 / 左右箭头滑动 / 红车到达出口即胜
 */
import { Car, ParkLevel, makeParkLevel, slide, redCanExit, CAR_COLORS } from './ParkingEngine'
import { GameTopBar, PrimaryBtn, ResultOverlay, Tag } from '../../components/Common'
import { GameStore } from '../../store/GameStore'

@Component
export struct ParkingPage {
  @State level: number = 1
  @State cars: Car[] = []
  @State par: number = 0
  @State selected: number = -1
  @State moves: number = 0
  @State over: boolean = false
  @State playing: boolean = false
  @State exitFlash: boolean = false
  private pathStack: NavPathStack | null = null
  private rows = 5
  private cols = 6
  private exitRow = 2

  build() {
    NavDestination() {
      Column({ space: 12 }) {
        GameTopBar({
          title: `挪车出道 · 第${this.level}关`,
          stat: this.playing ? `${this.moves} 步 / 目标 ${this.par}` : '',
          onBack: () => this.quit(),
        })
        if (!this.playing) {
          Column({ space: 14 }) {
            Text('🚗')
              .fontSize(46)
            Text('挪车出道')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
            Text('点选车辆，用箭头前后滑动，给红色主车清出通道；\n红车抵达右侧出口即过关。每关由 BFS 求解器验证可解，\n并给出最少步数做目标。')
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
          this.Lot()
          this.Controls()
          Blank()
        }
        ResultOverlay({
          visible: this.over,
          win: true,
          title: this.moves <= this.par ? `完美！${this.moves} 步出道` : `过关！${this.moves} 步`,
          detail: this.moves <= this.par ? '达到最少步数' : `最少步数为 ${this.par}`,
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

  private cell(): number {
    return 54
  }

  @Builder
  Lot() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        ForEach(this.range(this.rows), (r: number) => {
          Row() {
            ForEach(this.range(this.cols + 1), (c: number) => {
              this.LotCell(r, c)
            }, (c: number) => `lc-${r}-${c}`)
          }
        }, (r: number) => `lr-${r}`)
      }
      this.CarView()
    }
    .width((this.cols + 1) * this.cell())
    .height(this.rows * this.cell())
    .backgroundColor($r('app.color.divider'))
    .borderRadius(10)
  }

  @Builder
  LotCell(r: number, c: number) {
    Stack() {
      if (r === this.exitRow && c === this.cols) {
        Text(this.exitFlash ? '🚗' : '出口')
          .fontSize(this.exitFlash ? 30 : 10)
          .fontColor($r('app.color.jade_ok'))
      }
    }
    .width(this.cell() - 2)
    .height(this.cell() - 2)
    .margin(1)
    .borderRadius(6)
    .backgroundColor(r === this.exitRow && c === this.cols ? '#DFF0E3' : $r('app.color.wash'))
    .onClick(() => {
      // 点击出口格：若红车通畅则驶出
      if (r === this.exitRow && c === this.cols && redCanExit(this.cars, this.cols)) {
        this.exitFlash = true
        setTimeout(() => {
          this.win()
        }, 350)
      }
    })
  }

  @Builder
  CarView() {
    ForEach(this.cars, (car: Car) => {
      Stack() {
        Column()
          .width(car.horiz ? car.len * this.cell() - 10 : this.cell() - 10)
          .height(car.horiz ? this.cell() - 10 : car.len * this.cell() - 10)
          .borderRadius(8)
          .backgroundColor(car.id === 0 ? '#C0392B' : CAR_COLORS[car.id % CAR_COLORS.length])
          .border({ width: this.selected === car.id ? 3 : 1, color: this.selected === car.id ? '#F5E6C8' : '#00000033' })
        Text(car.id === 0 ? '主' : '')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .position({
        x: car.c * this.cell() + 5,
        y: car.r * this.cell() + 5,
      })
      .onClick(() => {
        this.selected = this.selected === car.id ? -1 : car.id
      })
      .animation({ duration: 140 })
    }, (car: Car) => `car-${car.id}-${car.r}-${car.c}`)
  }

  @Builder
  Controls() {
    Row({ space: 14 }) {
      Tag({ label: `第${this.level}关`, tone: 'red' })
      Text('◀')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.selected >= 0 ? $r('app.color.ink') : $r('app.color.ink_faint'))
        .width(46)
        .height(46)
        .textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.card'))
        .borderRadius(14)
        .border({ width: 1, color: $r('app.color.divider') })
        .onClick(() => this.doSlide(-1))
      Text('▶')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.selected >= 0 ? $r('app.color.ink') : $r('app.color.ink_faint'))
        .width(46)
        .height(46)
        .textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.card'))
        .borderRadius(14)
        .border({ width: 1, color: $r('app.color.divider') })
        .onClick(() => this.doSlide(1))
      Text('重开')
        .fontSize(13)
        .fontColor($r('app.color.ink_light'))
        .padding({ left: 12, right: 12, top: 9, bottom: 9 })
        .backgroundColor($r('app.color.wash'))
        .borderRadius(11)
        .onClick(() => this.startLevel(this.level))
      Blank()
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  private doSlide(d: number): void {
    if (this.selected < 0 || this.over) {
      return
    }
    if (slide(this.cars, this.selected, d, this.rows, this.cols)) {
      this.moves++
      const copy = this.cars.map((c: Car): Car => {
        return { id: c.id, r: c.r, c: c.c, len: c.len, horiz: c.horiz }
      })
      this.cars = copy
      // 若选中红车且已通畅，提示可出
      if (this.selected === 0 && redCanExit(this.cars, this.cols)) {
        this.selected = -1
      }
    }
  }

  private win(): void {
    this.over = true
    GameStore.recordScore('parking', Math.max(0, this.par * 100 - this.moves * 10), this.level)
    GameStore.recordPlay('parking')
  }

  private range(n: number): number[] {
    const r: number[] = []
    for (let i = 0; i < n; i++) {
      r.push(i)
    }
    return r
  }

  private startLevel(n: number): void {
    const lv: ParkLevel | null = makeParkLevel(n, () => Math.random(), 40)
    if (!lv) {
      return
    }
    this.level = n
    this.par = lv.par
    this.rows = lv.rows
    this.cols = lv.cols
    this.exitRow = lv.exitRow
    this.cars = lv.cars.map((c: Car): Car => {
      return { id: c.id, r: c.r, c: c.c, len: c.len, horiz: c.horiz }
    })
    this.selected = -1
    this.moves = 0
    this.over = false
    this.exitFlash = false
    this.playing = true
    GameStore.recordPlay('parking')
  }

  private quit(): void {
    if (this.pathStack) {
      this.pathStack.pop()
    }
  }
}
