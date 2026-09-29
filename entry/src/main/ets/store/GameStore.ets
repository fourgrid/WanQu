/**
 * 玩趣 - 成绩/进度持久化
 * 记录经 AppStorage 中转（key: game_<id>），UI 用 @StorageLink 响应。
 */
import preferences from '@ohos.data.preferences'
import common from '@ohos.app.ability.common'
import { GameRecord } from '../model/Types'

export class GameStore {
  private static store: preferences.Preferences | null = null

  static async init(context: common.Context): Promise<void> {
    GameStore.store = await preferences.getPreferences(context, 'wanqu_store')
    // 恢复所有游戏记录到 AppStorage
    const ids = ['screw', 'sudoku', 'link', 'block', 'ballsort', 'nonogram', 'parking', 'klotski']
    for (const id of ids) {
      const s = GameStore.store.getSync(`game_${id}`, '') as string
      if (s !== '') {
        try {
          const r = JSON.parse(s) as GameRecord
          AppStorage.setOrCreate(`game_${id}`, r)
        } catch (e) {
          // 忽略损坏数据
        }
      }
    }
  }

  static get(id: string): GameRecord {
    const r = AppStorage.get<GameRecord>(`game_${id}`)
    if (r) {
      return r
    }
    return { bestScore: 0, bestLevel: 0, playCount: 0, extra: '' }
  }

  static update(id: string, mutate: (r: GameRecord) => GameRecord): void {
    const next = mutate(GameStore.get(id))
    AppStorage.setOrCreate(`game_${id}`, next)
    if (GameStore.store) {
      GameStore.store.putSync(`game_${id}`, JSON.stringify(next))
      GameStore.store.flush()
    }
  }

  /** 记录一次游玩（次数+1），顺带更新附加数据 */
  static recordPlay(id: string, extra?: string): void {
    GameStore.update(id, (r): GameRecord => {
      const nr: GameRecord = {
        bestScore: r.bestScore,
        bestLevel: r.bestLevel,
        playCount: r.playCount + 1,
        extra: extra ?? r.extra,
      }
      return nr
    })
  }

  static recordScore(id: string, score: number, level?: number): void {
    GameStore.update(id, (r): GameRecord => {
      const nr: GameRecord = {
        bestScore: Math.max(r.bestScore, score),
        bestLevel: Math.max(r.bestLevel, level ?? 0),
        playCount: r.playCount,
        extra: r.extra,
      }
      return nr
    })
  }
}
