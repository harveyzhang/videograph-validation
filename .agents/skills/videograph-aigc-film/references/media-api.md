# 媒体 API（OpenAI Next 中转，2026-10 实测）

基址 `https://api.openai-next.com`，`Authorization: Bearer $CREDIT_MEDIA_API_KEY`。先 `GET /v1/models` 看本账号可用模型（实测返回 600+ 个 id，按 `image|seedance|tts|suno` 过滤）。

## 生图

```
POST /v1/images/generations  {"model":"gpt-image-2","prompt":"…","size":"1536x1024","quality":"high","n":1}
POST /v1/images/edits        multipart：model, prompt, size, quality, image[]=<参考图文件>（可多张）
```

- 返回 `data[0].b64_json` 或 `data[0].url`，两种都要处理。
- 单张约 40–100 秒；edits 偶发 524（网关超时），直接重试同一请求。
- 生成 3:2 后裁 16:9 再缩放到 1920×1080。

## 图生视频（Seedance 2.0）

```
POST /seedance/api/v3/contents/generations/tasks
{"model":"doubao-seedance-2-0-260128",
 "content":[{"type":"text","text":"<运动描述>"},
            {"type":"image_url","image_url":{"url":"data:image/jpeg;base64,…"},"role":"first_frame"}],
 "duration":4,"ratio":"16:9","resolution":"1080p","generate_audio":false,"watermark":false}
GET  /seedance/api/v3/contents/generations/tasks/{id}   → status: queued|running|succeeded|failed；succeeded 时 content.video_url
```

- 输出 1920×1080、24fps；4–6 秒片段约 3–4 分钟。并发 4 稳定。
- **提交后立刻把任务 ID 写进日志**。密钥失效、进程中断时，已提交的任务服务端仍会完成，恢复后按 ID 续取，不要重新提交（重复扣费）。

## 语音合成

```
POST /v1/audio/speech  {"model":"qwen3-tts-flash","input":"…","voice":"Cherry","response_format":"wav"}
```

- 中文可用音色实测：`Cherry`（女声旁白）、`Ethan`（男声）。返回 24 kHz 单声道 WAV，**文件头长度是流式占位值**，scipy 读取会警告但数据完整。
- 并行请求会 429（`Throttling.RateQuota`）：顺序生成 + 退避重试。

## 音乐

- 账号模型列表里有 `suno-*`，但 2026-10 实测：`/_open/suno/music/generate` 在该域名返回网站前端 HTML；`/suno/submit/music` 报 “Model fixed price not configured”；chat 方式报 `suno_task_failed`。**不可用时改用 numpy 原创合成**，在交付说明中写明，并保留之后替换音轨的路径（新音轨需重建工程）。

## 错误码对策

| 现象 | 处理 |
|---|---|
| 401 Invalid token（所有接口） | 密钥失效（额度耗尽或被吊销）。停止提交，告诉用户；恢复后按日志任务 ID 续取 |
| 429 Throttling | 降并发、指数退避 |
| 524 / fetch failed | 网关或网络抖动：查日志看是否已提交；已提交就续取，未提交再重试 |
| HTML 页面响应 | 端点不对外开放，换调用方式或替代方案 |
