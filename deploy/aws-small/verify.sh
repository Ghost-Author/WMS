#!/usr/bin/env bash
set -Eeuo pipefail

upload_tmp=""
uploaded_path=""
cleanup_verify() {
  local exit_code=$?
  trap - EXIT ERR
  if [[ -n "${upload_tmp}" ]]; then
    rm -f -- "${upload_tmp}"
  fi
  if [[ "${uploaded_path}" =~ ^/var/lib/wms/uploadPath/upload/[0-9]{4}/[0-9]{2}/[0-9]{2}/[^/]+$ ]]; then
    sudo rm -f -- "${uploaded_path}"
  fi
  exit "${exit_code}"
}
trap cleanup_verify EXIT
trap 'echo "verify_failed_line=${LINENO}" >&2' ERR

for service_name in mysql valkey-server wms nginx; do
  [[ "$(systemctl is-active "${service_name}")" == "active" ]]
  [[ "$(systemctl is-enabled "${service_name}")" == "enabled" ]]
done

[[ "$(sudo stat -c '%a:%U:%G' /etc/wms/wms.env)" == "600:root:root" ]]
[[ "$(sudo stat -c '%a:%U:%G' /etc/wms/valkey-secret.conf)" == "640:root:valkey" ]]
! sudo grep -q CHANGE_ME /etc/wms/wms.env

backend_socket="$(ss -lntH 'sport = :8080' | awk '{print $4}')"
[[ "${backend_socket}" == "127.0.0.1:8080" || "${backend_socket}" == "[::ffff:127.0.0.1]:8080" ]]
while IFS= read -r local_socket; do
  case "${local_socket}" in
    127.0.0.1:3306|127.0.0.1:6379|'[::1]:3306'|'[::1]:6379') ;;
    *) echo "Unexpected database/cache listener: ${local_socket}" >&2; exit 1 ;;
  esac
done < <(ss -lntH 'sport = :3306 or sport = :6379' | awk '{print $4}')

table_count="$(sudo mysql -NBe "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='wms'")"
user_count="$(sudo mysql -NBe "SELECT COUNT(*) FROM wms.sys_user")"
warehouse_count="$(sudo mysql -NBe "SELECT COUNT(*) FROM wms.wms_warehouse")"
[[ "${table_count}" -ge 41 ]]
[[ "${user_count}" -ge 1 ]]
[[ "${warehouse_count}" -ge 1 ]]

valkey_password="$(sudo sed -n 's/^REDIS_PASSWORD=//p' /etc/wms/wms.env)"
[[ "$(VALKEYCLI_AUTH="${valkey_password}" valkey-cli --raw ping 2>/dev/null)" == "PONG" ]]

[[ "$(curl -fsS http://127.0.0.1/healthz)" == "ok" ]]
captcha_json="$(curl -fsS http://127.0.0.1/prod-api/captchaImage)"
uuid="$(printf '%s' "${captcha_json}" | python3 -c 'import json,sys; data=json.load(sys.stdin); assert data.get("code") == 200 and data.get("captchaEnabled") is True and len(data.get("img", "")) > 100; print(data["uuid"])')"
captcha_code="$(VALKEYCLI_AUTH="${valkey_password}" valkey-cli --raw GET "captcha_codes:${uuid}" 2>/dev/null | tr -d '"\r\n')"
[[ -n "${captcha_code}" ]]

admin_password="${ADMIN_PASSWORD:-}"
if [[ -z "${admin_password}" ]]; then
  if [[ ! -t 0 ]]; then
    echo "Set ADMIN_PASSWORD or run interactively" >&2
    exit 1
  fi
  read -r -s -p 'Admin password: ' admin_password
  echo
fi
login_payload="$(ADMIN_PASSWORD="${admin_password}" CAPTCHA_CODE="${captcha_code}" CAPTCHA_UUID="${uuid}" python3 -c 'import json,os; print(json.dumps({"username":"admin","password":os.environ["ADMIN_PASSWORD"],"code":os.environ["CAPTCHA_CODE"],"uuid":os.environ["CAPTCHA_UUID"]}))')"
login_json="$(curl -fsS -H 'Content-Type: application/json' --data "${login_payload}" http://127.0.0.1/prod-api/login)"
token="$(printf '%s' "${login_json}" | python3 -c 'import json,sys; data=json.load(sys.stdin); assert data.get("code") == 200 and data.get("token"); print(data["token"])')"

info_json="$(curl -fsS -H "Authorization: Bearer ${token}" http://127.0.0.1/prod-api/getInfo)"
printf '%s' "${info_json}" | python3 -c 'import json,sys; data=json.load(sys.stdin); assert data.get("code") == 200 and data.get("user", {}).get("userName") == "admin"'

dashboard_json="$(curl -fsS -H "Authorization: Bearer ${token}" http://127.0.0.1/prod-api/wms/dashboard/summary)"
printf '%s' "${dashboard_json}" | python3 -c 'import json,sys; data=json.load(sys.stdin); assert data.get("code") == 200 and isinstance(data.get("data"), dict)'

upload_tmp="$(mktemp --suffix=.txt)"
printf 'WMS deployment verification\n' > "${upload_tmp}"
upload_json="$(curl -fsS -H "Authorization: Bearer ${token}" -F "file=@${upload_tmp};type=text/plain" http://127.0.0.1/prod-api/common/upload)"
rm -f -- "${upload_tmp}"
upload_tmp=""
upload_file="$(printf '%s' "${upload_json}" | python3 -c 'import json,sys; data=json.load(sys.stdin); assert data.get("code") == 200; print(data["fileName"])')"
[[ "${upload_file}" == /profile/upload/* ]]
upload_relative="${upload_file#/profile/}"
[[ "${upload_relative}" != *..* ]]
uploaded_path="/var/lib/wms/uploadPath/${upload_relative}"
[[ "${uploaded_path}" =~ ^/var/lib/wms/uploadPath/upload/[0-9]{4}/[0-9]{2}/[0-9]{2}/[^/]+$ ]]
sudo test -f "${uploaded_path}"
sudo rm -f -- "${uploaded_path}"
uploaded_path=""

echo "services=ok"
echo "ports=ok backend=${backend_socket}"
echo "database=ok tables=${table_count} users=${user_count} warehouses=${warehouse_count}"
echo "valkey=ok"
echo "captcha=ok"
echo "admin_login=ok"
echo "wms_dashboard=ok"
echo "upload=ok test_file_removed=yes"
trap - EXIT ERR
