/**
 * 玩趣 - 通用组件：游戏顶栏 / 结果浮层 / 标签
 */

/** 游戏页顶栏：返回 + 标题 + 右侧动作 */
@Component
export struct GameTopBar {
  @Prop title: string = ''
  @Prop stat: string = ''
  onBack: () => void = () => {}

  build() {
    Row({ space: 10 }) {
      Text('‹')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .width(34)
        .height(34)
        .textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.card'))
        .borderRadius(12)
        .border({ width: 1, color: $r('app.color.divider') })
        .onClick(() => this.onBack())
      Text(this.title)
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .layoutWeight(1)
      if (this.stat !== '') {
        Text(this.stat)
          .fontSize(13)
          .fontColor($r('app.color.gold'))
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor($r('app.color.wash'))
          .borderRadius(10)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: 8, bottom: 8 })
  }
}

/** 主按钮 */
@Component
export struct PrimaryBtn {
  @Prop label: string = ''
  onTap: () => void = () => {}

  build() {
    Text(this.label)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor(Color.White)
      .padding({ left: 22, right: 22, top: 11, bottom: 11 })
      .backgroundColor($r('app.color.cinnabar'))
      .borderRadius(13)
      .onClick(() => this.onTap())
  }
}

/** 次按钮 */
@Component
export struct GhostBtn {
  @Prop label: string = ''
  onTap: () => void = () => {}

  build() {
    Text(this.label)
      .fontSize(14)
      .fontColor($r('app.color.ink'))
      .padding({ left: 18, right: 18, top: 10, bottom: 10 })
      .backgroundColor($r('app.color.wash'))
      .borderRadius(12)
      .border({ width: 1, color: $r('app.color.divider') })
      .onClick(() => this.onTap())
  }
}

/** 结果浮层：胜利/失败 */
@Component
export struct ResultOverlay {
  @Prop visible: boolean = false
  @Prop win: boolean = true
  @Prop title: string = ''
  @Prop detail: string = ''
  primaryLabel: string = '再来一局'
  secondaryLabel: string = ''
  onPrimary: () => void = () => {}
  onSecondary: () => void = () => {}

  build() {
    if (this.visible) {
      Column({ space: 14 }) {
        Text(this.win ? '🎉' : '💦')
          .fontSize(44)
        Text(this.title)
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        if (this.detail !== '') {
          Text(this.detail)
            .fontSize(13)
            .fontColor($r('app.color.ink_light'))
            .lineHeight(20)
            .textAlign(TextAlign.Center)
        }
        Row({ space: 12 }) {
          if (this.secondaryLabel !== '') {
            GhostBtn({ label: this.secondaryLabel, onTap: () => this.onSecondary() })
          }
          PrimaryBtn({ label: this.primaryLabel, onTap: () => this.onPrimary() })
        }
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .height('100%')
      .padding(28)
      .backgroundColor('rgba(23,20,15,0.72)')
      .borderRadius(20)
    }
  }
}

/** 小标签 */
@Component
export struct Tag {
  @Prop label: string = ''
  @Prop tone: string = 'plain'

  build() {
    Text(this.label)
      .fontSize(11)
      .fontColor(this.tone === 'gold' ? $r('app.color.gold')
        : (this.tone === 'red' ? $r('app.color.cinnabar')
          : (this.tone === 'jade' ? $r('app.color.jade_ok') : $r('app.color.ink_light'))))
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .backgroundColor($r('app.color.wash'))
      .borderRadius(8)
  }
}
