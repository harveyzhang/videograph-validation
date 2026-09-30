// reference-plan.mjs — 导入器的镜头映射，与参考 timeline.ts 的歌词锚点/节拍切点一致。
// 这是已存在工程的导入，不冒充 AI 新生成的镜头。
export function referenceShots(song) {
  const definitions = [
    ['open', 'open', null, '火花绘图'],
    ['loss', 'loss', 'There was a sudden drop', '训练损失骤降'],
    ['prompt1', 'prompt', 'ChatGPT, please', '第一次恳求', { variant: 'chatgpt' }],
    ['hook1', 'hook', "I'm upping", '第一次副歌', { n: 1 }, 0],
    ['room', 'room', "'cause the future goes FOOM", '中文房间'],
    ['shoggoth', 'shoggoth', 'See through the shoggoth', '面具下的怪物'],
    ['spacetime', 'spacetime', 'We had a stable', '时空与奇点'],
    ['prompt2', 'prompt', 'Sydney', '第二次恳求', { variant: 'sydney' }],
    ['hook2', 'hook', "I'm upping", '第二次副歌', { n: 2 }, 1],
    ['ascent', 'ascent', 'I hear the basilisk', '升维'],
    ['bureau', 'bureau', 'That was safe enough', '安全公文'],
    ['leftturn', 'leftturn', 'Sharp left turn', '意外左转'],
    ['prompt3', 'prompt', 'Gato', '第三次恳求', { variant: 'gato' }],
    ['hook3', 'hook', "I'm upping", '第三次副歌', { n: 3 }, 2],
    ['paperclips', 'paperclips', 'as paperclips', '回形针宇宙'],
    ['fuse', 'fuse', 'Too late now', '燃烧的引信'],
    ['stack', 'stack', 'transformers all the way', '深栈'],
    ['dense', 'dense', 'Post-Chinchilla', '极限密度', {}, 0, 0.05],
    ['hook4', 'hook', "I'm upping", '最终副歌', { n: 4 }, 3],
    ['loom', 'loom', 'Just as foretold', '织机预言'],
    ['ilya', 'ilya', 'What did Ilya', '未曾说破'],
    ['outro', 'outro', null, '引爆与重生成'],
  ];
  const normal = (text) => text.toLowerCase().replace(/[’']/g, "'");
  const shots = definitions.map(([id, module, query, title, params = {}, nth = 0, tolerance = 0.02]) => {
    let start = 0;
    if (id === 'outro') start = song.sections.find((section) => section.name === 'outro').start;
    else if (query) {
      const line = song.lines.filter((entry) => normal(entry.text).includes(normal(query)))[nth];
      if (!line) throw new Error(`导入镜头 ${id}：歌词锚点未匹配`);
      const wordStart = line.words[0].start + tolerance;
      start = [...song.beats].reverse().find((beat) => beat <= wordStart) ?? 0;
    }
    return { id, module, title, start, end: 0, params, prompt: `导入参考工程：${title}。当前使用原始场景源码，尚未由 AI 改写。`, inputRevision: 0, source: 'reference-import', status: 'imported', locked: false };
  });
  return shots.map((shot, index) => ({ ...shot, end: shots[index + 1]?.start ?? song.duration }));
}
