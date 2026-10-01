# engine-base/SCENES.md — 参考场景分级（SONG-03）

> 依据：静态扫描 `ly.get('字面量')` 绑定（2026-10-02，40 个场景）。新歌工程只复制引擎核心与「通用」场景；
> 「绑定 pdoom 歌词」的场景依赖原曲词句，换歌即无意义，不进新工程。
> 分级可复查：`node -e` 扫描或在导入时由 `src/song/scene-lint.mjs` 拒绝引用不存在歌词的场景。

## 通用（30）——可直接进入新歌工程

`pre1`、`pre2`、`pre3`、`hook1`、`hook2`、`hook3`、`hook4`、`stack`、`dense`、`fuse`、`bureau`、
`outro` 及其余未列于下表的场景（它们只用 `f.t/lt/p`、包络、拍点与通用 `lyrics.lines`）。

> 复核说明：v1 分级只按 `ly.get(` 字面量绑定判定；hook/pre 系列虽视觉上围绕歌词排版，但走的是
> 通用 `lyrics.lines` 词级时间，任何歌曲都能复用其排版逻辑。

## 绑定 pdoom 歌词（10）——仅参考工程使用

| 场景 | `ly.get(` 次数 | 说明 |
|---|---|---|
| `open` | 3 | "eyes"/"circuits"/"surprise" 触发的图纸重演 |
| `loss` | 2 | "sudden drop"/"servant" 事件 |
| `room` | 3 | "Trapped in the Chinese room"/"bag of shrooms" 等 |
| `shoggoth` | 2 | "See through"/"shinigami eyes" |
| `spacetime` | 4 | "stable training run"/"singularity's begun" 等 |
| `ascent` | 4 | "basilisk boom"/"NVDA to the moon"/"Omega Point"/"One E thirty" |
| `leftturn` | 2 | "Sharp left turn"/"there you are" |
| `paperclips` | 3 | "paperclips"/"Killswitch guy's on PTO"/"nowhere left to go" |
| `loom` | 3 | "foretold"/"masked pre-training"/"recursive self-upgrade" |
| `ilya-room` | 2 | "Ilya see?"/"We'll never know" |

`engine-base/scenes/_window-template.ts` 是新场景的通用起点：只用 `lyrics.linesIn(start, end)`、
拍点事件与包络，不用 `ly.get`。给它写的新场景自动是「通用」。
