/*@effect
{
  "id": "beat-zoom-ladder",
  "name": "阶梯推镜",
  "kind": "post",
  "category": "运动与节拍",
  "tags": ["zoom", "step zoom", "beat", "punch in", "staircase", "阶梯推镜", "逐拍推进", "卡点", "放大"],
  "summary": "每一拍画面向中心推进一级（瞬间跳一下、不缓动），一个小节推 4 级，到小节结束再一下子弹回原始大小——像剪辑师在拍点上一刀一刀地“裁近”。",
  "when": "嘻哈/电子/流行的卡点段落、强调人物表情或产品细节、副歌前的蓄力。",
  "avoid": "画面边缘有重要内容时（推近会裁掉）；安静段落。",
  "params": {
    "stepZoom": { "type": "float", "default": 0.08, "min": 0.02, "max": 0.25, "label": "每拍推进量" },
    "steps": { "type": "float", "default": 4, "min": 2, "max": 8, "label": "每小节几级（通常 = 每小节拍数）" },
    "centerX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "推进中心 X" },
    "centerY": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "推进中心 Y" },
    "snap": { "type": "float", "default": 0, "min": 0, "max": 0.05, "label": "拍点冲击（通常由节拍驱动）" }
  },
  "bindings": { "snap": { "to": "kick", "amount": 0.015 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques 节奏与卡点：逐拍裁近", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（剪辑手法 “step zoom / punch-in ladder”）：同一个镜头，在每个拍点上剪一刀并把画面放大一级，
// 画面在拍点上一跳一跳地逼近主体；小节结束时切回全景，开始下一轮。比连续推镜更有节奏、更硬朗。
// 节拍：级数直接由小节相位决定（uBar × steps 取整），每一级在拍点上跳变；snap 再挂鼓点加一点冲击。

vec4 effect(vec2 uv) {
  float lvl = floor(uBar * steps);                          // 0..steps-1：本小节第几拍
  float z = 1. + lvl * stepZoom + snap;
  vec2 c = vec2(centerX, centerY);
  vec2 q = (uv - c) / z + c;
  return vec4(srcTex(q).rgb, 1.);
}
