/**
 * 玩趣 - 公共类型
 */

/** 游戏标识 */
export type GameId = 'screw' | 'sudoku' | 'link' | 'block' | 'ballsort' | 'nonogram' | 'parking' | 'klotski'

/** 游戏元信息 */
export interface GameMeta {
  id: string
  name: string
  glyph: string          // 大厅图标字符
  batch: number          // 第几批
  tagline: string        // 一句话
}

/** 大厅游戏列表 */
export const GAMES: GameMeta[] = [
  { id: 'screw', name: '拧螺丝', glyph: '🔩', batch: 1, tagline: '层叠板件 · 分色收纳 · 当红玩法' },
  { id: 'sudoku', name: '数独', glyph: '9️⃣', batch: 1, tagline: '四档难度 · 每日一题 · 唯一解' },
  { id: 'link', name: '连连看', glyph: '🔗', batch: 1, tagline: '经典对对碰 · 两折连通' },
  { id: 'block', name: '方块消除', glyph: '🧱', batch: 2, tagline: '8×8 拖放 · 整行消除 · 连击加分' },
  { id: 'ballsort', name: '球球排序', glyph: '🔮', batch: 2, tagline: '同色入管 · 逆向生成必可解' },
  { id: 'nonogram', name: '数织', glyph: '🖼️', batch: 3, tagline: '数字线索 · 推理像素画' },
  { id: 'parking', name: '挪车出道', glyph: '🚗', batch: 3, tagline: '滑动移车 · 送主车出库' },
  { id: 'klotski', name: '华容道', glyph: '🀄', batch: 3, tagline: '经典布局 · 步数挑战' },
]

/** 单局成绩记录 */
export interface GameRecord {
  bestScore: number
  bestLevel: number
  playCount: number
  extra: string            // 各游戏自定义附加数据(JSON)
}
