# 以安WMS 前端

以安WMS 的 Vue 3 管理端，使用 Vite、Element Plus 和 Pinia 构建。

## 开发

```bash
npm ci
npm run dev
```

开发地址默认为 `http://localhost:5173`，接口通过 `/dev-api` 代理到本地后端。

## 构建

```bash
npm run build:prod
```

生产文件输出到 `dist/`。页面标题由各环境文件中的 `VITE_APP_TITLE` 配置，接口前缀由 `VITE_APP_BASE_API` 配置。
