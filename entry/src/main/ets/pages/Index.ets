/**
 * 玩趣 - 大厅：当前主打连连看；其余游戏打磨中，逐个上线
 */
import { GameStore } from '../store/GameStore'
import { LinkPage } from '../games/link/LinkPage'

const COMING: string[] = ['拧螺丝', '数独', '方块消除', '球球排序', '数织', '挪车出道', '华容道']

@Entry
@Component
struct Index {
  pathStack: NavPathStack = new NavPathStack()

  build() {
    Navigation(this.pathStack) {
      Scroll() {
        Column({ space: 16 }) {
          // 头部
          Row({ space: 12 }) {
            Image($r('app.media.app_icon'))
              .width(46)
              .height(46)
              .borderRadius(13)
            Column({ space: 3 }) {
              Text('玩趣')
                .fontSize(26)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.ink'))
                .letterSpacing(3)
              Text('好游戏，一个一个打磨')
                .fontSize(11)
                .fontColor($r('app.color.ink_faint'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding({ top: 10 })

          // 主推一行：连连看
          Row({ space: 14 }) {
            Image($r('app.media.game_link'))
              .width(62)
              .height(62)
              .borderRadius(16)
              .shadow({ radius: 6, color: 'rgba(36,92,65,0.35)', offsetY: 3 })
            Column({ space: 4 }) {
              Text('连连看')
                .fontSize(19)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.ink'))
              Text('两折连通 · 连击消除 · 关卡挑战')
                .fontSize(11)
                .fontColor($r('app.color.ink_light'))
              Text(this.linkStat())
                .fontSize(10)
                .fontColor($r('app.color.gold'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text('开始 ›')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .padding({ left: 18, right: 16, top: 9, bottom: 9 })
              .backgroundColor($r('app.color.cinnabar'))
              .borderRadius(14)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .padding({ left: 12, right: 12, top: 12, bottom: 12 })
          .backgroundColor($r('app.color.card'))
          .borderRadius(18)
          .border({ width: 1.2, color: '#3D8B65' })
          .shadow({ radius: 8, color: 'rgba(43,38,32,0.10)', offsetY: 3 })
          .scale(this.pressed ? { x: 0.97, y: 0.97 } : { x: 1, y: 1 })
          .animation({ duration: 120, curve: Curve.FastOutSlowIn })
          .onTouch((e: TouchEvent) => {
            this.pressed = e.type === TouchType.Down
          })
          .onClick(() => {
            this.pathStack.pushPathByName('link', 'link')
          })

          // 打磨中
          Column({ space: 10 }) {
            Row({ space: 8 }) {
              Rect()
                .width(14)
                .height(3)
                .radius(1.5)
                .fill($r('app.color.gold'))
              Text('打磨中 · 逐个上线')
                .fontSize(13)
                .fontColor($r('app.color.ink_light'))
                .letterSpacing(1)
            }
            .alignItems(VerticalAlign.Center)

            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(COMING, (name: string) => {
                Text(`${name} · 打磨中`)
                  .fontSize(12)
                  .fontColor($r('app.color.ink_faint'))
                  .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                  .margin(3)
                  .backgroundColor($r('app.color.wash'))
                  .borderRadius(10)
              }, (name: string) => `coming-${name}`)
            }
            .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .margin({ top: 6 })

          Text('全部离线可玩 · 成绩保存在本机')
            .fontSize(11)
            .fontColor($r('app.color.ink_faint'))
            .padding({ top: 2, bottom: 12 })
        }
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, top: 8 })
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.pagesMap)
    .backgroundColor($r('app.color.paper'))
  }

  @State pressed: boolean = false

  @Builder
  pagesMap(name: string) {
    if (name === 'link') {
      LinkPage()
    }
  }

  private linkStat(): string {
    const r = GameStore.get('link')
    if (r.playCount === 0) {
      return '还没玩过，点开始试试'
    }
    if (r.bestLevel > 0) {
      return `已到第 ${r.bestLevel} 关 · 最高 ${r.bestScore} 分`
    }
    return `最高 ${r.bestScore} 分 · 已玩 ${r.playCount} 局`
  }
}
