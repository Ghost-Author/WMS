# AWS 小规格实例部署

此目录用于资源受限的测试实例（最低 2 vCPU、2 GB 内存；8 GB 磁盘只能短期测试，建议扩到 20 GB），采用主机原生的 Nginx、Java、MySQL 和 Valkey，避免 Docker 构建占用大量磁盘。生产环境仍建议使用更大的实例和容器化部署。

部署前应创建至少 1 GB 交换空间，并安装 MySQL 8.4、Valkey、Java 25、Nginx，以及验证码渲染所需的 `libharfbuzz0b`、`libfontconfig1`、`fonts-dejavu-core`。服务端敏感配置存放在 `/etc/wms/wms.env`，权限必须为 `0600`，不得提交到 Git。

文件用途：

- `wms.service`：以独立的 `wms` 非 root 用户运行后端，并限制 JVM 和 systemd 内存。
- `nginx.conf`：托管前端静态文件，将 `/prod-api/` 代理到本机 8080。
- `mysql.cnf`：将 MySQL 绑定到回环地址并将缓冲池控制在 256 MB。
- `wms.env.example`：后端环境变量模板，所有 `CHANGE_ME` 必须替换为随机值。
- `install.sh`：校验 commit 和构建产物哈希后，以原子版本目录安装或重部署。
- `verify.sh`：验证服务、监听地址、数据库、登录、WMS 看板和文件上传。
- `wms-tunnel.service`：可选的 Cloudflare Quick Tunnel，仅用于安全组暂时无法放行时生成临时 HTTPS 测试地址。

AWS 安全组只应开放 TCP 22 和 80，测试时均限制为使用者公网 IP；不要开放 3306、6379 或 8080。当前配置仅提供 HTTP，不应存放真实业务数据。

## Ubuntu 26.04 服务器准备

```bash
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

sudo apt-get update
sudo apt-get install -y mysql-server valkey-server openjdk-25-jre-headless nginx git curl openssl python3 libharfbuzz0b libfontconfig1 fonts-dejavu-core
install -d -m 0700 /tmp/wms-deploy
```

在构建机器的仓库根目录构建并准备发布文件：

```bash
mvn -q -DskipTests package
cd yian-wms-ui
npm ci
npm run build:prod
cd ..

tar -C yian-wms-ui/dist -czf /tmp/wms-ui.tar.gz .
cp yian-wms-admin/target/yian-wms-admin.jar /tmp/yian-wms-admin.jar
EXPECTED_COMMIT="$(git rev-parse HEAD)"
JAR_SHA256="$(shasum -a 256 /tmp/yian-wms-admin.jar | awk '{print $1}')"
UI_SHA256="$(shasum -a 256 /tmp/wms-ui.tar.gz | awk '{print $1}')"
```

把产物和部署文件上传到服务器的私有暂存目录（替换 IP 和密钥路径）：

```bash
scp -i /path/to/key.pem \
  /tmp/yian-wms-admin.jar /tmp/wms-ui.tar.gz \
  deploy/aws-small/{install.sh,verify.sh,wms.service,wms-tunnel.service,nginx.conf,mysql.cnf,wms.env.example} \
  ubuntu@SERVER_IP:/tmp/wms-deploy/

ssh -i /path/to/key.pem ubuntu@SERVER_IP \
  "EXPECTED_COMMIT=${EXPECTED_COMMIT} JAR_SHA256=${JAR_SHA256} UI_SHA256=${UI_SHA256} /tmp/wms-deploy/install.sh"
```

首次验收直接运行以下命令，脚本会隐藏管理员密码输入。登录成功后必须立即把默认密码 `admin123` 改掉；改密后再次验收时输入新密码。

```bash
ssh -t -i /path/to/key.pem ubuntu@SERVER_IP /tmp/wms-deploy/verify.sh
```

安装脚本仅允许空数据库首次导入，并在三个 SQL 文件全部成功后记录指纹。若发现非空但没有完成标记的数据库会停止，避免在半导入状态下继续。1.0.0 命名升级会先将数据库备份到 `/var/backups/yian-wms/`，再执行 `sql/migrations/V1.0.0__rebrand_to_yian_wms.sql` 并更新指纹；其他未知的 SQL 指纹变化仍会停止部署，必须先提供显式迁移，不能靠重复运行初始化脚本升级。每次部署切换后会清空该应用专用的 Valkey 数据库，用户需要重新登录，MySQL 业务数据不受影响。

## 可选临时公网隧道

Cloudflare Quick Tunnel 不需要账号，会生成随机的 `*.trycloudflare.com` 地址。它没有可用性承诺，服务重启后地址可能改变，只适合开发和临时测试。安装官方 `cloudflared` 后启用：

```bash
sudo install -o root -g root -m 0644 wms-tunnel.service /etc/systemd/system/wms-tunnel.service
sudo systemctl daemon-reload
sudo systemctl enable --now wms-tunnel
sudo journalctl -u wms-tunnel -n 100 --no-pager | grep -o 'https://[^ ]*\.trycloudflare\.com' | tail -1
```

隧道会把公网 HTTPS 请求转发到 `http://127.0.0.1:80`。停止并取消开机启动：

```bash
sudo systemctl disable --now wms-tunnel
```
