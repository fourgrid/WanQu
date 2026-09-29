/**
 * 玩趣 - 大厅：游戏网格 + 最近战绩
 */
import { GAMES, GameMeta, GameRecord } from '../model/Types'
import { GameStore } from '../store/GameStore'
import { ScrewPage } from '../games/screw/ScrewPage'
import { SudokuPage } from '../games/sudoku/SudokuPage'
import { LinkPage } from '../games/link/LinkPage'
import { BlockPage } from '../games/block/BlockPage'
import { BallSortPage } from '../games/ballsort/BallSortPage'
import { NonogramPage } from '../games/nonogram/NonogramPage'
import { ParkingPage } from '../games/parking/ParkingPage'
import { KlotskiPage } from '../games/klotski/KlotskiPage'

@Entry
@Component
struct Index {
  pathStack: NavPathStack = new NavPathStack()

  build() {
    Navigation(this.pathStack) {
      Column({ space: 18 }) {
        Row({ space: 10 }) {
          Column() {
            Text('玩趣')
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
              .letterSpacing(4)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Text('八个游戏 · 一盒在手')
            .fontSize(11)
            .fontColor($r('app.color.ink_faint'))
            .padding({ top: 4 })
        }
        .width('100%')

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(GAMES, (g: GameMeta) => {
            this.GameCard(g)
          }, (g: GameMeta) => `game-${g.id}`)
        }
        .width('100%')

        Text('所有游戏离线可玩 · 成绩保存在本机')
          .fontSize(11)
          .fontColor($r('app.color.ink_faint'))
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 20 })
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.pagesMap)
    .backgroundColor($r('app.color.paper'))
  }

  @Builder
  pagesMap(name: string) {
    if (name === 'screw') {
      ScrewPage()
    } else if (name === 'sudoku') {
      SudokuPage()
    } else if (name === 'link') {
      LinkPage()
    } else if (name === 'block') {
      BlockPage()
    } else if (name === 'ballsort') {
      BallSortPage()
    } else if (name === 'nonogram') {
      NonogramPage()
    } else if (name === 'parking') {
      ParkingPage()
    } else if (name === 'klotski') {
      KlotskiPage()
    }
  }

  @Builder
  GameCard(g: GameMeta) {
    Column({ space: 8 }) {
      Text(g.glyph)
        .fontSize(34)
      Text(g.name)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
      Text(g.tagline)
        .fontSize(10)
        .fontColor($r('app.color.ink_light'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.cardStat(g.id))
        .fontSize(10)
        .fontColor($r('app.color.gold'))
    }
    .alignItems(HorizontalAlign.Start)
    .width('47.5%')
    .padding(14)
    .margin(4)
    .backgroundColor($r('app.color.card'))
    .borderRadius(18)
    .border({ width: 1, color: $r('app.color.divider') })
    .onClick(() => {
      this.pathStack.pushPathByName(g.id, g.id)
    })
  }

  private cardStat(id: string): string {
    const r: GameRecord = GameStore.get(id)
    if (r.playCount === 0) {
      return '未开局'
    }
    if (r.bestLevel > 0 && r.bestScore > 0) {
      return `最高第${r.bestLevel}关 · 最佳${r.bestScore}分`
    }
    if (r.bestLevel > 0) {
      return `最高第${r.bestLevel}关`
    }
    if (r.bestScore > 0) {
      return `最佳 ${r.bestScore} 分`
    }
    return `已玩 ${r.playCount} 局`
  }
}
