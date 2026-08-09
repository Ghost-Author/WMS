# Oracle Cloud 免费实例部署

该方案面向 Oracle Cloud Always Free 的 ARM64 实例，使用 Docker Compose 同机运行 Nginx、以安WMS、MySQL 8.4 和 Redis。

## 推荐实例参数

- 镜像：Ubuntu 24.04（aarch64）
- Shape：`VM.Standard.A1.Flex`
- OCPU：2
- 内存：12 GB
- 启动盘：80 GB
- 网络：分配公网 IPv4

在 Oracle VCN 安全列表或 NSG 中开放：

- TCP 22：仅允许自己的公网 IP
- TCP 80：单人测试也仅允许自己的公网 IP；确需临时公开演示时再短时允许 `0.0.0.0/0`

MySQL、Redis 和后端 8080 端口仅存在于 Docker 内部网络，不应在云防火墙中开放。

## 首次部署

服务器安装 Git、Docker Engine 和 Docker Compose v2 后执行：

```bash
git clone https://github.com/Ghost-Author/WMS.git
cd WMS
cp deploy/.env.example deploy/.env
chmod 600 deploy/.env
```

编辑 `deploy/.env`，将所有 `CHANGE_ME` 替换为随机值。可使用 `openssl rand -hex 24` 分别生成数据库和 Redis 密码，使用 `openssl rand -hex 32` 生成 JWT 密钥。

确认没有遗留占位值：

```bash
! grep -q CHANGE_ME deploy/.env
```

启动全部服务：

```bash
docker compose --env-file deploy/.env -f deploy/docker-compose.oracle.yml up -d --build
docker compose --env-file deploy/.env -f deploy/docker-compose.oracle.yml ps
docker compose --env-file deploy/.env -f deploy/docker-compose.oracle.yml logs mysql --tail=200
```

首次启动必须确认 MySQL 日志中的三个初始化脚本均执行成功。脚本只在空数据卷上运行；如果首次初始化失败，应先停止服务并检查具体 SQL 错误，不要直接反复重启或在已有业务数据时删除数据卷。

已有数据库升级到 1.0.0 前必须先备份，再执行 `sql/migrations/V1.0.0__rebrand_to_yian_wms.sql`。初始化脚本只用于空数据库，不能作为升级脚本重复导入。

访问 `http://服务器公网IP`，使用初始账号 `admin`、密码 `admin123` 登录。首次登录后应立即修改管理员密码，并验证登录、WMS 页面和文件上传功能。

## 查看日志与更新

```bash
docker compose --env-file deploy/.env -f deploy/docker-compose.oracle.yml logs -f --tail=200
git pull --ff-only
docker compose --env-file deploy/.env -f deploy/docker-compose.oracle.yml up -d --build
```

停止服务但保留数据：

```bash
docker compose --env-file deploy/.env -f deploy/docker-compose.oracle.yml down
```

不要对含有 `-v` 的 `down` 命令进行试验；它会删除 MySQL、Redis 和上传文件的数据卷。
