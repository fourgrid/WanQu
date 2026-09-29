/**
 * 球球排序 · 开发中（引擎就绪，逐个打磨上线）
 */
@Component
export struct BallSortPage {
  private pathStack: NavPathStack | null = null

  build() {
    NavDestination() {
      Column({ space: 16 }) {
        Blank()
        Text('球球排序')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text('开发中 · 逐个打磨上线')
          .fontSize(13)
          .fontColor($r('app.color.ink_light'))
        Text('回到大厅玩连连看')
          .fontSize(14)
          .fontColor(Color.White)
          .padding({ left: 22, right: 22, top: 11, bottom: 11 })
          .backgroundColor($r('app.color.cinnabar'))
          .borderRadius(13)
          .margin({ top: 6 })
        Blank()
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.paper'))
    .onReady((ctx: NavDestinationContext) => {
      this.pathStack = ctx.pathStack
    })
  }
}
