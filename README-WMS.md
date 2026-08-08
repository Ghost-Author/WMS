# 智仓 WMS 快速启动

本项目基于 RuoYi-Vue 3.9.2（Spring Boot 4 + Vue 3）扩展仓储管理能力。后端默认运行在 `http://localhost:8080`，前端默认运行在 `http://localhost:5173`。

Oracle Cloud 免费 ARM64 实例的容器化部署说明见 [`deploy/README-ORACLE.md`](deploy/README-ORACLE.md)。

## 环境要求

- JDK 17 或更高版本
- Maven 3.9 或更高版本
- Node.js 20 或更高版本，npm 10 或更高版本
- Docker Desktop，或 Docker Engine + Docker Compose v2

## 1. 启动 MySQL 和 Redis

复制本地配置并启动依赖服务：

```bash
cp .env.example .env
docker compose up -d
docker compose ps
```

默认开发配置如下：

| 服务 | 地址 | 数据库/账号 | 密码 |
| --- | --- | --- | --- |
| MySQL 8.4 | `localhost:3306` | 数据库 `wms`，用户 `wms` | `wms123456` |
| MySQL root | `localhost:3306` | `root` | `root123456` |
| Redis 7 | `localhost:6379` | DB 0 | 无密码 |

MySQL 首次创建数据卷时，会依次执行：

1. `sql/ry_20260320.sql`：RuoYi 基础表和初始账号
2. `sql/quartz.sql`：Quartz 调度表
3. `sql/wms.sql`：WMS 表、演示数据、动态菜单和按钮权限

初始化脚本只会在 MySQL 数据卷为空时执行。若确实需要完全重建本地数据库，可先执行 `docker compose down -v` 再重新启动；该命令会永久删除当前 MySQL 和 Redis 本地数据，请先备份。

## 2. 配置后端

开发环境已有与 Compose 一致的默认值，通常无需额外配置。需要覆盖时可设置：

```bash
export MYSQL_URL='jdbc:mysql://localhost:3306/wms?useUnicode=true&characterEncoding=utf8&zeroDateTimeBehavior=convertToNull&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia%2FShanghai'
export MYSQL_USERNAME='wms'
export MYSQL_PASSWORD='wms123456'
export REDIS_HOST='localhost'
export REDIS_PORT='6379'
export REDIS_PASSWORD=''
```

也可以执行 `set -a; source .env; set +a`，将复制后的 `.env` 一次性加载到当前终端，再启动后端。

生产环境还应覆盖 `WMS_TOKEN_SECRET`、`WMS_UPLOAD_PATH` 和 `WMS_LOG_PATH`。`.env` 仅供本机 Compose 使用，不应提交真实生产密钥。

Swagger/OpenAPI 和 Druid 管理入口默认关闭。复制 `.env.example` 并加载后会为本地开发开启 Swagger；如需临时开启 Druid，还必须设置仅本机/IP 白名单与独立强密码：

```bash
export DRUID_CONSOLE_ENABLED=true
export DRUID_WEB_STAT_ENABLED=true
export DRUID_ALLOW='127.0.0.1'
export DRUID_USERNAME='druid_admin'
export DRUID_PASSWORD='请替换为随机强密码'
```

## 3. 启动后端

在项目根目录执行：

```bash
mvn -pl ruoyi-admin -am clean package -DskipTests
java -jar ruoyi-admin/target/ruoyi-admin.jar
```

后端启动成功后：

- API 根地址：`http://localhost:8080`
- Swagger UI（设置 `SPRINGDOC_ENABLED=true` 后）：`http://localhost:8080/swagger-ui.html`
- WMS OpenAPI JSON（设置 `SPRINGDOC_ENABLED=true` 后）：`http://localhost:8080/v3/api-docs/wms`
- Druid 控制台（按上文显式开启后）：`http://localhost:8080/druid/`

## 4. 启动前端

打开另一个终端：

```bash
cd ruoyi-ui
npm ci
npm run dev
```

访问 `http://localhost:5173`，使用初始账号登录：

- 用户名：`admin`
- 密码：`admin123`

## 功能模块

后端入口位于 `ruoyi-admin`，WMS 领域模型、Mapper 和业务服务位于 `ruoyi-wms`；前端 WMS 页面和请求封装分别位于 `ruoyi-ui/src/views/wms`、`ruoyi-ui/src/api/wms`。

- WMS 看板：库存、入库、出库等运营指标概览
- 仓库、库区、库位：维护 `仓库 → 库区 → 库位` 的存储层级
- 物料：维护物料编码、条码、规格、单位和安全库存
- 库存：按仓库、库位、物料和批次查看实时数量及库存流水
- 入库单：维护入库单及明细，完成入库后增加库存并记录正向流水
- 出库单：维护出库单及明细，完成出库后扣减库存并记录负向流水
- 系统管理：沿用 RuoYi 用户、角色、菜单、字典、日志和监控能力

## 关键业务规则

1. 仓库编码和物料编码全局唯一；库区编码、库位编码在所属仓库内唯一；物料条码非空时全局唯一。
2. 库区类型支持 `RECEIVING`、`STORAGE`、`PICKING`、`SHIPPING`、`RETURN`；库位类型支持 `NORMAL`、`FROZEN`、`DEFECTIVE`。
3. 基础资料状态 `0` 为启用、`1` 为停用。单据状态为 `DRAFT`、`COMPLETED` 或 `CANCELLED`，只有草稿单可以编辑并执行完成操作。
4. 库存维度唯一键为“仓库 + 库位 + 物料 + 批次”。无批次业务统一使用空字符串，避免同一库存维度被拆分。
5. 数量统一使用四位小数。入库、出库完成操作必须在数据库事务内更新单据、库存和流水；重复完成同一单据应被拒绝。
6. 出库数量不能超过可用库存（库存数量减锁定数量），任何完成操作都不得产生负库存。
7. 已完成单据和库存流水属于业务凭证，不应直接修改或物理删除。关联业务存在时，外键会限制删除仓库、库区、库位或物料。

## 常用运维命令

```bash
docker compose logs -f mysql
docker compose logs -f redis
docker compose stop
docker compose down
```

`docker compose down` 会停止并移除容器，但保留命名数据卷；下次 `docker compose up -d` 会继续使用原数据。

## 生产部署注意事项

- 替换示例数据库密码和 JWT 密钥，不要把 `.env`、备份或日志提交到仓库；Swagger 与 Druid 默认保持关闭，确需开启时使用 IP 白名单和独立强密码。
- MySQL 和 Redis 不应直接暴露到公网；使用防火墙、私有网络和最小权限账号，生产 Redis 应配置认证与持久化策略。
- 使用版本化数据库迁移工具管理结构升级。容器初始化 SQL 适合全新开发环境，不应覆盖已有生产库。
- 为 MySQL 和上传目录制定备份、恢复演练及保留策略；统一主机、JVM、数据库的 `Asia/Shanghai` 时区。
- 在反向代理上启用 HTTPS、请求大小限制和访问日志，并保护所有管理入口。
- 完成入库/出库涉及并发库存更新，生产环境应保留事务、行锁或等价并发控制，并监控死锁、慢 SQL、连接池和库存异常。
