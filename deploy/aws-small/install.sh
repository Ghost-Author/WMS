#!/usr/bin/env bash
set -Eeuo pipefail

readonly repo_url="https://github.com/Ghost-Author/WMS.git"
readonly expected_commit="${EXPECTED_COMMIT:-}"
readonly jar_sha256="${JAR_SHA256:-}"
readonly ui_sha256="${UI_SHA256:-}"
readonly staging_dir="${STAGING_DIR:-/tmp/wms-deploy}"
readonly source_dir="/opt/wms-src"
readonly app_dir="/opt/wms"
readonly legacy_sql_fingerprint="d34f80965c3d2d6c9140641e680f74dbb7e95a9f950be0563e2e16625052f45f"
readonly naming_migration="${source_dir}/sql/migrations/V1.0.0__rebrand_to_yian_wms.sql"
readonly core_extension_version="1.1.0"
readonly core_extension_migration="${source_dir}/sql/migrations/V1.1.0__wms_core_extensions.sql"
readonly demo_seed="${source_dir}/sql/demo/wms_demo_seed.sql"
readonly demo_refresh="${source_dir}/sql/demo/wms_demo_refresh.sql"

env_tmp=""
env_refresh=""
valkey_tmp=""
backup_tmp=""
cleanup_install() {
  local exit_code=$?
  local secret_tmp
  trap - EXIT
  for secret_tmp in "${env_tmp}" "${env_refresh}" "${valkey_tmp}"; do
    if [[ -n "${secret_tmp}" && -f "${secret_tmp}" && ! -L "${secret_tmp}" && -O "${secret_tmp}" ]]; then
      shred -u -- "${secret_tmp}" || rm -f -- "${secret_tmp}"
    fi
  done
  if [[ -n "${backup_tmp}" && "${backup_tmp}" =~ ^/var/backups/yian-wms/wms-before-[A-Za-z0-9._-]+\.sql\.tmp\.[0-9]+$ ]]; then
    sudo rm -f -- "${backup_tmp}"
  fi
  exit "${exit_code}"
}
trap cleanup_install EXIT

if [[ ! "${expected_commit}" =~ ^[0-9a-f]{40}$ ]]; then
  echo "EXPECTED_COMMIT must be a full 40-character lowercase Git SHA" >&2
  exit 1
fi
if [[ ! "${jar_sha256}" =~ ^[0-9a-f]{64}$ ]] ||
   [[ ! "${ui_sha256}" =~ ^[0-9a-f]{64}$ ]]; then
  echo "JAR_SHA256 and UI_SHA256 must be lowercase SHA-256 values" >&2
  exit 1
fi
if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as a sudo-capable non-root deployment user" >&2
  exit 1
fi

readonly release_id="${expected_commit:0:12}-${ui_sha256:0:12}"
readonly web_dir="/var/www/wms-${release_id}"
readonly jar_release="${app_dir}/releases/yian-wms-admin-${expected_commit:0:12}-${jar_sha256:0:12}.jar"

for command_name in curl date git mysql mysqldump nginx openssl sed sha256sum shred sudo systemctl tar valkey-cli; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 1
  fi
done

if [[ ! -d "${staging_dir}" || -L "${staging_dir}" ]] ||
   [[ "$(stat -c '%U:%a' "${staging_dir}")" != "$(id -un):700" ]]; then
  echo "STAGING_DIR must be a real directory owned by $(id -un) with mode 0700" >&2
  exit 1
fi

required_files=(
  yian-wms-admin.jar
  wms-ui.tar.gz
  wms.service
  wms-tunnel.service
  nginx.conf
  mysql.cnf
  wms.env.example
)

for artifact_name in "${required_files[@]}"; do
  artifact_path="${staging_dir}/${artifact_name}"
  if [[ ! -f "${artifact_path}" || -L "${artifact_path}" || ! -O "${artifact_path}" ]]; then
    echo "Deployment artifact must be a regular, non-symlink file owned by $(id -un): ${artifact_path}" >&2
    exit 1
  fi
done

if [[ "$(sha256sum "${staging_dir}/yian-wms-admin.jar" | awk '{print $1}')" != "${jar_sha256}" ]] ||
   [[ "$(sha256sum "${staging_dir}/wms-ui.tar.gz" | awk '{print $1}')" != "${ui_sha256}" ]]; then
  echo "Deployment artifact checksum mismatch" >&2
  exit 1
fi

if ! tar -tzf "${staging_dir}/wms-ui.tar.gz" | awk '
  /^\// || /(^|\/)\.\.($|\/)/ { bad=1 }
  END { exit bad ? 1 : 0 }
'; then
  echo "Frontend archive contains an unsafe path" >&2
  exit 1
fi
if tar -tvzf "${staging_dir}/wms-ui.tar.gz" | awk '$1 ~ /^[lh]/ { found=1 } END { exit found ? 0 : 1 }'; then
  echo "Frontend archive must not contain symbolic or hard links" >&2
  exit 1
fi

if [[ ! -d "${source_dir}/.git" ]]; then
  if [[ -e "${source_dir}" ]]; then
    echo "${source_dir} exists but is not a Git repository" >&2
    exit 1
  fi
  sudo git clone --filter=blob:none --no-checkout "${repo_url}" "${source_dir}"
fi

if [[ "$(sudo git -C "${source_dir}" remote get-url origin)" != "${repo_url}" ]]; then
  echo "Unexpected Git origin in ${source_dir}" >&2
  exit 1
fi
sudo git -C "${source_dir}" fetch --depth 1 origin "${expected_commit}"
sudo git -C "${source_dir}" checkout --detach --force "${expected_commit}"

actual_commit="$(sudo git -C "${source_dir}" rev-parse HEAD)"
if [[ "${actual_commit}" != "${expected_commit}" ]]; then
  echo "Unexpected source commit: ${actual_commit}" >&2
  exit 1
fi

if ! id -u wms >/dev/null 2>&1; then
  sudo useradd --system --home-dir /var/lib/wms --shell /usr/sbin/nologin wms
fi

sudo install -d -o root -g root -m 0755 "${app_dir}" "${app_dir}/releases"
sudo install -d -o wms -g wms -m 0750 /var/lib/wms /var/lib/wms/uploadPath /var/log/wms
sudo install -d -o root -g valkey -m 0750 /etc/wms
sudo install -o root -g root -m 0644 "${staging_dir}/mysql.cnf" /etc/mysql/mysql.conf.d/wms.cnf
sudo systemctl restart mysql

if [[ ! -f /etc/wms/wms.env ]]; then
  db_password="$(openssl rand -hex 24)"
  valkey_password="$(openssl rand -hex 24)"
  token_secret="$(openssl rand -hex 32)"
  druid_password="$(openssl rand -hex 24)"
  env_tmp="$(mktemp)"
  chmod 0600 "${env_tmp}"
  {
    printf 's/CHANGE_ME_DATABASE_PASSWORD/%s/\n' "${db_password}"
    printf 's/CHANGE_ME_VALKEY_PASSWORD/%s/\n' "${valkey_password}"
    printf 's/CHANGE_ME_WITH_AT_LEAST_32_RANDOM_CHARACTERS/%s/\n' "${token_secret}"
    printf 's/CHANGE_ME_DRUID_PASSWORD/%s/\n' "${druid_password}"
  } | sed -f - "${staging_dir}/wms.env.example" > "${env_tmp}"
  sudo install -o root -g root -m 0600 "${env_tmp}" /etc/wms/wms.env
  shred -u "${env_tmp}"
  env_tmp=""
fi

druid_password="$(sudo sed -n 's/^DRUID_PASSWORD=//p' /etc/wms/wms.env)"
if [[ ! "${druid_password}" =~ ^[0-9a-f]{48}$ ]]; then
  druid_password="$(openssl rand -hex 24)"
fi

env_refresh="$(mktemp)"
chmod 0600 "${env_refresh}"
sudo sed -E '/^(LOGGING_LEVEL_COM_[A-Z0-9_]*|DRUID_WEB_STAT_ENABLED|DRUID_CONSOLE_ENABLED|DRUID_ALLOW|DRUID_USERNAME|DRUID_PASSWORD)=/d' /etc/wms/wms.env > "${env_refresh}"
{
  echo 'LOGGING_LEVEL_COM_YIAN_WMS=info'
  echo 'DRUID_WEB_STAT_ENABLED=true'
  echo 'DRUID_CONSOLE_ENABLED=true'
  echo 'DRUID_ALLOW=127.0.0.1'
  echo 'DRUID_USERNAME=druid_admin'
  echo "DRUID_PASSWORD=${druid_password}"
} >> "${env_refresh}"
sudo install -o root -g root -m 0600 "${env_refresh}" /etc/wms/wms.env
shred -u "${env_refresh}"
env_refresh=""

db_password="$(sudo sed -n 's/^MYSQL_PASSWORD=//p' /etc/wms/wms.env)"
valkey_password="$(sudo sed -n 's/^REDIS_PASSWORD=//p' /etc/wms/wms.env)"
token_secret="$(sudo sed -n 's/^WMS_TOKEN_SECRET=//p' /etc/wms/wms.env)"

if [[ ! "${db_password}" =~ ^[0-9a-f]{48}$ ]] ||
   [[ ! "${valkey_password}" =~ ^[0-9a-f]{48}$ ]] ||
   [[ ! "${token_secret}" =~ ^[0-9a-f]{64}$ ]] ||
   [[ ! "${druid_password}" =~ ^[0-9a-f]{48}$ ]]; then
  echo "Invalid generated secret format" >&2
  exit 1
fi

valkey_tmp="$(mktemp)"
chmod 0600 "${valkey_tmp}"
{
  echo "bind 127.0.0.1 -::1"
  echo "protected-mode yes"
  echo "requirepass ${valkey_password}"
  echo "maxmemory 128mb"
  echo "maxmemory-policy noeviction"
} > "${valkey_tmp}"
sudo install -o root -g valkey -m 0640 "${valkey_tmp}" /etc/wms/valkey-secret.conf
shred -u "${valkey_tmp}"
valkey_tmp=""

if ! sudo grep -qxF "include /etc/wms/valkey-secret.conf" /etc/valkey/valkey.conf; then
  echo "include /etc/wms/valkey-secret.conf" | sudo tee -a /etc/valkey/valkey.conf >/dev/null
fi
sudo systemctl restart valkey-server
VALKEYCLI_AUTH="${valkey_password}" valkey-cli ping >/dev/null

printf '%s\n' "CREATE DATABASE IF NOT EXISTS wms CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;" |
  sudo mysql
printf '%s\n' "CREATE USER IF NOT EXISTS 'wms'@'127.0.0.1' IDENTIFIED BY '${db_password}'; ALTER USER 'wms'@'127.0.0.1' IDENTIFIED BY '${db_password}'; GRANT ALL PRIVILEGES ON wms.* TO 'wms'@'127.0.0.1'; FLUSH PRIVILEGES;" |
  sudo mysql

sql_fingerprint="$({
  sha256sum "${source_dir}/sql/yian_wms_20260320.sql"
  sha256sum "${source_dir}/sql/quartz.sql"
  sha256sum "${source_dir}/sql/wms.sql"
} | awk '{print $1}' | sha256sum | awk '{print $1}')"
marker_exists="$(sudo mysql -NBe "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='wms' AND table_name='wms_deployment_version'")"
schema_table_count="$(sudo mysql -NBe "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='wms'")"

if [[ "${marker_exists}" == "1" ]]; then
  installed_fingerprint="$(sudo mysql -NBe "SELECT sql_fingerprint FROM wms.wms_deployment_version WHERE id=1")"
  if [[ "${installed_fingerprint}" != "${sql_fingerprint}" ]]; then
    if [[ "${installed_fingerprint}" != "${legacy_sql_fingerprint}" ]] ||
       [[ ! -f "${naming_migration}" ]]; then
      echo "Database schema fingerprint changed without a supported migration" >&2
      exit 1
    fi

    backup_dir="/var/backups/yian-wms"
    backup_path="${backup_dir}/wms-before-1.0.0-${expected_commit:0:12}-$(date -u +%Y%m%dT%H%M%SZ).sql"
    backup_tmp="${backup_path}.tmp.$$"
    sudo install -d -o root -g root -m 0700 "${backup_dir}"
    if ! sudo mysqldump --single-transaction --routines --triggers wms |
      sudo tee "${backup_tmp}" >/dev/null; then
      echo "Database backup before 1.0.0 migration failed" >&2
      exit 1
    fi
    sudo chmod 0600 "${backup_tmp}"
    if ! sudo test -s "${backup_tmp}"; then
      echo "Database backup before 1.0.0 migration is empty" >&2
      exit 1
    fi
    sudo mv "${backup_tmp}" "${backup_path}"
    backup_tmp=""

    sudo mysql --database=wms < "${naming_migration}"
    sudo mysql --database=wms -e "UPDATE wms_deployment_version SET sql_fingerprint='${sql_fingerprint}', source_commit='${expected_commit}', applied_at=CURRENT_TIMESTAMP WHERE id=1;"
  else
    sudo mysql --database=wms -e "UPDATE wms_deployment_version SET source_commit='${expected_commit}', applied_at=CURRENT_TIMESTAMP WHERE id=1;"
  fi
elif [[ "${schema_table_count}" != "0" ]]; then
  echo "Database is non-empty but has no completed deployment marker; refusing a partial re-import" >&2
  exit 1
else
  sudo mysql --database=wms < "${source_dir}/sql/yian_wms_20260320.sql"
  sudo mysql --database=wms < "${source_dir}/sql/quartz.sql"
  sudo mysql --database=wms < "${source_dir}/sql/wms.sql"
  imported_table_count="$(sudo mysql -NBe "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='wms'")"
  if [[ "${imported_table_count}" -lt 41 ]]; then
    echo "Database import produced only ${imported_table_count} tables" >&2
    exit 1
  fi
  sudo mysql --database=wms -e "CREATE TABLE wms_deployment_version (id TINYINT UNSIGNED NOT NULL PRIMARY KEY, sql_fingerprint CHAR(64) NOT NULL, source_commit CHAR(40) NOT NULL, applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP); INSERT INTO wms_deployment_version (id, sql_fingerprint, source_commit) VALUES (1, '${sql_fingerprint}', '${expected_commit}');"
fi

if [[ ! -f "${core_extension_migration}" || -L "${core_extension_migration}" ]]; then
  echo "Missing regular core extension migration: ${core_extension_migration}" >&2
  exit 1
fi

core_extension_fingerprint="$(sha256sum "${core_extension_migration}" | awk '{print $1}')"
sudo mysql --database=wms -e "CREATE TABLE IF NOT EXISTS wms_schema_migration (version VARCHAR(32) NOT NULL PRIMARY KEY, script_fingerprint CHAR(64) NOT NULL, source_commit CHAR(40) NOT NULL, applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP);"
installed_core_fingerprint="$(sudo mysql -NBe "SELECT script_fingerprint FROM wms.wms_schema_migration WHERE version='${core_extension_version}'")"
if [[ -n "${installed_core_fingerprint}" && "${installed_core_fingerprint}" != "${core_extension_fingerprint}" ]]; then
  echo "Applied migration ${core_extension_version} differs from the immutable repository script" >&2
  exit 1
fi
if [[ -z "${installed_core_fingerprint}" ]]; then
  backup_dir="/var/backups/yian-wms"
  backup_path="${backup_dir}/wms-before-core-${core_extension_version}-${expected_commit:0:12}-$(date -u +%Y%m%dT%H%M%SZ).sql"
  backup_tmp="${backup_path}.tmp.$$"
  sudo install -d -o root -g root -m 0700 "${backup_dir}"
  if ! sudo mysqldump --single-transaction --routines --triggers wms |
    sudo tee "${backup_tmp}" >/dev/null; then
    sudo rm -f -- "${backup_tmp}"
    echo "Database backup before core extension migration failed" >&2
    exit 1
  fi
  sudo chmod 0600 "${backup_tmp}"
  if ! sudo test -s "${backup_tmp}"; then
    sudo rm -f -- "${backup_tmp}"
    echo "Database backup before core extension migration is empty" >&2
    exit 1
  fi
  sudo mv "${backup_tmp}" "${backup_path}"
  backup_tmp=""

  sudo mysql --database=wms < "${core_extension_migration}"
  sudo mysql --database=wms -e "INSERT IGNORE INTO wms_schema_migration (version, script_fingerprint, source_commit) VALUES ('${core_extension_version}', '${core_extension_fingerprint}', '${expected_commit}');"
  recorded_core_fingerprint="$(sudo mysql -NBe "SELECT script_fingerprint FROM wms.wms_schema_migration WHERE version='${core_extension_version}'")"
  if [[ "${recorded_core_fingerprint}" != "${core_extension_fingerprint}" ]]; then
    echo "Concurrent migration ${core_extension_version} used a different immutable script" >&2
    exit 1
  fi
fi

if [[ ! -f "${demo_seed}" || -L "${demo_seed}" || ! -f "${demo_refresh}" || -L "${demo_refresh}" ]]; then
  echo "Missing regular demo seed or refresh file" >&2
  exit 1
fi

demo_seed_fingerprint="$(sha256sum "${demo_seed}" | awk '{print $1}')"
demo_marker_exists="$(sudo mysql -NBe "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='wms' AND table_name='wms_demo_seed_version'")"
installed_demo_fingerprint=""
if [[ "${demo_marker_exists}" == "1" ]]; then
  demo_refreshed_column_exists="$(sudo mysql -NBe "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='wms' AND table_name='wms_demo_seed_version' AND column_name='refreshed_on'")"
  if [[ "${demo_refreshed_column_exists}" != "1" ]]; then
    sudo mysql --database=wms -e "ALTER TABLE wms_demo_seed_version ADD COLUMN refreshed_on DATE DEFAULT NULL AFTER applied_at;"
  fi
  installed_demo_fingerprint="$(sudo mysql -NBe "SELECT seed_fingerprint FROM wms.wms_demo_seed_version WHERE id=1")"
fi

if [[ "${installed_demo_fingerprint}" != "${demo_seed_fingerprint}" ]]; then
  backup_dir="/var/backups/yian-wms"
  backup_path="${backup_dir}/wms-before-demo-${demo_seed_fingerprint:0:12}-${expected_commit:0:12}-$(date -u +%Y%m%dT%H%M%SZ).sql"
  backup_tmp="${backup_path}.tmp.$$"
  sudo install -d -o root -g root -m 0700 "${backup_dir}"
  if ! sudo mysqldump --single-transaction --routines --triggers wms |
    sudo tee "${backup_tmp}" >/dev/null; then
    sudo rm -f -- "${backup_tmp}"
    echo "Database backup before demo seed failed" >&2
    exit 1
  fi
  sudo chmod 0600 "${backup_tmp}"
  if ! sudo test -s "${backup_tmp}"; then
    sudo rm -f -- "${backup_tmp}"
    echo "Database backup before demo seed is empty" >&2
    exit 1
  fi
  sudo mv "${backup_tmp}" "${backup_path}"
  backup_tmp=""

  sudo mysql --database=wms < "${demo_seed}"
  sudo mysql --database=wms -e "CREATE TABLE IF NOT EXISTS wms_demo_seed_version (id TINYINT UNSIGNED NOT NULL PRIMARY KEY, seed_fingerprint CHAR(64) NOT NULL, source_commit CHAR(40) NOT NULL, applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, refreshed_on DATE DEFAULT NULL); INSERT INTO wms_demo_seed_version (id, seed_fingerprint, source_commit, applied_at) VALUES (1, '${demo_seed_fingerprint}', '${expected_commit}', CURRENT_TIMESTAMP) ON DUPLICATE KEY UPDATE seed_fingerprint=VALUES(seed_fingerprint), source_commit=VALUES(source_commit), applied_at=CURRENT_TIMESTAMP;"
else
  sudo mysql --database=wms -e "UPDATE wms_demo_seed_version SET source_commit='${expected_commit}' WHERE id=1;"
fi

# Refresh only the fixed demo document dates so dashboard trends stay meaningful across later deployments.
sudo mysql --database=wms < "${demo_refresh}"
sudo mysql --database=wms -e "UPDATE wms_demo_seed_version SET source_commit='${expected_commit}', refreshed_on=CURDATE() WHERE id=1;"

jar_tmp="${jar_release}.tmp.$$"
sudo install -o root -g root -m 0644 "${staging_dir}/yian-wms-admin.jar" "${jar_tmp}"
sudo mv "${jar_tmp}" "${jar_release}"
sudo ln -sfn "${jar_release}" "${app_dir}/yian-wms-admin.jar"

web_tmp=""
cleanup_web_tmp() {
  local exit_code=$?
  trap - EXIT
  if [[ -n "${web_tmp}" && "${web_tmp}" == /var/www/.wms-*.tmp.* ]]; then
    sudo rm -rf -- "${web_tmp}"
  fi
  exit "${exit_code}"
}
trap cleanup_web_tmp EXIT

if [[ ! -d "${web_dir}" ]]; then
  web_tmp="$(sudo mktemp -d "/var/www/.wms-${release_id}.tmp.XXXXXX")"
  sudo tar --warning=no-unknown-keyword --no-same-owner --no-same-permissions \
    -xzf "${staging_dir}/wms-ui.tar.gz" -C "${web_tmp}"
  if [[ ! -f "${web_tmp}/index.html" ]]; then
    echo "Frontend extraction failed" >&2
    exit 1
  fi
  sudo chown -R root:root "${web_tmp}"
  sudo chmod -R u=rwX,go=rX "${web_tmp}"
  sudo mv "${web_tmp}" "${web_dir}"
  web_tmp=""
fi
if [[ ! -f "${web_dir}/index.html" ]]; then
  echo "Frontend extraction failed" >&2
  exit 1
fi

if [[ -L /var/www/wms ]]; then
  sudo ln -sfn "${web_dir}" /var/www/wms
elif [[ ! -e /var/www/wms ]]; then
  sudo ln -s "${web_dir}" /var/www/wms
else
  echo "/var/www/wms exists and is not a symlink" >&2
  exit 1
fi

sudo install -o root -g root -m 0644 "${staging_dir}/wms.service" /etc/systemd/system/wms.service
sudo install -o root -g root -m 0644 "${staging_dir}/wms-tunnel.service" /etc/systemd/system/wms-tunnel.service
sudo install -o root -g root -m 0644 "${staging_dir}/nginx.conf" /etc/nginx/sites-available/wms
if [[ -L /etc/nginx/sites-enabled/default ]]; then
  sudo unlink /etc/nginx/sites-enabled/default
fi
sudo ln -sfn /etc/nginx/sites-available/wms /etc/nginx/sites-enabled/wms
sudo nginx -t

sudo systemctl daemon-reload
sudo systemctl enable wms
sudo systemctl stop wms || true
VALKEYCLI_AUTH="${valkey_password}" valkey-cli FLUSHDB >/dev/null
sudo systemctl restart wms
sudo systemctl reload nginx

backend_ready=false
for _ in $(seq 1 90); do
  if curl -fsS http://127.0.0.1:8080/captchaImage >/dev/null 2>&1; then
    backend_ready=true
    break
  fi
  sleep 1
done
if [[ "${backend_ready}" != "true" ]]; then
  echo "Backend did not become ready" >&2
  exit 1
fi

sudo apt-get clean
rm -f -- \
  "${staging_dir}/yian-wms-admin.jar" \
  "${staging_dir}/wms-ui.tar.gz" \
  "${staging_dir}/wms.service" \
  "${staging_dir}/wms-tunnel.service" \
  "${staging_dir}/nginx.conf" \
  "${staging_dir}/mysql.cnf" \
  "${staging_dir}/wms.env.example"

trap - EXIT
echo "AWS_SMALL_DEPLOY_OK commit=${actual_commit} release=${release_id}"
