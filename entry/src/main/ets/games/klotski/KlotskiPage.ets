/**
 * 华容道页：经典五大布局 / 点子亮出可行方向 / 曹操出底口
 */
import { KPiece, KLayout, LAYOUTS, parseLayout, movePiece, caocaoFree } from './KlotskiEngine'
import { GameTopBar, PrimaryBtn, ResultOverlay, Tag } from '../../components/Common'
import { GameStore } from '../../store/GameStore'

@Component
export struct KlotskiPage {
  @State pieces: KPiece[] = []
  @State layoutIdx: number = 0
  @State layoutName: string = ''
  @State par: number = 0
  @State moves: number = 0
  @State selected: number = -1
  @State over: boolean = false
  @State playing: boolean = false
  private pathStack: NavPathStack | null = null

  build() {
    NavDestination() {
      Column({ space: 12 }) {
        GameTopBar({
          title: this.playing ? `华容道 · ${this.layoutName}` : '华容道',
          stat: this.playing ? `${this.moves} 步 / 参考 ${this.par}` : '',
          onBack: () => this.quit(),
        })
        if (!this.playing) {
          Column({ space: 12 }) {
            Text('🀄')
              .fontSize(46)
            Text('华容道')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
            Text('点选棋子，四周亮出的箭头即为可走方向；\n把 2×2 的曹操移到底部中间出口即胜。\n五个经典布局，步数挑战。')
              .fontSize(12)
              .fontColor($r('app.color.ink_light'))
              .textAlign(TextAlign.Center)
              .lineHeight(19)
            Column({ space: 8 }) {
              ForEach(LAYOUTS, (l: KLayout, i: number) => {
                Text(`${l.name} · 参考 ${l.par} 步`)
                  .fontSize(14)
                  .fontColor($r('app.color.ink'))
                  .padding({ left: 20, right: 20, top: 10, bottom: 10 })
                  .backgroundColor($r('app.color.card'))
                  .borderRadius(12)
                  .border({ width: 1, color: $r('app.color.divider') })
                  .onClick(() => this.startLayout(i))
              }, (l: KLayout) => `lay-${l.name}`)
            }
            Blank()
          }
          .width('100%')
          .layoutWeight(1)
        } else {
          this.Board()
          Row({ space: 10 }) {
            Tag({ label: this.layoutName, tone: 'red' })
            Text('换布局')
              .fontSize(13)
              .fontColor($r('app.color.ink_light'))
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .backgroundColor($r('app.color.wash'))
              .borderRadius(10)
              .onClick(() => {
                this.playing = false
                this.over = false
              })
            Text('重开本局')
              .fontSize(13)
              .fontColor($r('app.color.ink_light'))
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .backgroundColor($r('app.color.wash'))
              .borderRadius(10)
              .onClick(() => this.startLayout(this.layoutIdx))
            Blank()
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          Blank()
        }
        ResultOverlay({
          visible: this.over,
          win: true,
          title: this.moves <= this.par ? `神机妙算！${this.moves} 步` : `曹操出走！${this.moves} 步`,
          detail: this.moves <= this.par ? '达到参考最优解' : `该布局参考 ${this.par} 步`,
          primaryLabel: '再战一局',
          secondaryLabel: '返回大厅',
          onPrimary: () => this.startLayout(this.layoutIdx),
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
    return 78
  }

  @Builder
  Board() {
    Column() {
      ForEach(this.range(5), (r: number) => {
        Row() {
          ForEach(this.range(4), (c: number) => {
            this.Cell(r, c)
          }, (c: number) => `kc-${r}-${c}`)
        }
      }, (r: number) => `kr-${r}`)
    }
    .backgroundColor($r('app.color.divider'))
    .borderRadius(12)
  }

  @Builder
  Cell(r: number, c: number) {
    Stack() {
      ForEach(this.pieces, (p: KPiece) => {
        if (p.r === r && p.c === c) {
          this.PieceView(p)
        }
      }, (p: KPiece) => `pz-${p.id}-${p.r}-${p.c}`)
      // 出口标记
      if (r === 4 && (c === 1 || c === 2)) {
        Text('出')
          .fontSize(12)
          .fontColor($r('app.color.gold'))
          .opacity(0.5)
      }
    }
    .width(this.cell() - 3)
    .height(this.cell() - 3)
    .margin(1.5)
    .borderRadius(8)
    .backgroundColor(this.cellHasPiece(r, c) ? Color.Transparent : $r('app.color.wash'))
    .onClick(() => {
      // 点空格：若与选中子相邻则尝试移动
      if (this.selected >= 0) {
        this.tryMoveTo(r, c)
      }
    })
  }

  private cellHasPiece(r: number, c: number): boolean {
    for (const p of this.pieces) {
      if (r >= p.r && r < p.r + p.h && c >= p.c && c < p.c + p.w) {
        return true
      }
    }
    return false
  }

  @Builder
  PieceView(p: KPiece) {
    Column({ space: 2 }) {
      Text(p.name)
        .fontSize(p.w === 2 && p.h === 2 ? 22 : 15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
      if (this.selected === p.id) {
        Text(this.dirHint(p))
          .fontSize(10)
          .fontColor('#FFFFFFCC')
      }
    }
    .justifyContent(FlexAlign.Center)
    .width(p.w * this.cell() - 8)
    .height(p.h * this.cell() - 8)
    .borderRadius(10)
    .backgroundColor(this.pieceColor(p))
    .border({ width: this.selected === p.id ? 2.5 : 0.5, color: this.selected === p.id ? '#F5E6C8' : '#00000044' })
    .animation({ duration: 130 })
    .onClick(() => {
      this.selected = this.selected === p.id ? -1 : p.id
    })
  }

  private pieceColor(p: KPiece): ResourceColor {
    if (p.w === 2 && p.h === 2) {
      return '#B03A2E'
    }
    if (p.w === 2) {
      return '#B98F45'
    }
    if (p.h === 2) {
      return '#5D6D7E'
    }
    return '#85929E'
  }

  private dirHint(p: KPiece): string {
    const dirs: string[] = []
    const probe = (dr: number, dc: number): boolean => {
      const nr = p.r + dr
      const nc = p.c + dc
      if (nr < 0 || nc < 0 || nr + p.h > 5 || nc + p.w > 4) {
        return false
      }
      for (const other of this.pieces) {
        if (other.id === p.id) {
          continue
        }
        if (nr < other.r + other.h && nr + p.h > other.r && nc < other.c + other.w && nc + p.w > other.c) {
          return false
        }
      }
      return true
    }
    if (probe(0, -1)) {
      dirs.push('←')
    }
    if (probe(0, 1)) {
      dirs.push('→')
    }
    if (probe(-1, 0)) {
      dirs.push('↑')
    }
    if (probe(1, 0)) {
      dirs.push('↓')
    }
    return dirs.join(' ')
  }

  /** 点击目标空格：把选中子朝该方向挪一格 */
  private tryMoveTo(r: number, c: number): void {
    const p = this.pieces.find((x: KPiece): boolean => x.id === this.selected)
    if (!p) {
      return
    }
    let dr = 0
    let dc = 0
    if (c === p.c - 1 && r >= p.r && r < p.r + p.h) {
      dc = -1
    } else if (c === p.c + p.w && r >= p.r && r < p.r + p.h) {
      dc = 1
    } else if (r === p.r - 1 && c >= p.c && c < p.c + p.w) {
      dr = -1
    } else if (r === p.r + p.h && c >= p.c && c < p.c + p.w) {
      dr = 1
    } else {
      this.selected = -1
      return
    }
    if (movePiece(this.pieces, this.selected, dr, dc)) {
      this.moves++
      const copy = this.pieces.map((x: KPiece): KPiece => {
        return { id: x.id, name: x.name, r: x.r, c: x.c, w: x.w, h: x.h }
      })
      this.pieces = copy
      if (caocaoFree(this.pieces)) {
        setTimeout(() => {
          this.over = true
          GameStore.recordScore('klotski', Math.max(0, this.par * 10 - this.moves), this.layoutIdx + 1)
          GameStore.recordPlay('klotski')
        }, 260)
      }
    } else {
      this.selected = -1
    }
  }

  private range(n: number): number[] {
    const r: number[] = []
    for (let i = 0; i < n; i++) {
      r.push(i)
    }
    return r
  }

  private startLayout(i: number): void {
    const layout = LAYOUTS[i]
    this.layoutIdx = i
    this.layoutName = layout.name
    this.par = layout.par
    this.pieces = parseLayout(layout)
    this.moves = 0
    this.selected = -1
    this.over = false
    this.playing = true
    GameStore.recordPlay('klotski')
  }

  private quit(): void {
    if (this.pathStack) {
      this.pathStack.pop()
    }
  }
}
