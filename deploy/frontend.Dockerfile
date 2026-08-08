FROM node:22.23.1-alpine3.24 AS builder

WORKDIR /app
COPY ruoyi-ui/package.json ruoyi-ui/package-lock.json ./
RUN npm ci --no-audit --registry=https://registry.npmjs.org
COPY ruoyi-ui/ ./
RUN npm run build:prod

FROM nginx:1.30.4-alpine

COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist/ /usr/share/nginx/html/

EXPOSE 80
