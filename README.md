# 玩趣 🎲 益智游戏盒子

> HarmonyOS（ArkTS / Stage 模型）离线小游戏合集：一个 app，八个游戏。

## 游戏一览

| 批次 | 游戏 | 玩法核心 | 技术亮点 |
| --- | --- | --- | --- |
| 一 | 🔩 拧螺丝 | 层叠板件、分色收纳、板件坠落 | 关卡程序生成，覆盖/坠落规则引擎 |
| 一 | 9️⃣ 数独 | 四档难度 + 每日一题 | 回溯求解 + 挖洞唯一解校验 + MRV 剪枝 |
| 一 | 🔗 连连看 | 两折连通消除 | ≤2 折点寻路 + 可解性模拟 + 死局重排 |
| 二 | 🧱 方块消除 | 8×8 拖放、整行整列消 | 19 种块形 + 连击计分 + 死局判定 |
| 二 | 🔮 球球排序 | 同色入管归位 | 已解局面逆向打乱，必可解 + 无限撤销 |
| 三 | 🖼️ 数织 | 行列线索推理像素画 | 行解法器校验（可纯逻辑推出） |
| 三 | 🚗 挪车出道 | 滑车给红车清路 | BFS 求解器验证关卡并给出最少步数 |
| 三 | 🀄 华容道 | 五大经典布局 | 字符画布局库 + 最优步数参考 |

全部离线可玩；成绩/进度保存在本机（Preferences）。大厅展示每个游戏的历史最佳。

## 构建

依赖 DevEco Studio 6.1.1+。命令行构建：

```bash
./scripts/build.sh       # 未签名 HAP
./scripts/install-phone.sh  # 签名打包 + hdc 装机（需先在 DevEco 自动签名一次）
./scripts/make-icon.mjs 216 <out.png>   # 重新生成图标
```

## 工程结构

```
WanQu/
├── AppScope/                  应用配置 + 图标
├── entry/src/main/ets/
│   ├── entryability/          EntryAbility（启动加载成绩）
│   ├── model/Types.ets        游戏元信息 / 记录类型
│   ├── store/GameStore.ets    成绩持久化（Preferences + AppStorage）
│   ├── components/Common.ets  顶栏 / 按钮组 / 结果浮层 / 标签
│   ├── pages/Index.ets        大厅（游戏网格 + 战绩）
│   └── games/                 每游戏 = Engine(纯逻辑) + Page(交互)
│       ├── screw/  sudoku/  link/        第一批
│       ├── block/  ballsort/             第二批
│       └── nonogram/  parking/  klotski/ 第三批
└── scripts/                   build / install / icon
```

引擎与 UI 分离：Engine 全部纯函数/纯数据结构，可独立单测；Page 只做交互与动画。

## License

MIT
