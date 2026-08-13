#!/usr/bin/env bash
set -Eeuo pipefail

upload_tmp=""
export_tmp=""
auth_header_tmp=""
uploaded_path=""
druid_cookie=""
cleanup_verify() {
  local exit_code=$?
  trap - EXIT ERR
  if [[ -n "${upload_tmp}" ]]; then
    rm -f -- "${upload_tmp}"
  fi
  if [[ -n "${export_tmp}" ]]; then
    rm -f -- "${export_tmp}"
  fi
  if [[ -n "${auth_header_tmp}" ]]; then
    rm -f -- "${auth_header_tmp}"
  fi
  if [[ -n "${druid_cookie}" ]]; then
    rm -f -- "${druid_cookie}"
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
[[ "$(systemctl show wms --property=Environment --value)" == *"TZ=Asia/Shanghai"* ]]

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
demo_warehouse_count="$(sudo mysql -NBe "SELECT COUNT(*) FROM wms.wms_warehouse WHERE warehouse_code REGEXP '^DEMO-WH-'")"
demo_item_count="$(sudo mysql -NBe "SELECT COUNT(*) FROM wms.wms_item WHERE item_code REGEXP '^DEMO-'")"
demo_stock_count="$(sudo mysql -NBe "SELECT COUNT(*) FROM wms.wms_stock WHERE batch_no REGEXP '^DEMO-'")"
demo_receipt_count="$(sudo mysql -NBe "SELECT COUNT(*) FROM wms.wms_receipt WHERE receipt_no REGEXP '^DEMO-'")"
demo_shipment_count="$(sudo mysql -NBe "SELECT COUNT(*) FROM wms.wms_shipment WHERE shipment_no REGEXP '^DEMO-'")"
demo_movement_count="$(sudo mysql -NBe "SELECT COUNT(*) FROM wms.wms_stock_movement WHERE biz_no REGEXP '^DEMO-'")"
[[ "${table_count}" -ge 41 ]]
[[ "${user_count}" -ge 1 ]]
[[ "${warehouse_count}" -ge 1 ]]
[[ "${demo_warehouse_count}" -eq 3 ]]
[[ "${demo_item_count}" -ge 14 ]]
[[ "${demo_stock_count}" -ge 17 ]]
[[ "${demo_receipt_count}" -ge 3 ]]
[[ "${demo_shipment_count}" -ge 3 ]]
[[ "${demo_movement_count}" -ge 30 ]]

demo_seed_fingerprint="$(sha256sum /opt/wms-src/sql/demo/wms_demo_seed.sql | awk '{print $1}')"
installed_demo_fingerprint="$(sudo mysql -NBe "SELECT seed_fingerprint FROM wms.wms_demo_seed_version WHERE id=1")"
[[ "${installed_demo_fingerprint}" == "${demo_seed_fingerprint}" ]]
demo_refreshed_today="$(sudo mysql -NBe "SELECT COUNT(*) FROM wms.wms_demo_seed_version WHERE id=1 AND refreshed_on=CURDATE()")"
[[ "${demo_refreshed_today}" -eq 1 ]]
core_extension_fingerprint="$(sha256sum /opt/wms-src/sql/migrations/V1.1.0__wms_core_extensions.sql | awk '{print $1}')"
installed_core_fingerprint="$(sudo mysql -NBe "SELECT script_fingerprint FROM wms.wms_schema_migration WHERE version='1.1.0'")"
[[ "${installed_core_fingerprint}" == "${core_extension_fingerprint}" ]]

demo_invalid_stock="$(sudo mysql -NBe "SELECT COUNT(*) FROM wms.wms_stock s JOIN wms.wms_warehouse w ON w.warehouse_id=s.warehouse_id JOIN wms.wms_location l ON l.location_id=s.location_id JOIN wms.wms_item i ON i.item_id=s.item_id WHERE (w.warehouse_code REGEXP '^DEMO-' OR l.location_code REGEXP '^DEMO-' OR i.item_code REGEXP '^DEMO-' OR s.batch_no REGEXP '^DEMO-') AND (s.quantity<0 OR s.locked_quantity<0 OR s.locked_quantity>s.quantity)")"
demo_locked_stock="$(sudo mysql -NBe "SELECT COUNT(*) FROM wms.wms_stock WHERE batch_no REGEXP '^DEMO-' AND locked_quantity<>0")"
demo_capacity_errors="$(sudo mysql -NBe "SELECT COUNT(*) FROM (SELECT l.location_id FROM wms.wms_location l JOIN wms.wms_stock s ON s.location_id=l.location_id WHERE l.location_code REGEXP '^DEMO-' AND l.capacity_qty>0 GROUP BY l.location_id,l.capacity_qty HAVING SUM(s.quantity)>l.capacity_qty) x")"
demo_ledger_errors="$(sudo mysql -NBe "SELECT COUNT(*) FROM (SELECT s.stock_id FROM wms.wms_stock s JOIN wms.wms_warehouse w ON w.warehouse_id=s.warehouse_id JOIN wms.wms_location l ON l.location_id=s.location_id JOIN wms.wms_item i ON i.item_id=s.item_id LEFT JOIN (SELECT warehouse_id,location_id,item_id,batch_no,SUM(change_qty) movement_qty FROM wms.wms_stock_movement GROUP BY warehouse_id,location_id,item_id,batch_no) m ON m.warehouse_id=s.warehouse_id AND m.location_id=s.location_id AND m.item_id=s.item_id AND m.batch_no=s.batch_no WHERE (w.warehouse_code REGEXP '^DEMO-' OR l.location_code REGEXP '^DEMO-' OR i.item_code REGEXP '^DEMO-' OR s.batch_no REGEXP '^DEMO-') AND (m.movement_qty IS NULL OR m.movement_qty<>s.quantity)) x")"
demo_today_inbound="$(sudo mysql -NBe "SELECT COALESCE(SUM(total_qty),0) FROM wms.wms_receipt WHERE receipt_no REGEXP '^DEMO-' AND status='COMPLETED' AND receipt_date>=CURDATE() AND receipt_date<CURDATE()+INTERVAL 1 DAY")"
demo_today_outbound="$(sudo mysql -NBe "SELECT COALESCE(SUM(total_qty),0) FROM wms.wms_shipment WHERE shipment_no REGEXP '^DEMO-' AND status='COMPLETED' AND shipment_date>=CURDATE() AND shipment_date<CURDATE()+INTERVAL 1 DAY")"
demo_action_permissions="$(sudo mysql -NBe "SELECT COUNT(DISTINCT perms) FROM wms.sys_menu WHERE perms IN ('wms:stock:transfer','wms:stock:adjust','wms:receipt:cancel','wms:shipment:cancel') AND status='0'")"
duplicate_action_permissions="$(sudo mysql -NBe "SELECT COUNT(*) FROM (SELECT perms FROM wms.sys_menu WHERE perms IN ('wms:stock:transfer','wms:stock:adjust','wms:receipt:cancel','wms:shipment:cancel') GROUP BY perms HAVING COUNT(*)<>1) p")"
admin_action_permissions="$(sudo mysql -NBe "SELECT COUNT(DISTINCT m.perms) FROM wms.sys_role r JOIN wms.sys_role_menu rm ON rm.role_id=r.role_id JOIN wms.sys_menu m ON m.menu_id=rm.menu_id WHERE r.role_key='admin' AND m.perms IN ('wms:stock:transfer','wms:stock:adjust','wms:receipt:cancel','wms:shipment:cancel')")"
[[ "${demo_invalid_stock}" -eq 0 ]]
[[ "${demo_locked_stock}" -eq 0 ]]
[[ "${demo_capacity_errors}" -eq 0 ]]
[[ "${demo_ledger_errors}" -eq 0 ]]
[[ "$(printf '%.0f' "${demo_today_inbound}")" -gt 0 ]]
[[ "$(printf '%.0f' "${demo_today_outbound}")" -gt 0 ]]
[[ "${demo_action_permissions}" -eq 4 ]]
[[ "${duplicate_action_permissions}" -eq 0 ]]
[[ "${admin_action_permissions}" -eq 4 ]]

valkey_password="$(sudo sed -n 's/^REDIS_PASSWORD=//p' /etc/wms/wms.env)"
[[ "$(VALKEYCLI_AUTH="${valkey_password}" valkey-cli --raw ping 2>/dev/null)" == "PONG" ]]

druid_username="$(sudo sed -n 's/^DRUID_USERNAME=//p' /etc/wms/wms.env)"
druid_password="$(sudo sed -n 's/^DRUID_PASSWORD=//p' /etc/wms/wms.env)"
druid_login_page="$(curl -fsS http://127.0.0.1/prod-api/druid/login.html)"
[[ "${druid_login_page}" == *'name="loginUsername"'* ]]
curl -fsS -o /dev/null http://127.0.0.1/prod-api/druid/css/bootstrap.min.css
curl -fsS -o /dev/null http://127.0.0.1/prod-api/druid/js/jquery.min.js
druid_invalid_login_response="$(
  printf 'loginUsername=%s&loginPassword=%s' "${druid_username}" '__invalid_verification_password__' |
    curl -fsS --data-binary @- http://127.0.0.1/prod-api/druid/submitLogin
)"
[[ "${druid_invalid_login_response}" == "error" ]]
druid_cookie="$(mktemp)"
chmod 0600 "${druid_cookie}"
druid_login_response="$(
  printf 'loginUsername=%s&loginPassword=%s' "${druid_username}" "${druid_password}" |
    curl -fsS -c "${druid_cookie}" --data-binary @- http://127.0.0.1/prod-api/druid/submitLogin
)"
[[ "${druid_login_response}" == "success" ]]
druid_index_page="$(curl -fsS -b "${druid_cookie}" http://127.0.0.1/prod-api/druid/index.html)"
[[ "${druid_index_page}" == *'Druid Stat Index'* ]]
druid_basic_json="$(curl -fsS -b "${druid_cookie}" http://127.0.0.1/prod-api/druid/basic.json)"
printf '%s' "${druid_basic_json}" | python3 -c 'import json,sys; data=json.load(sys.stdin); assert data.get("ResultCode") == 1 and data.get("Content", {}).get("ResetEnable") is False'
druid_previous_session_id="$(awk '$6 == "JSESSIONID" { print $7 }' "${druid_cookie}")"
[[ -n "${druid_previous_session_id}" ]]
druid_password=""

[[ "$(curl -fsS http://127.0.0.1/healthz)" == "ok" ]]
captcha_json="$(curl -fsS http://127.0.0.1/prod-api/captchaImage)"
uuid="$(printf '%s' "${captcha_json}" | python3 -c 'import json,sys; data=json.load(sys.stdin); assert data.get("code") == 200 and data.get("captchaEnabled") is True and len(data.get("img", "")) > 100; print(data["uuid"])')"
captcha_code="$(VALKEYCLI_AUTH="${valkey_password}" valkey-cli --raw GET "captcha_codes:${uuid}" 2>/dev/null | tr -d '"\r\n')"
[[ -n "${captcha_code}" ]]

admin_password="${ADMIN_PASSWORD:-}"
unset ADMIN_PASSWORD
if [[ -z "${admin_password}" ]]; then
  if [[ ! -t 0 ]]; then
    echo "Set ADMIN_PASSWORD or run interactively" >&2
    exit 1
  fi
  read -r -s -p 'Admin password: ' admin_password
  echo
fi
login_payload="$(printf '%s\0%s\0%s' "${admin_password}" "${captcha_code}" "${uuid}" | python3 -c 'import json,sys; password,code,uuid=(part.decode() for part in sys.stdin.buffer.read().split(b"\0")); print(json.dumps({"username":"admin","password":password,"code":code,"uuid":uuid}))')"
admin_password=""
login_json="$(printf '%s' "${login_payload}" | curl -fsS -H 'Content-Type: application/json' --data-binary @- http://127.0.0.1/prod-api/login)"
login_payload=""
token="$(printf '%s' "${login_json}" | python3 -c 'import json,sys; data=json.load(sys.stdin); assert data.get("code") == 200 and data.get("token"); print(data["token"])')"
login_json=""
auth_header_tmp="$(mktemp)"
chmod 0600 "${auth_header_tmp}"
printf 'Authorization: Bearer %s\n' "${token}" > "${auth_header_tmp}"

info_json="$(curl -fsS -H "@${auth_header_tmp}" http://127.0.0.1/prod-api/getInfo)"
printf '%s' "${info_json}" | python3 -c 'import json,sys; data=json.load(sys.stdin); assert data.get("code") == 200 and data.get("user", {}).get("userName") == "admin"'

druid_unauthorized_json="$(curl -fsS -X POST http://127.0.0.1/prod-api/monitor/druid/session)"
printf '%s' "${druid_unauthorized_json}" | python3 -c 'import json,sys; assert json.load(sys.stdin).get("code") == 401'

druid_session_json="$(curl -fsS -b "${druid_cookie}" -c "${druid_cookie}" -H "@${auth_header_tmp}" -X POST http://127.0.0.1/prod-api/monitor/druid/session)"
printf '%s' "${druid_session_json}" | python3 -c 'import json,sys; assert json.load(sys.stdin).get("code") == 200'
druid_session_id="$(awk '$6 == "JSESSIONID" { print $7 }' "${druid_cookie}")"
[[ -n "${druid_session_id}" ]]
[[ "${druid_session_id}" != "${druid_previous_session_id}" ]]
druid_sso_index_page="$(curl -fsS -b "${druid_cookie}" http://127.0.0.1/prod-api/druid/index.html)"
[[ "${druid_sso_index_page}" == *'Druid Stat Index'* ]]
druid_session_delete_json="$(curl -fsS -b "${druid_cookie}" -c "${druid_cookie}" -H "@${auth_header_tmp}" -X DELETE http://127.0.0.1/prod-api/monitor/druid/session)"
printf '%s' "${druid_session_delete_json}" | python3 -c 'import json,sys; assert json.load(sys.stdin).get("code") == 200'
druid_expired_result="$(curl -sS -o /dev/null -w '%{http_code} %{redirect_url}' -H "Cookie: JSESSIONID=${druid_session_id}" http://127.0.0.1/prod-api/druid/index.html)"
[[ "${druid_expired_result}" == "302 http://127.0.0.1/prod-api/druid/login.html" ]]
rm -f -- "${druid_cookie}"
druid_cookie=""

dashboard_json="$(curl -fsS -H "@${auth_header_tmp}" http://127.0.0.1/prod-api/wms/dashboard/summary)"
printf '%s' "${dashboard_json}" | python3 -c 'import json,sys; data=json.load(sys.stdin); summary=data.get("data", {}); assert data.get("code") == 200 and isinstance(summary, dict); assert float(summary.get("todayInbound", 0)) > 0 and float(summary.get("todayOutbound", 0)) > 0'

trend_json="$(curl -fsS -H "@${auth_header_tmp}" http://127.0.0.1/prod-api/wms/dashboard/operationTrend)"
printf '%s' "${trend_json}" | python3 -c 'import json,sys; data=json.load(sys.stdin); rows=data.get("data", []); assert data.get("code") == 200 and isinstance(rows, list) and len(rows) >= 3; assert any(float(row.get("inboundQty", 0)) > 0 for row in rows); assert any(float(row.get("outboundQty", 0)) > 0 for row in rows)'

distribution_json="$(curl -fsS -H "@${auth_header_tmp}" http://127.0.0.1/prod-api/wms/dashboard/warehouseStockDistribution)"
printf '%s' "${distribution_json}" | python3 -c 'import json,sys; data=json.load(sys.stdin); rows=data.get("data", []); assert data.get("code") == 200 and isinstance(rows, list); assert sum(1 for row in rows if float(row.get("stockQty", 0)) > 0) >= 2'

stock_json="$(curl -fsS -G -H "@${auth_header_tmp}" --data-urlencode 'warehouseCode=DEMO-' --data-urlencode 'pageNum=1' --data-urlencode 'pageSize=100' http://127.0.0.1/prod-api/wms/stock/list)"
printf '%s' "${stock_json}" | python3 -c 'import json,sys; data=json.load(sys.stdin); assert data.get("code") == 200 and len(data.get("rows", [])) >= 17'

for export_endpoint in \
  wms/warehouse/export wms/area/export wms/location/export wms/item/export \
  wms/receipt/export wms/shipment/export wms/stock/export \
  wms/stock/lowStock/export wms/stock/movement/export; do
  export_tmp="$(mktemp --suffix=.xlsx)"
  curl -fsS -H "@${auth_header_tmp}" -X POST -o "${export_tmp}" "http://127.0.0.1/prod-api/${export_endpoint}"
  [[ "$(stat -c '%s' "${export_tmp}")" -gt 1000 ]]
  [[ "$(od -An -tx1 -N2 "${export_tmp}" | tr -d ' \n')" == "504b" ]]
  rm -f -- "${export_tmp}"
  export_tmp=""
done

upload_tmp="$(mktemp --suffix=.txt)"
printf 'WMS deployment verification\n' > "${upload_tmp}"
upload_json="$(curl -fsS -H "@${auth_header_tmp}" -F "file=@${upload_tmp};type=text/plain" http://127.0.0.1/prod-api/common/upload)"
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

druid_cookie="$(mktemp)"
chmod 0600 "${druid_cookie}"
druid_logout_session_json="$(curl -fsS -c "${druid_cookie}" -H "@${auth_header_tmp}" -X POST http://127.0.0.1/prod-api/monitor/druid/session)"
printf '%s' "${druid_logout_session_json}" | python3 -c 'import json,sys; assert json.load(sys.stdin).get("code") == 200'
druid_logout_session_id="$(awk '$6 == "JSESSIONID" { print $7 }' "${druid_cookie}")"
[[ -n "${druid_logout_session_id}" ]]
logout_json="$(curl -fsS -b "${druid_cookie}" -c "${druid_cookie}" -H "@${auth_header_tmp}" -X POST http://127.0.0.1/prod-api/logout)"
printf '%s' "${logout_json}" | python3 -c 'import json,sys; assert json.load(sys.stdin).get("code") == 200'
druid_after_logout_result="$(curl -sS -o /dev/null -w '%{http_code} %{redirect_url}' -H "Cookie: JSESSIONID=${druid_logout_session_id}" http://127.0.0.1/prod-api/druid/index.html)"
[[ "${druid_after_logout_result}" == "302 http://127.0.0.1/prod-api/druid/login.html" ]]
token_after_logout_json="$(curl -fsS -H "@${auth_header_tmp}" http://127.0.0.1/prod-api/getInfo)"
printf '%s' "${token_after_logout_json}" | python3 -c 'import json,sys; assert json.load(sys.stdin).get("code") == 401'
rm -f -- "${druid_cookie}"
druid_cookie=""
rm -f -- "${auth_header_tmp}"
auth_header_tmp=""
token=""

echo "services=ok"
echo "ports=ok backend=${backend_socket}"
echo "database=ok tables=${table_count} users=${user_count} warehouses=${warehouse_count}"
echo "demo_data=ok warehouses=${demo_warehouse_count} items=${demo_item_count} stocks=${demo_stock_count} receipts=${demo_receipt_count} shipments=${demo_shipment_count} movements=${demo_movement_count}"
echo "valkey=ok"
echo "druid_console=ok"
echo "druid_wms_session=ok"
echo "logout_session=ok"
echo "captcha=ok"
echo "admin_login=ok"
echo "wms_dashboard=ok"
echo "wms_analytics=ok"
echo "wms_export=ok"
echo "upload=ok test_file_removed=yes"
trap - EXIT ERR
