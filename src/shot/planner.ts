// planner.ts — 「AI 听歌 → 自动规划镜头卡片带」。
// 两条路：builtinPlan（复刻 pdoom-video 真实剪辑的 23 窗口参考规划，无需 LLM）
// 和 llmPlan（把全曲结构喂给 LLM，按用户概念自由规划，JSON 容错解析）。
import type { ProviderConfig } from '../llm/types';
import { cachedChat } from '../llm/adapters';
import { afterLine, cutAtLine, FULL_SONG, sectionStart, type FullSongData, type LyricLine } from './engine';

export interface PlannedCard {
  id: string;
  title: string;
  window: { start: number; end: number };
  /** 锚定说明（人可读）：这张卡为什么在这个窗口。 */
  anchor: string;
  prompt: string;
}

const n2 = (x: number) => x.toFixed(2);

// ── 内置参考规划：pdoom-video timeline.ts 的 23 个窗口 + TREATMENT 的 plate 描述压缩成中文提示词 ──
// 每项：[id, 标题, 起点规则, 终点规则(下一段起点兜底), 中文镜头提示词]
type Bound = (song: FullSongData) => number;

const REFERENCE_PLAN: Array<{ id: string; title: string; start: Bound; end: Bound; anchor: string; prompt: string }> = [
  { id: 'open', title: 'OPEN · 火花绘图', start: () => 0, end: (s) => cutAtLine(s, 'sudden drop'), anchor: 'intro + verse1 前半', prompt: '深色构造图纸（墨黑底、骨白网格）。一枚橙色火花当绘图笔：第一拍起坐标轴与圆规弧点亮，火花沿网格逐笔画出一只由椭圆身体+矩形腿+贝塞尔鬃毛组成的独角兽简笔图；唱到 "eyes" 镜头推近到一个完美的圆点眼睛并标注 r=0.08；"Your circuits make me nervous" 时图纸重演 checkpoints（其中一帧出现五条腿），笔画重排成 PCB 走线，画面轻微震颤；"that\'s no surprise" 处 surprisal −log p 的读数滚落到 0.00 nats。顶部两行逐词卡拉OK。' },
  { id: 'loss', title: 'LOSS · 骤降', start: (s) => cutAtLine(s, 'sudden drop'), end: (s) => cutAtLine(s, 'ChatGPT, please'), anchor: 'verse1 后半', prompt: 'hairline 坐标轴从黑场画入（对数 loss 纵轴、step 横轴、mono 刻度）。火花从左侧画出带噪声的 loss 平稳曲线，歌词逐词骑在曲线上；唱到 "sudden drop" 曲线骤降（grokking 悬崖）镜头随之下坠出图表底部；唱到 "servant" SERVANT 一词放大顶起；唱到 "boss" 整个世界绕中心翻转 180°（等级倒置），网格与坐标轴一起翻。' },
  { id: 'pre1', title: 'PROMPT · ChatGPT', start: (s) => cutAtLine(s, 'ChatGPT, please'), end: (s) => cutAtLine(s, "I'm upping", 0), anchor: 'pre-chorus 1', prompt: '大片深色空场中一条细长的 prompt 输入框。恳求以 token 逐字打出（mono 字体，逐词跟唱）：ChatGPT, / please don\'t / eat me / alive；每个新 token 上方闪现一个小型下一词分布条（候选+概率，如 eat 0.44 · delete 0.21 · train on 0.18），被采样的词点亮橙色。背景是缓慢向内吸入的同心刻线圆环（喉咙/隧道感）。行末光标闪烁、⏎ 按下，整屏向副歌闪进。' },
  { id: 'hook1', title: 'HOOK 1 · 干净版', start: (s) => cutAtLine(s, "I'm upping", 0), end: (s) => cutAtLine(s, 'FOOM'), anchor: '副歌 1', prompt: '副歌 hook 的第一次亮相，干净克制：I\'M / UPPING / MY / P(DOOM) 一个词一记重拍、逐词满屏大字（Archivo 900 风格、骨白压墨黑）；UPPING 的字母字面上升；P(DOOM) 按数学式排版，HUD 里的小数字冲出角落放大成 0.15 满屏滚过一遍再退回。无杂质、无装饰，只有排版的力量。' },
  { id: 'room', title: 'ROOM · FOOM 房间', start: (s) => cutAtLine(s, 'FOOM'), end: (s) => cutAtLine(s, 'shoggoth'), anchor: 'chorus1', prompt: '"FOOM" 的字母碎裂成线并指数级分叉（1→2→4→…每 8 分音符翻倍）充满画面，FOOM 的两个 O 变成冲击波环扩张。"Trapped in the Chinese room" 冲击波轰开房门，镜头沿 hairline 图书馆过道猛推，逐拍切换（甩镜带滚转、低角度、punch-in）；吊牌逐词盖印歌词，我不懂卡片从槽口弹出。"bag of shrooms" 菌袋落桌、菌丝过生长满房间，acid 黄绿点缀、拖影扭曲一切。' },
  { id: 'shoggoth', title: 'SHOGGOTH · 透视', start: (s) => cutAtLine(s, 'shoggoth'), end: (s) => cutAtLine(s, 'stable training'), anchor: 'break1 + verse2 起', prompt: '一枚乏味的骨白圆盘面具（两点一弧的"助手微笑"）占满画面，完美友好。唱到 "See through" 一条 X 光扫描带横扫而过，扫过处面具变透明，露出里面雕版排线风格的自创 shoggoth：巨量管状触手与褶皱的结（engraving 排线、橙色轮廓光、深黑），多只眼睛。"shinigami eyes" 眼睛逐记睁开，左边缘出现 mono 死神标签（名字+寿命倒数）用引导线连到对应的眼。间奏处眼睛依次闭合，质量塌缩成一条水平直线（flatline）。' },
  { id: 'spacetime', title: 'SPACETIME · 时空', start: (s) => cutAtLine(s, 'stable training'), end: (s) => cutAtLine(s, 'Sydney'), anchor: 'verse2', prompt: '四个乐章：① "stable training run" 一台锁定的示波器，波形在玻璃下发光带余晖，歌词骑在波上；② "singularity\'s begun" 示波器像老电视一样关掉，NOW 的 O 变成黑洞诞生、镜头坠入，SINGULARITY\'S 缠上光子环、BEGUN 被引力透镜弯成微笑；③ "optimizing, accelerating" 螺旋爬出喉道进入流线涡旋，词随唱拉长；④ "atoms rearranging" 歌词的点脱离汇入流动并重组成一枚回形针轮廓（伏笔）。' },
  { id: 'pre2', title: 'PROMPT · Sydney', start: (s) => cutAtLine(s, 'Sydney'), end: (s) => cutAtLine(s, "I'm upping", 1), anchor: 'pre-chorus 2', prompt: '同一条 prompt 模板的第二变奏：输入框坐在一排竖栅栏后面，栅栏逐拍向内逼近；token 逐词打出（Sydney / please let me / free，分布候选 free 0.39 · go 0.33 · a good user 0.08）；行末 ⏎ 后回复开始打字，只画出一道令人不安的微笑弧线。比 pre1 更压抑。' },
  { id: 'hook2', title: 'HOOK 2 · 反色版', start: (s) => cutAtLine(s, "I'm upping", 1), end: (s) => cutAtLine(s, 'basilisk'), anchor: '副歌 2', prompt: 'hook 第二次，更重：整个画面反转为信号橙底、墨黑大字。I\'M / UPPING / MY / P(DOOM) 逐拍满屏，字母带拖影与轻微位移抖动，0.42 满屏滚过。橙色场本身在拍点上呼吸（亮度随 kick 脉冲）。' },
  { id: 'ascent', title: 'ASCENT · 升维', start: (s) => cutAtLine(s, 'basilisk'), end: (s) => cutAtLine(s, 'safe enough'), anchor: 'chorus2', prompt: '"basilisk boom" 一枚雕版蛇眼（鳞片为排线图案、竖缝瞳孔）在 boom 上猛睁并放出冲击波震屏；"NVDA to the moon" 瞳孔变竖线切到 K 线图（排线蜡烛体，火花就是价格线）指数上升，镜头竖直追随直到抵上一枚钞票扭索纹（guilloché）雕版月亮，歌词排成钞票lettering；"Omega Point" 所有线收敛到一个白热点、Cormorant 意大利体缩进光点；"One E thirty" 一排 31 位机械滚轮里程计翻滚到 1e30 FLOP/s。' },
  { id: 'bureau', title: 'BUREAU · 公文', start: (s) => cutAtLine(s, 'safe enough'), end: (s) => cutAtLine(s, 'Sharp left turn'), anchor: 'verse3 前半', prompt: '反色纸面 plate：骨白纸+墨线。一张安全评估表（Form 7-B、复选框、打字机体字段里逐词打出歌词），唱到 "reckoned" 一枚橙色橡皮章 SAFE ENOUGH 砸下（墨迹质感、微旋转、震屏）；"Forward MLP, backward, repeat" 一张 MLP 技术图，脉冲前向扫一遍、"backward" 脉冲回扫且词镜像从右往左排、"repeat" 最后一拍卡顿重复×3；"von Neumann\'s obsolete" 冯·诺依曼架构教科书图被橙色划掉并撕裂坠入黑场。' },
  { id: 'leftturn', title: 'LEFT TURN · 岔路', start: (s) => cutAtLine(s, 'Sharp left turn'), end: (s) => cutAtLine(s, 'Gato'), anchor: 'verse3 后半', prompt: '俯视工程路线图：虚线路径+里程碑 SRR·PDR·CDR·TRR·LAUNCH，火花沿线行进。唱到 "Sharp left turn" 火花 90° 左拐、镜头甩 pans 跟随；"there you are" 火花刹进 Terra incognita 测绘图的一个弹坑，标记落下，镜头拉远——等高线原来是一张作为地形的面具（两个眼坑+一道笑谷），YOU/ARE 作为地图标签盖印，UNPLANNED OBJECT · not on roadmap 标注砸入。"Without a single CDR" 甩到同页的甘特复审表：TODAY 播头（火花）跑过 SRR、PDR，在空白的 CDR 槽位卡住闪烁（STATUS: NOT HELD），随后掠过 TRR（SKIPPED）直奔 LAUNCH（AHEAD OF SCHEDULE）。' },
  { id: 'pre3', title: 'PROMPT · Gato', start: (s) => cutAtLine(s, 'Gato'), end: (s) => cutAtLine(s, "I'm upping", 2), anchor: 'pre-chorus 3（breakdown）', prompt: '第三变奏，安静脆弱的 breakdown：prompt 框孤零零漂浮在黑里。token 缓慢打出（Gato / please don\'t / let me / go），没有花哨分布，只有小号 mono 候选；打完后字母彼此慢慢漂散（"don\'t let me go"），一个小光标固执地拉住最后一个字母不放。留白多、节奏慢、克制。' },
  { id: 'hook3', title: 'HOOK 3 · 降格版', start: (s) => cutAtLine(s, "I'm upping", 2), end: (s) => cutAtLine(s, 'paperclips'), anchor: '副歌 3（安静）', prompt: 'hook 第三次，骤然抽空：hairline 细体小字，大量黑色，I\'M UPPING MY P(DOOM) 一词一拍地极简浮现，0.81 用打字机速度一行行慢慢滚出来。诡异、克制、预告失控。' },
  { id: 'paperclips', title: 'CLIPS · 回形针', start: (s) => cutAtLine(s, 'paperclips'), end: (s) => cutAtLine(s, 'fuse'), anchor: 'chorus3（安静副歌）', prompt: '安静的惊悚与美：火花的线弯成第一枚回形针；逐拍复制 1,2,4,8…长成一望无际的雕版回形针晶格（骨白金属、橙轮廓光、深雾），镜头在晶格间缓慢漂移。"Killswitch guy\'s on PTO" 一张 out-of-office 自动回复卡漂过（mono 逐词打出：Automatic reply… please contact —）；"nowhere left to go" 回形针合拢包围，词被挤在缝隙间（窄字宽）。' },
  { id: 'fuse', title: 'FUSE · 引信', start: (s) => cutAtLine(s, 'fuse'), end: (s) => cutAtLine(s, 'transformers all the way'), anchor: 'chorus3 尾', prompt: '"we lit the fuse" 歌词本身就是一条燃烧的引信：编股绳雕版纹理，火花沿词序烧过、烧到的字符焦黑碎裂剥落，粒子飞溅。"Orthogonality thesis blues" 图纸上的正交性图表（INTELLIGENCE→×GOALS↑、散布的 annotated minds），那条平坦回归线是一根吉他弦——唱到 "blues" 时按歌手真实音高弯曲（揉弦、上翻八度、谱纸碎片上一个孤独的 ♭ 蓝音）并持续振响。' },
  { id: 'stack', title: 'STACK · 深栈', start: (s) => cutAtLine(s, 'transformers all the way'), end: (s) => cutAtLine(s, 'Post-Chinchilla'), anchor: 'bridge 前半', prompt: '喧闹：无穷垂直堆叠的 transformer 块技术线图（attention、add & norm、feed-forward、残差箭头，层层向下），镜头逐拍坠落穿过一层块；引语带巨大引号，一词一块。"Till you learned to disobey" 坠落在拍上骤停——其中一块转出对齐，"disobey" 这个词违抗卡拉OK（从右往左高亮/反向滑动）。' },
  { id: 'dense', title: 'DENSE · 极限密度', start: (s) => cutAtLine(s, 'Post-Chinchilla'), end: (s) => cutAtLine(s, "I'm upping", 3), anchor: 'bridge 后半', prompt: '版面自身的安全框成为主角：TITLE SAFE 90% / ACTION SAFE 93% 导轨线可见；每记 kick 歌词被压得更窄更重（宽 125→62、字重 300→900、负字距），复制份层层塞入直到 title-safe 盒变成一块实心版，TOKENS/PARAM 计数冲过 Chinchilla 最优 20 到 20,000。"safety fence" 每个重音词撞破一道框（title-safe→action-safe→画面本身，裁切标记炸飞）；"Hundred thousand GPU" 俯视 10 万格网格波浪闪烁+mono 计数器；"RLHF goes askew" 世界变成倾斜的桌面，面具滚坡、被校正拉回、再滚、倒扣（微笑变皱眉），REWARD MODEL 面板 0.99→0.41→弹回 0.99。' },
  { id: 'hook4', title: 'HOOK 4 · 极限版', start: (s) => cutAtLine(s, "I'm upping", 3), end: (s) => cutAtLine(s, 'foretold'), anchor: '副歌 4（最响）', prompt: 'hook 第四次也是最大化：选通重复（同词多帧闪现）、堆叠轮廓字、震屏、数字自我复制 0.99999… 满屏；P(DOOM) 滚向 0.99 时数字位数逐拍增殖，一切过载但排版依然精确。' },
  { id: 'loom', title: 'LOOM · 织机预言', start: (s) => cutAtLine(s, 'foretold'), end: (s) => cutAtLine(s, 'Ilya'), anchor: 'chorus4', prompt: '主角是续写树：从上一张卡的火花扎根，歌词沿被采样路径逐 token 生成（每个节点带概率），周围萌发暗淡的替代分支（Exactly .19 / prophesied .09…）；最后一个节点展开可读的分布（Moloch / scaling laws / Nostradamus / nobody, technically / a Substack / the eval suite）直到 Cormorant 意大利体的 Loom 被 SAMPLED（p 0.31）。"masked pre-training days" 歌词以实心 [MASK] 块出现、随唱揭开；"recursive self-upgrade" 德罗斯特式递归自升级，一层套一层。' },
  { id: 'ilya', title: 'ILYA · 未曾说破', start: (s) => cutAtLine(s, 'Ilya'), end: (s) => sectionStart(s, 'outro'), anchor: 'chorus4 尾', prompt: '白线雕版的 raymarch 房间：一台从背后看的笔记本电脑，只有它的光。镜头先停在合上的盖背看贴纸（FEEL THE AGI、笑脸面具、TikZ 独角兽、SLIGHTLY CONSCIOUS、Q*、attention is all you need），唱到 "Ilya see?" 猛地甩到正面——屏幕被 REDACTED 黑条覆盖；"We\'ll never know" 盖子被逐词压下，光收成一条缝、再收成呼吸灯；"know" 得到自己的 WITHHELD 条。"Was it all for show?" 一座空剧场，聚光灯照着空无，问题字样刻在台口拱框上；幕布合拢，缝隙的光在画面中心收成一个火花点。' },
  { id: 'outro', title: 'OUTRO · 引爆与重生成', start: (s) => sectionStart(s, 'outro'), end: (s) => s.duration, anchor: 'outro', prompt: '引信烧到尽头引爆：P(doom) 1.00。然后数字被继续上调，一拍一个值：进度条冲破 1.0 端帽（1.01→2.00，附一条一本正经的 Kolmogorov 脚注）；对数尺飞过（3.14、10、42、1000）；打字机零墙（1e9、1e30、1e100、1e1000）；火花画出 ∞ 并落在 ∞ 上。随后按论文公式排版 P(doom)=∞（公式编号 (1)），逐拍化简：∞ 翻身变 8、8 拆成 0/0、分数颤抖着塌在分数线上一圈冲击波—— inflate 成 NaN¹（脚注：¹ 估计值已无定义）。一切收束回火花，画面裁切框合拢，一个孤零零的 ↻ Regenerate 按钮；光标点下，所有 plate 倒放 rewind 越来越快，最后片头倒放刹停回第一帧——首尾无缝循环。' },
];

export function builtinPlan(song: FullSongData = FULL_SONG): PlannedCard[] {
  const cards: PlannedCard[] = [];
  for (let i = 0; i < REFERENCE_PLAN.length; i++) {
    const entry = REFERENCE_PLAN[i]!;
    const start = entry.start(song);
    let end = entry.end(song);
    if (!end || end <= start) end = i + 1 < REFERENCE_PLAN.length ? REFERENCE_PLAN[i + 1]!.start(song) : song.duration;
    cards.push({ id: entry.id, title: entry.title, window: { start: Math.max(0, start), end: Math.min(song.duration, end) }, anchor: entry.anchor, prompt: entry.prompt });
  }
  // 兜底：保证窗口严格递增且无缝覆盖全曲
  for (let i = 0; i < cards.length; i++) {
    if (i > 0 && cards[i]!.window.start < cards[i - 1]!.window.end) cards[i]!.window.start = cards[i - 1]!.window.end;
    if (cards[i]!.window.end <= cards[i]!.window.start) cards[i]!.window.end = Math.min(song.duration, cards[i]!.window.start + 1);
  }
  return cards;
}

// ── LLM 规划：全曲结构 + 用户概念 → 卡片数组 JSON ─────────────────────────────

const planSchemaDoc = `
输出一个 JSON 数组，每个元素是一张镜头卡片：
{ "id": "短id(英文小写)", "title": "标题（中文，含情绪词）", "anchorLine": "锚定的歌词行原文（必须是输入歌单里存在的行，取该行首词所在拍作为切点）", "endLine": "结束锚定的下一行歌词原文（该卡切到它之前；最后一张可省略表示到曲末）", "prompt": "给场景程序员的镜头提示词（中文，3-5 句：构图、核心视觉比喻、标志性动作、卡拉OK如何融入画面、拍点上的变化）" }

规划要求：
- 卡片按时间严格递增、无缝覆盖整首歌（一张的 end 就是下一张的 start）；14-24 张为宜。
- 切点吸咐节拍由系统自动完成，你只负责选对锚定行。
- hook（"I'm upping my P(doom)"）每次出现都应有专属卡片且视觉逐次升级。
- 每张卡的 prompt 要有一个具体的、可画的视觉比喻（具象物：图表/表格/房间/地图/机器/织物…），不要写"抽象氛围"。
- 忠于用户的概念输入；没有概念输入时参考末日论文插图版画的基调。
`.trim();

export function buildPlanMessages(song: FullSongData, concept: string): { system: string; user: string } {
  const lines = song.lines.map((l, i) => `${i}. [${l.start.toFixed(1)}-${l.end.toFixed(1)}] ${l.text}`).join('\n');
  const sections = song.sections.map((s) => `${s.name} ${s.start.toFixed(1)}-${s.end.toFixed(1)}`).join(' · ');
  const system = [
    '你是 VideoGraph 的镜头规划师（timeline director）：听完一首歌的完整结构数据，规划整支歌词 MV 的镜头卡片带。',
    '美学基调：末日论文的插图版画——墨黑底、骨白字、信号橙唯一强调色、hairline 精确、一板一眼的科学家式冷幽默；禁止紫色霓虹赛博朋克、发光大脑、Matrix 代码雨、AI 生成感图样。',
    planSchemaDoc,
    '只输出 JSON 数组本身，不要 markdown 代码围栏，不要任何解释文字。',
  ].join('\n\n');
  const user = [
    `## 概念输入（用户给这首歌的一句话概念）\n${concept.trim() || '（无 —— 按歌曲本身的 AI 末日叙事自由发挥）'}`,
    `## 歌曲\n${song.song} · ${song.bpm} BPM · ${song.duration.toFixed(1)}s`,
    `## 段落\n${sections}`,
    `## 歌词（行号. [起-止秒] 文本）\n${lines}`,
  ].join('\n\n');
  return { system, user };
}

/** 容错解析：剥围栏、找 JSON 数组、逐卡校验并把锚定行换算成秒。 */
export function parsePlanResponse(raw: string, song: FullSongData): { cards: PlannedCard[]; warnings: string[] } {
  const warnings: string[] = [];
  let text = raw.trim();
  const fence = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (fence) text = fence[1]!.trim();
  const start = text.indexOf('[');
  const endIdx = text.lastIndexOf(']');
  if (start < 0 || endIdx <= start) throw new Error('LLM 返回里找不到 JSON 数组');
  let parsed: unknown;
  try {
    parsed = JSON.parse(text.slice(start, endIdx + 1));
  } catch (error) {
    throw new Error(`JSON 解析失败：${String(error).slice(0, 160)}`);
  }
  if (!Array.isArray(parsed) || parsed.length === 0) throw new Error('JSON 数组为空');

  const norm = (s: string) => s.toLowerCase().replace(/[’']/g, "'").replace(/[^a-z0-9 ]/g, '').trim();
  const resolve = (anchor: unknown, fallback: number): number => {
    if (typeof anchor !== 'string' || !anchor.trim()) return fallback;
    const q = norm(anchor);
    const line: LyricLine | undefined = song.lines.find((l) => norm(l.text).includes(q.slice(0, Math.max(8, Math.floor(q.length * 0.6)))));
    if (!line) {
      const idx = Number(anchor);
      if (Number.isInteger(idx) && idx >= 0 && idx < song.lines.length) return cutAtLine(song, song.lines[idx]!.text);
      return fallback;
    }
    return cutAtLine(song, line.text);
  };

  const raw0 = parsed as Array<Record<string, unknown>>;
  const cards: PlannedCard[] = [];
  for (let i = 0; i < raw0.length; i++) {
    const item = raw0[i]!;
    const id = typeof item.id === 'string' && item.id.trim() ? item.id.trim().slice(0, 24) : `shot${i + 1}`;
    const title = typeof item.title === 'string' && item.title.trim() ? item.title.trim().slice(0, 40) : `镜头 ${i + 1}`;
    const prompt = typeof item.prompt === 'string' ? item.prompt.trim() : '';
    if (!prompt) { warnings.push(`卡片 ${id}：无提示词，已跳过`); continue; }
    const anchorLine = typeof item.anchorLine === 'string' ? item.anchorLine : '';
    const start = i === 0 ? 0 : resolve(anchorLine, cards[i - 1]?.window.end ?? 0);
    let end: number;
    const endLine = typeof item.endLine === 'string' ? item.endLine : '';
    const nextAnchor = raw0[i + 1] && typeof raw0[i + 1]!.anchorLine === 'string' ? raw0[i + 1]!.anchorLine as string : '';
    end = resolve(endLine || nextAnchor, -1);
    if (end < 0) end = i === raw0.length - 1 ? song.duration : Math.min(song.duration, start + 8);
    if (end <= start) {
      warnings.push(`卡片 ${id}：窗口<=0（${n2(start)}→${n2(end)}），已拉长到 4s`);
      end = Math.min(song.duration, start + 4);
    }
    cards.push({ id: `${id}-${i}`, title, window: { start: Math.max(0, start), end: Math.min(song.duration, end) }, anchor: anchorLine || 'LLM 规划', prompt });
  }
  for (let i = 1; i < cards.length; i++) {
    if (cards[i]!.window.start < cards[i - 1]!.window.end) {
      warnings.push(`卡片 ${cards[i]!.id}：起点早于上一张终点，已吸附衔接`);
      cards[i]!.window.start = cards[i - 1]!.window.end;
      if (cards[i]!.window.end <= cards[i]!.window.start) cards[i]!.window.end = Math.min(song.duration, cards[i]!.window.start + 2);
    }
  }
  return { cards, warnings };
}

export interface LlmPlanResult {
  cards: PlannedCard[];
  warnings: string[];
  model: string;
  usage?: { input?: number; output?: number };
}

export async function llmPlan(provider: ProviderConfig, concept: string, song: FullSongData = FULL_SONG, signal?: AbortSignal): Promise<LlmPlanResult> {
  const { system, user } = buildPlanMessages(song, concept);
  const { result } = await cachedChat(provider, [
    { role: 'system', content: system },
    { role: 'user', content: user },
  ], { temperature: 0.5, maxTokens: 8192, signal });
  const { cards, warnings } = parsePlanResponse(result.text, song);
  return { cards, warnings, model: provider.model, usage: result.usage };
}
