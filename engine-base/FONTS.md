# engine-base/FONTS.md — 字体资源登记（SONG-03）

> 参考引擎字体（Archivo/Cormorant/IBM Plex Mono）只有拉丁字形。新歌歌词是中文时必须登记并
> 子集化中文字体；字体文件**只放进工程目录**（`projects/<id>/engine/app/public/fonts/`），不提交仓库。

## 登记格式（工程 manifest 的 fonts 节点）

```json
{
  "fonts": [
    { "family": "Noto Sans SC", "file": "fonts/NotoSansSC-Bold.subset.otf", "hash": "<sha256>",
      "license": "OFL-1.1", "source": "https://fonts.google.com/noto/specimen/Noto+Sans+SC",
      "subsetCodepoints": "<fonttools 子集所用码点清单的 sha256>" }
  ]
}
```

## 默认选择

| 用途 | 字体 | 许可 | 备注 |
|---|---|---|---|
| 中文歌词主字 | Noto Sans SC（Bold/Black） | OFL-1.1，可商用 | 与 Archivo 的可变宽度气质接近 |
| 中文衬线（需要时） | Noto Serif SC | OFL-1.1 | 对应 Cormorant 的位置 |
| 等宽读数 | IBM Plex Mono（已有，拉丁） | OFL-1.1 | 数字读数够用；中文标签用 Noto Sans SC |

## 子集化流程（Song-03 实施时固化为脚本）

1. 收集本工程歌词全部码点 + ASCII + 常用标点。
2. `fonttools subset --text-file=codepoints.txt` 生成子集；记录码点清单 hash。
3. 歌词修改引入新码点时重新子集化（opentype 轮廓文字效果对中文要实测性能）。
