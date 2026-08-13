# 以安WMS

以安WMS 是一套前后端分离的仓储管理系统，覆盖仓库、库区、库位、物料、实时库存、库存流水、入库单、出库单和运营看板。

## 功能模块

- 仓库、库区、库位三级存储体系
- 物料、条码、规格、单位和安全库存
- 按仓库、库位、物料、批次管理实时库存
- 入库单、出库单的草稿、完成、取消与 Excel 导出
- 库存流水、跨仓/跨库位直接调拨、盘盈盘亏与库位容量校验
- 按仓安全库存预警、近 7 日出入库趋势和仓库库存分布
- 用户、角色、菜单、字典、日志、监控和代码生成
- PC 端自适应管理界面
- 可重复安装的智能硬件演示数据与部署烟测

## 技术栈

- 后端：Java 17、Spring Boot 4、MyBatis、MySQL、Valkey/Redis
- 前端：Vue 3、Vite、Element Plus、Pinia
- 部署：Nginx、systemd 或 Docker Compose

## 项目结构

```text
yian-wms-admin       Web 服务入口
yian-wms-business    仓储业务模块
yian-wms-common      通用类型与工具
yian-wms-framework   安全、缓存和 Web 基础设施
yian-wms-generator   代码生成模块
yian-wms-quartz      定时任务模块
yian-wms-system      系统管理模块
yian-wms-ui          Vue 前端
sql                  初始化与迁移脚本
deploy               部署配置
```

## 本地启动

环境要求：JDK 17+、Maven 3.9+、Node.js 20+、npm 10+、Docker Compose v2。

先启动 MySQL 和 Valkey/Redis：

```bash
cp .env.example .env
docker compose up -d
```

启动后端：

```bash
mvn -pl yian-wms-admin -am clean package -DskipTests
java -jar yian-wms-admin/target/yian-wms-admin.jar
```

启动前端：

```bash
cd yian-wms-ui
npm ci
npm run dev
```

访问 `http://localhost:5173`。测试账号为 `admin`，初始密码为 `admin123`；首次登录后请立即修改密码。

## 配置

常用环境变量：

```text
MYSQL_URL
MYSQL_USERNAME
MYSQL_PASSWORD
REDIS_HOST
REDIS_PORT
REDIS_PASSWORD
WMS_TOKEN_SECRET
WMS_UPLOAD_PATH
WMS_LOG_PATH
```

生产环境应使用随机强密码和独立 Token 密钥，关闭不需要的 Swagger、Druid 入口，并且不要把数据库、缓存服务直接暴露到公网。

## 部署

- Oracle Cloud 容器部署：[`deploy/README-ORACLE.md`](deploy/README-ORACLE.md)
- AWS 小规格实例部署：[`deploy/aws-small/README.md`](deploy/aws-small/README.md)

## 许可证

项目及第三方代码的许可和必要版权声明见 [`LICENSE`](LICENSE) 与前端模块中的 `LICENSE`。这些法律声明不作为产品品牌展示。
