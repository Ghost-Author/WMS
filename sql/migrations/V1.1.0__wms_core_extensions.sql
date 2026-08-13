-- Add permissions introduced by the WMS core workflow extensions.
-- This migration is idempotent and never overwrites an existing permission or removes role grants.

CREATE TEMPORARY TABLE yian_wms_v110_lock_guard
(
    lock_acquired TINYINT NOT NULL CHECK (lock_acquired = 1)
);
INSERT INTO yian_wms_v110_lock_guard (lock_acquired)
VALUES (GET_LOCK('yian_wms_schema_migration_v1_1_0', 300));

DELIMITER $$

DROP PROCEDURE IF EXISTS yian_wms_apply_v110_permissions$$
CREATE PROCEDURE yian_wms_apply_v110_permissions()
BEGIN
    DECLARE v_parent_id BIGINT;
    DECLARE v_menu_id BIGINT;
    DECLARE v_candidate BIGINT;
    DECLARE v_wms_root_id BIGINT;
    DECLARE v_valid_count BIGINT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT MIN(menu_id) INTO v_parent_id
      FROM sys_menu WHERE perms = 'wms:stock:list' AND menu_type = 'C';
    IF v_parent_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Missing WMS stock menu for V1.1.0 migration';
    END IF;

    SELECT MIN(menu_id) INTO v_menu_id FROM sys_menu WHERE perms = 'wms:stock:transfer';
    IF v_menu_id IS NULL THEN
        SET v_candidate = 2142;
        IF EXISTS (SELECT 1 FROM sys_menu WHERE menu_id = v_candidate) THEN
            SELECT COALESCE(MAX(menu_id), 2199) + 1 INTO v_candidate FROM sys_menu;
        END IF;
        INSERT INTO sys_menu
            (menu_id, menu_name, parent_id, order_num, path, component, query, route_name,
             is_frame, is_cache, menu_type, visible, status, perms, icon,
             create_by, create_time, update_by, update_time, remark)
        VALUES
            (v_candidate, '库存调拨', v_parent_id, 3, '#', '', '', '',
             1, 0, 'F', '0', '0', 'wms:stock:transfer', '#',
             'admin', NOW(), '', NULL, 'WMS库存直接调拨动作权限');
        SET v_menu_id = v_candidate;
    END IF;
    INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
        SELECT role_id, v_menu_id FROM sys_role
         WHERE role_key = 'admin' AND status = '0' AND del_flag = '0';

    SELECT MIN(menu_id) INTO v_menu_id FROM sys_menu WHERE perms = 'wms:stock:adjust';
    IF v_menu_id IS NULL THEN
        SET v_candidate = 2143;
        IF EXISTS (SELECT 1 FROM sys_menu WHERE menu_id = v_candidate) THEN
            SELECT COALESCE(MAX(menu_id), 2199) + 1 INTO v_candidate FROM sys_menu;
        END IF;
        INSERT INTO sys_menu
            (menu_id, menu_name, parent_id, order_num, path, component, query, route_name,
             is_frame, is_cache, menu_type, visible, status, perms, icon,
             create_by, create_time, update_by, update_time, remark)
        VALUES
            (v_candidate, '库存盘点', v_parent_id, 4, '#', '', '', '',
             1, 0, 'F', '0', '0', 'wms:stock:adjust', '#',
             'admin', NOW(), '', NULL, 'WMS库存直接盘点动作权限');
        SET v_menu_id = v_candidate;
    END IF;
    INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
        SELECT role_id, v_menu_id FROM sys_role
         WHERE role_key = 'admin' AND status = '0' AND del_flag = '0';

    SELECT MIN(menu_id) INTO v_parent_id
      FROM sys_menu WHERE perms = 'wms:receipt:list' AND menu_type = 'C';
    IF v_parent_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Missing WMS receipt menu for V1.1.0 migration';
    END IF;
    SELECT MIN(menu_id) INTO v_menu_id FROM sys_menu WHERE perms = 'wms:receipt:cancel';
    IF v_menu_id IS NULL THEN
        SET v_candidate = 2156;
        IF EXISTS (SELECT 1 FROM sys_menu WHERE menu_id = v_candidate) THEN
            SELECT COALESCE(MAX(menu_id), 2199) + 1 INTO v_candidate FROM sys_menu;
        END IF;
        INSERT INTO sys_menu
            (menu_id, menu_name, parent_id, order_num, path, component, query, route_name,
             is_frame, is_cache, menu_type, visible, status, perms, icon,
             create_by, create_time, update_by, update_time, remark)
        VALUES
            (v_candidate, '取消入库', v_parent_id, 7, '#', '', '', '',
             1, 0, 'F', '0', '0', 'wms:receipt:cancel', '#',
             'admin', NOW(), '', NULL, 'WMS入库单取消动作权限');
        SET v_menu_id = v_candidate;
    END IF;
    INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
        SELECT role_id, v_menu_id FROM sys_role
         WHERE role_key = 'admin' AND status = '0' AND del_flag = '0';

    SELECT MIN(menu_id) INTO v_parent_id
      FROM sys_menu WHERE perms = 'wms:shipment:list' AND menu_type = 'C';
    IF v_parent_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Missing WMS shipment menu for V1.1.0 migration';
    END IF;
    SELECT MIN(menu_id) INTO v_menu_id FROM sys_menu WHERE perms = 'wms:shipment:cancel';
    IF v_menu_id IS NULL THEN
        SET v_candidate = 2166;
        IF EXISTS (SELECT 1 FROM sys_menu WHERE menu_id = v_candidate) THEN
            SELECT COALESCE(MAX(menu_id), 2199) + 1 INTO v_candidate FROM sys_menu;
        END IF;
        INSERT INTO sys_menu
            (menu_id, menu_name, parent_id, order_num, path, component, query, route_name,
             is_frame, is_cache, menu_type, visible, status, perms, icon,
             create_by, create_time, update_by, update_time, remark)
        VALUES
            (v_candidate, '取消出库', v_parent_id, 7, '#', '', '', '',
             1, 0, 'F', '0', '0', 'wms:shipment:cancel', '#',
             'admin', NOW(), '', NULL, 'WMS出库单取消动作权限');
        SET v_menu_id = v_candidate;
    END IF;
    INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
        SELECT role_id, v_menu_id FROM sys_role
         WHERE role_key = 'admin' AND status = '0' AND del_flag = '0';

    -- Add WMS navigation/read grants to the built-in common role; preserve any administrator customizations.
    SELECT MIN(menu_id) INTO v_wms_root_id
      FROM sys_menu WHERE parent_id = 0 AND path = 'wms' AND menu_type = 'M';
    IF v_wms_root_id IS NOT NULL THEN
        INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
        SELECT r.role_id, m.menu_id
          FROM sys_role r
          JOIN sys_menu m
            ON m.menu_id = v_wms_root_id
            OR (m.parent_id = v_wms_root_id AND m.menu_type = 'C')
            OR (m.menu_type = 'F' AND m.perms IN (
                'wms:warehouse:query', 'wms:area:query', 'wms:location:query',
                'wms:item:query', 'wms:stock:query', 'wms:receipt:query', 'wms:shipment:query'
            ))
         WHERE r.role_key = 'common' AND r.status = '0' AND r.del_flag = '0';
    END IF;

    SELECT COUNT(*) INTO v_valid_count
      FROM sys_menu m
      JOIN sys_menu p ON p.menu_id = m.parent_id
     WHERE m.menu_type = 'F' AND m.status = '0'
       AND (
            (m.perms = 'wms:stock:transfer' AND p.perms = 'wms:stock:list')
         OR (m.perms = 'wms:stock:adjust' AND p.perms = 'wms:stock:list')
         OR (m.perms = 'wms:receipt:cancel' AND p.perms = 'wms:receipt:list')
         OR (m.perms = 'wms:shipment:cancel' AND p.perms = 'wms:shipment:list')
       );
    IF v_valid_count <> 4 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'V1.1.0 WMS action permission validation failed';
    END IF;

    SELECT COUNT(DISTINCT m.perms) INTO v_valid_count
      FROM sys_role r
      JOIN sys_role_menu rm ON rm.role_id = r.role_id
      JOIN sys_menu m ON m.menu_id = rm.menu_id
     WHERE r.role_key = 'admin'
       AND m.perms IN ('wms:stock:transfer', 'wms:stock:adjust',
                       'wms:receipt:cancel', 'wms:shipment:cancel');
    IF v_valid_count <> 4 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'V1.1.0 admin action grant validation failed';
    END IF;

    COMMIT;
END$$

CALL yian_wms_apply_v110_permissions()$$
DROP PROCEDURE yian_wms_apply_v110_permissions$$

DELIMITER ;

DO RELEASE_LOCK('yian_wms_schema_migration_v1_1_0');
DROP TEMPORARY TABLE yian_wms_v110_lock_guard;
