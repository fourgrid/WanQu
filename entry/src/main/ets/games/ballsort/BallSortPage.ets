/**
 * 球球排序页：点管选球 / 再点目标管倒入 / 撤销 / 关卡递增
 */
import { SortLevel, Move, makeSortLevel, canPour, doPour, undoMove, isSolved, BALL_COLORS } from './BallSortEngine'
import { GameTopBar, PrimaryBtn, GhostBtn, ResultOverlay, Tag } from '../../components/Common'
import { GameStore } from '../../store/GameStore'

@Component
export struct BallSortPage {
  @State level: number = 1
  @State tubes: number[][] = []
  @State capacity: number = 4
  @State selectedTube: number = -1
  @State moves: number = 0
  @State history: Move[] = []
  @State over: boolean = false
  @State win: boolean = false
  @State playing: boolean = false
  private pathStack: NavPathStack | null = null

  build() {
    NavDestination() {
      Column({ space: 12 }) {
        GameTopBar({
          title: `球球排序 · 第${this.level}关`,
          stat: this.playing ? `${this.moves} 步` : '',
          onBack: () => this.quit(),
        })
        if (!this.playing) {
          Column({ space: 14 }) {
            Text('🔮')
              .fontSize(46)
            Text('球球排序')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
            Text('点一根管子拿起顶部同色球，再点另一根倒入；\n目标管需同色或为空；把每种颜色归到一根管子里即胜。\n关卡由已解局面逆向打乱生成，必定有解。')
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
          this.Tubes()
          Row({ space: 10 }) {
            Tag({ label: `第${this.level}关`, tone: 'red' })
            GhostBtn({ label: '撤销', onTap: () => this.undo() })
            GhostBtn({ label: '重开', onTap: () => this.startLevel(this.level) })
            Blank()
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          Blank()
        }
        ResultOverlay({
          visible: this.over,
          win: this.win,
          title: this.win ? `第${this.level}关完成！` : '本关未完成',
          detail: this.win ? `共 ${this.moves} 步` : '再试一次',
          primaryLabel: this.win ? '下一关' : '重试本关',
          secondaryLabel: this.win ? '返回大厅' : '',
          onPrimary: () => this.startLevel(this.win ? this.level + 1 : this.level),
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
  Tubes() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
      ForEach(this.tubes, (t: number[], ti: number) => {
        Column({ space: 5 }) {
          // 球（自顶向下显示 = 数组倒序）
          Column({ space: 4 }) {
            ForEach(this.ballsDisplay(t), (c: number) => {
              Circle()
                .width(26)
                .height(26)
                .fill(c < 0 ? Color.Transparent : BALL_COLORS[c % BALL_COLORS.length])
                .border({
                  width: c < 0 ? 1.5 : 0,
                  color: $r('app.color.divider'),
                })
            }, (c: number, i: number) => `ball-${ti}-${i}-${c}`)
          }
          .justifyContent(FlexAlign.End)
          .height(4 * 30)
        }
        .padding({ left: 5, right: 5, top: 6, bottom: 6 })
        .margin(4)
        .borderRadius(12)
        .border({
          width: this.selectedTube === ti ? 2.5 : 1.5,
          color: this.selectedTube === ti ? $r('app.color.cinnabar') : $r('app.color.divider'),
        })
        .backgroundColor($r('app.color.wash'))
        .onClick(() => this.tapTube(ti))
      }, (t: number[], ti: number) => `tube-${ti}-${t.join(',')}`)
    }
    .width('100%')
  }

  /** 从顶到底展示（含空位占位），高度恒定 */
  private ballsDisplay(t: number[]): number[] {
    const out: number[] = []
    for (let i = 0; i < this.capacity - t.length; i++) {
      out.push(-1)
    }
    for (let i = t.length - 1; i >= 0; i--) {
      out.push(t[i])
    }
    return out
  }

  private tapTube(ti: number): void {
    if (this.over) {
      return
    }
    if (this.selectedTube < 0) {
      if (this.tubes[ti].length > 0) {
        this.selectedTube = ti
      }
      return
    }
    if (this.selectedTube === ti) {
      this.selectedTube = -1
      return
    }
    const from = this.selectedTube
    if (!canPour(this.tubes, from, ti, this.capacity)) {
      this.selectedTube = -1
      return
    }
    const mv = doPour(this.tubes, from, ti, this.capacity)
    this.moves++
    this.history.push(mv)
    // 拷贝触发刷新
    const copy: number[][] = []
    for (const t of this.tubes) {
      copy.push(t.slice())
    }
    this.tubes = copy
    this.selectedTube = -1
    if (isSolved(this.tubes, this.capacity)) {
      this.win = true
      this.over = true
      GameStore.recordScore('ballsort', this.moves, this.level)
      GameStore.recordPlay('ballsort')
    }
  }

  private undo(): void {
    if (this.history.length === 0 || this.over) {
      return
    }
    const mv = this.history.pop()
    if (mv) {
      undoMove(this.tubes, mv)
      this.moves = Math.max(0, this.moves - 1)
      const copy: number[][] = []
      for (const t of this.tubes) {
        copy.push(t.slice())
      }
      this.tubes = copy
    }
  }

  private startLevel(n: number): void {
    const lv: SortLevel = makeSortLevel(n, () => Math.random())
    this.level = n
    const copy: number[][] = []
    for (const t of lv.tubes) {
      copy.push(t.slice())
    }
    this.tubes = copy
    this.capacity = lv.capacity
    this.selectedTube = -1
    this.moves = 0
    this.history = []
    this.over = false
    this.win = false
    this.playing = true
    GameStore.recordPlay('ballsort')
  }

  private quit(): void {
    if (this.pathStack) {
      this.pathStack.pop()
    }
  }
}
