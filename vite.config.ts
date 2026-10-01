import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// 旧演示视图的 dev 中间件（llm-proxy / pdoom-task / shot-queue）已随 CLEANUP-01 移除；
// 真实工作台只依赖 5191 工程服务，前端不再有自定义后端路由。
export default defineConfig({
  plugins: [react()],
  server: { port: 5188, host: '127.0.0.1' },
});
