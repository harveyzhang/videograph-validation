// ae-page.mjs — 在渲染页内执行的函数（经 page.evaluate 序列化，必须自包含、不引用外部变量）。
// 真实引擎走 __pdoom.engine.readPixelsAsync（快，自底向上行序）；测试夹具引擎退回 __pdoom.png() 解码。

/**
 * 顺序渲染 times 并采集：低分辨率灰度帧（运动/亮度分析）和/或缩略图（拼图）。
 * sequential=true 时首帧 seek、后续按 dt 连续渲染（有状态场景正确）；否则每帧 seek。
 */
export async function pageSample({ times, dt, sequential, seekFirst = true, gray, thumbWidth }) {
  const P = window.__pdoom;
  const engine = P.engine;
  const W = P.width ?? 1920, H = P.height ?? 1080;
  const fast = !!engine?.readPixelsAsync;
  const grays = [], thumbs = [];
  let full = null, fullCanvas = null;
  const thumbHeight = thumbWidth ? Math.round(thumbWidth * H / W) : 0;
  for (let index = 0; index < times.length; index++) {
    const t = times[index];
    if (fast && sequential && (index > 0 || !seekFirst)) engine.render(t, dt, false, 1, 0.2);
    else await P.still(t, 1, 0.2);
    let source; // CanvasImageSource（自顶向下）
    if (fast && gray && !thumbWidth) {
      // 只要灰度：直接在像素缓冲上做 8×8 子采样盒滤波（同时压低胶片颗粒）（自底向上行序），省掉 1080p 的 putImageData 与缩放。
      const px = await engine.readPixelsAsync(), out = new Uint8Array(gray.w * gray.h);
      const cellW = W / gray.w, cellH = H / gray.h;
      for (let y = 0; y < gray.h; y++) for (let x = 0; x < gray.w; x++) {
        let sum = 0;
        for (let sy = 0; sy < 8; sy++) for (let sx = 0; sx < 8; sx++) {
          const px0 = Math.floor((x + (sx + 0.5) / 8) * cellW), py0 = H - 1 - Math.floor((y + (sy + 0.5) / 8) * cellH);
          const o = (py0 * W + px0) * 4;
          sum += 0.2126 * px[o] + 0.7152 * px[o + 1] + 0.0722 * px[o + 2];
        }
        out[y * gray.w + x] = Math.round(sum / 64);
      }
      let s = ''; for (let i = 0; i < out.length; i += 0x8000) s += String.fromCharCode(...out.subarray(i, i + 0x8000));
      grays.push(btoa(s));
      continue;
    }
    if (fast) {
      const px = await engine.readPixelsAsync();
      if (!full) { full = new ImageData(W, H); fullCanvas = new OffscreenCanvas(W, H); }
      const row = W * 4;
      for (let y = 0; y < H; y++) full.data.set(px.subarray((H - 1 - y) * row, (H - y) * row), y * row);
      fullCanvas.getContext('2d').putImageData(full, 0, 0);
      source = fullCanvas;
    } else {
      const base64 = await P.png();
      const binary = atob(base64), bytes = new Uint8Array(binary.length);
      for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
      source = await createImageBitmap(new Blob([bytes], { type: 'image/png' }));
    }
    if (gray) {
      const canvas = new OffscreenCanvas(gray.w, gray.h), ctx = canvas.getContext('2d');
      ctx.imageSmoothingQuality = 'high';
      ctx.drawImage(source, 0, 0, gray.w, gray.h);
      const data = ctx.getImageData(0, 0, gray.w, gray.h).data, out = new Uint8Array(gray.w * gray.h);
      for (let p = 0; p < out.length; p++) out[p] = Math.round(0.2126 * data[p * 4] + 0.7152 * data[p * 4 + 1] + 0.0722 * data[p * 4 + 2]);
      let s = ''; for (let i = 0; i < out.length; i += 0x8000) s += String.fromCharCode(...out.subarray(i, i + 0x8000));
      grays.push(btoa(s));
    }
    if (thumbWidth) {
      const canvas = new OffscreenCanvas(thumbWidth, thumbHeight), ctx = canvas.getContext('2d');
      ctx.imageSmoothingQuality = 'high';
      ctx.drawImage(source, 0, 0, thumbWidth, thumbHeight);
      const blob = await canvas.convertToBlob({ type: 'image/png' });
      const bytes = new Uint8Array(await blob.arrayBuffer());
      let s = ''; for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
      thumbs.push(btoa(s));
    }
    if (source.close) source.close();
  }
  const errors = [...(P.errors ?? [])];
  return { grays, thumbs, errors };
}

/** 网格拼图：tiles = [{ png?: base64, lines: string[], accent?: boolean, placeholder?: string }]，返回 PNG base64。 */
export async function pageComposeGrid({ tiles, columns, tileWidth, title }) {
  const tileHeight = Math.round(tileWidth * 9 / 16), labelHeight = 40, gap = 6, header = title ? 34 : 0;
  const rows = Math.ceil(tiles.length / columns);
  const width = columns * tileWidth + (columns + 1) * gap, height = header + rows * (tileHeight + labelHeight) + (rows + 1) * gap;
  const canvas = new OffscreenCanvas(width, height), ctx = canvas.getContext('2d');
  ctx.fillStyle = '#111317'; ctx.fillRect(0, 0, width, height);
  if (title) { ctx.fillStyle = '#EEE9DF'; ctx.font = '16px "Microsoft YaHei", sans-serif'; ctx.textBaseline = 'middle'; ctx.fillText(title, gap + 4, header / 2 + 2); }
  for (const [index, tile] of tiles.entries()) {
    const x = gap + (index % columns) * (tileWidth + gap), y = header + gap + Math.floor(index / columns) * (tileHeight + labelHeight + gap);
    if (tile.png) {
      const binary = atob(tile.png), bytes = new Uint8Array(binary.length);
      for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
      const bitmap = await createImageBitmap(new Blob([bytes], { type: 'image/png' }));
      ctx.drawImage(bitmap, x, y, tileWidth, tileHeight); bitmap.close();
    } else {
      ctx.fillStyle = '#1d2027'; ctx.fillRect(x, y, tileWidth, tileHeight);
      ctx.fillStyle = '#8a8f99'; ctx.font = '14px "Microsoft YaHei", sans-serif'; ctx.textBaseline = 'middle'; ctx.textAlign = 'center';
      ctx.fillText(tile.placeholder ?? '无画面', x + tileWidth / 2, y + tileHeight / 2); ctx.textAlign = 'left';
    }
    if (tile.accent) { ctx.strokeStyle = '#FF4D12'; ctx.lineWidth = 3; ctx.strokeRect(x + 1.5, y + 1.5, tileWidth - 3, tileHeight - 3); }
    ctx.fillStyle = '#EEE9DF'; ctx.font = '12px "Microsoft YaHei", monospace'; ctx.textBaseline = 'top';
    (tile.lines ?? []).slice(0, 2).forEach((line, i) => {
      let text = line;
      while (ctx.measureText(text).width > tileWidth - 4 && text.length > 1) text = text.slice(0, -2) + '…';
      ctx.fillStyle = i === 0 ? '#EEE9DF' : '#9aa0aa';
      ctx.fillText(text, x + 2, y + tileHeight + 4 + i * 17);
    });
  }
  const blob = await canvas.convertToBlob({ type: 'image/png' });
  const bytes = new Uint8Array(await blob.arrayBuffer());
  let s = ''; for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
}

/** 节奏对照图：画面运动（橙）vs 音乐能量（灰），下拍竖线、画面峰红点、切点虚线。 */
export async function pageDrawChart({ t, motion, audio, downbeats, peaks, cuts, start, end, title }) {
  const width = 1600, height = 420, left = 40, right = 12, top = 34, bottom = 28;
  const canvas = new OffscreenCanvas(width, height), ctx = canvas.getContext('2d');
  ctx.fillStyle = '#111317'; ctx.fillRect(0, 0, width, height);
  const x = (time) => left + (time - start) / Math.max(1e-6, end - start) * (width - left - right);
  const plotHeight = height - top - bottom;
  const scale = (values) => { const sorted = values.filter(Number.isFinite).sort((a, b) => a - b); const max = sorted[Math.floor(sorted.length * 0.995)] || 1; return (value) => top + plotHeight - Math.min(1, value / max) * plotHeight; };
  ctx.strokeStyle = 'rgba(255,255,255,0.10)'; ctx.lineWidth = 1;
  for (const db of downbeats) { ctx.beginPath(); ctx.moveTo(x(db), top); ctx.lineTo(x(db), top + plotHeight); ctx.stroke(); }
  ctx.setLineDash([6, 5]); ctx.strokeStyle = 'rgba(120,200,255,0.7)';
  for (const cut of cuts) { ctx.beginPath(); ctx.moveTo(x(cut), top); ctx.lineTo(x(cut), top + plotHeight); ctx.stroke(); }
  ctx.setLineDash([]);
  const line = (values, color, widthPx) => { const y = scale(values); ctx.strokeStyle = color; ctx.lineWidth = widthPx; ctx.beginPath(); values.forEach((value, i) => { const px = x(t[i]), py = y(value ?? 0); if (i) ctx.lineTo(px, py); else ctx.moveTo(px, py); }); ctx.stroke(); return y; };
  if (audio) line(audio, 'rgba(200,200,200,0.55)', 1.5);
  const y = line(motion, '#FF7A33', 1.5);
  ctx.fillStyle = '#FF3355';
  for (const peak of peaks) { const i = t.findIndex((value) => value >= peak - 1e-6); if (i >= 0) { ctx.beginPath(); ctx.arc(x(peak), y(motion[i] ?? 0), 3, 0, Math.PI * 2); ctx.fill(); } }
  ctx.fillStyle = '#EEE9DF'; ctx.font = '14px "Microsoft YaHei", sans-serif'; ctx.textBaseline = 'middle';
  ctx.fillText(title, left, top / 2);
  ctx.fillStyle = '#9aa0aa'; ctx.font = '12px monospace';
  const step = Math.max(1, Math.ceil((end - start) / 16));
  for (let s = Math.ceil(start); s <= end; s += step) ctx.fillText(`${s}s`, x(s) - 8, height - bottom / 2);
  const blob = await canvas.convertToBlob({ type: 'image/png' });
  const bytes = new Uint8Array(await blob.arrayBuffer());
  let s = ''; for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
}
