/**
 * 玩趣 - 公共类型
 */

/** 游戏标识 */
export type GameId = 'screw' | 'sudoku' | 'link' | 'block' | 'ballsort' | 'nonogram' | 'parking' | 'klotski'

/** 游戏元信息 */
export interface GameMeta {
  id: string
  name: string
  batch: number          // 第几批
  accent: string         // 签名色（卡片描边/强调）
  tagline: string        // 一句话
}

/** 大厅游戏列表 */
export const GAMES: GameMeta[] = [
  { id: 'screw', name: '拧螺丝', batch: 1, accent: '#4285F4', tagline: '层叠板件 · 分色收纳' },
  { id: 'sudoku', name: '数独', batch: 1, accent: '#2ECC71', tagline: '四档难度 · 每日一题' },
  { id: 'link', name: '连连看', batch: 1, accent: '#9B59B6', tagline: '两折连通 · 经典对对碰' },
  { id: 'block', name: '方块消除', batch: 2, accent: '#3498DB', tagline: '整行整列 · 连击加分' },
  { id: 'ballsort', name: '球球排序', batch: 2, accent: '#E67E22', tagline: '同色入管 · 必有解' },
  { id: 'nonogram', name: '数织', batch: 3, accent: '#1ABC9C', tagline: '线索推理像素画' },
  { id: 'parking', name: '挪车出道', batch: 3, accent: '#E74C3C', tagline: '滑车清路 · 送主车出库' },
  { id: 'klotski', name: '华容道', batch: 3, accent: '#F1C40F', tagline: '五大经典布局' },
]

/** 单局成绩记录 */
export interface GameRecord {
  bestScore: number
  bestLevel: number
  playCount: number
  extra: string            // 各游戏自定义附加数据(JSON)
}
