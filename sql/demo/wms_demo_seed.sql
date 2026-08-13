-- 以安WMS 智能硬件履约演示数据
-- 适用：MySQL 8.x；执行顺序：01 系统表 -> 02 Quartz -> 03 WMS 表 -> 04 V1.1 扩展 -> 05 本脚本。
-- 安全边界：指纹变更时对 DEMO-* 仓库/库位/物料/批次任一维度做演示 scope rebase。
-- 本脚本会清理该 scope 内的运行时测试单据、库存与全部流水，仅可用于已备份的测试/演示环境。
-- 幂等与一致性：命名锁串行化，单事务写入，提交前断言；任一异常均回滚并释放锁。

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE TEMPORARY TABLE yian_wms_demo_seed_lock_guard
(
    lock_acquired TINYINT NOT NULL CHECK (lock_acquired = 1)
);
INSERT INTO yian_wms_demo_seed_lock_guard (lock_acquired)
VALUES (GET_LOCK('yian_wms_demo_seed_v1', 300));

DELIMITER $$

DROP PROCEDURE IF EXISTS seed_yian_wms_demo$$
CREATE PROCEDURE seed_yian_wms_demo()
BEGIN
    DECLARE v_error_count BIGINT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    DROP TEMPORARY TABLE IF EXISTS demo_stock_meta;
    CREATE TEMPORARY TABLE demo_stock_meta
    (
        warehouse_code  VARCHAR(32)   NOT NULL,
        location_code   VARCHAR(32)   NOT NULL,
        item_code       VARCHAR(32)   NOT NULL,
        batch_no        VARCHAR(64)   NOT NULL,
        production_date DATE                   DEFAULT NULL,
        expiry_date     DATE                   DEFAULT NULL,
        locked_quantity DECIMAL(18,4) NOT NULL DEFAULT 0,
        PRIMARY KEY (warehouse_code, location_code, item_code, batch_no)
    ) ENGINE=InnoDB;

    DROP TEMPORARY TABLE IF EXISTS demo_movement_plan;
    CREATE TEMPORARY TABLE demo_movement_plan
    (
        movement_seq    INT           NOT NULL,
        biz_type        VARCHAR(20)   NOT NULL,
        biz_no          VARCHAR(32)   NOT NULL,
        warehouse_code  VARCHAR(32)   NOT NULL,
        location_code   VARCHAR(32)   NOT NULL,
        item_code       VARCHAR(32)   NOT NULL,
        batch_no        VARCHAR(64)   NOT NULL,
        change_qty      DECIMAL(18,4) NOT NULL,
        operation_time  DATETIME      NOT NULL,
        remark          VARCHAR(500)           DEFAULT NULL,
        PRIMARY KEY (movement_seq),
        KEY idx_demo_movement_dimension (warehouse_code, location_code, item_code, batch_no)
    ) ENGINE=InnoDB;

    -- 以任一 DEMO 维度为边界完整重建，防止运行时生成的非 DEMO 业务号流水遗留后导致账实不一。
    DELETE m
      FROM wms_stock_movement m
      LEFT JOIN wms_warehouse w ON w.warehouse_id = m.warehouse_id
      LEFT JOIN wms_location l ON l.location_id = m.location_id
      LEFT JOIN wms_area a ON a.area_id = l.area_id
      LEFT JOIN wms_item i ON i.item_id = m.item_id
     WHERE m.biz_no REGEXP '^DEMO-'
        OR w.warehouse_code REGEXP '^DEMO-'
        OR a.area_code REGEXP '^DEMO-'
        OR l.location_code REGEXP '^DEMO-'
        OR i.item_code REGEXP '^DEMO-'
        OR m.batch_no REGEXP '^DEMO-';

    -- 同步清理引用演示 scope 的测试单据，避免保留“已完成单据但对应流水已重置”的历史。
    DELETE r
      FROM wms_receipt r
      LEFT JOIN wms_warehouse w ON w.warehouse_id = r.warehouse_id
      LEFT JOIN wms_receipt_line rl ON rl.receipt_id = r.receipt_id
      LEFT JOIN wms_location l ON l.location_id = rl.location_id
      LEFT JOIN wms_area a ON a.area_id = l.area_id
      LEFT JOIN wms_item i ON i.item_id = rl.item_id
     WHERE r.receipt_no REGEXP '^DEMO-'
        OR w.warehouse_code REGEXP '^DEMO-'
        OR a.area_code REGEXP '^DEMO-'
        OR l.location_code REGEXP '^DEMO-'
        OR i.item_code REGEXP '^DEMO-'
        OR rl.batch_no REGEXP '^DEMO-';

    DELETE sh
      FROM wms_shipment sh
      LEFT JOIN wms_warehouse w ON w.warehouse_id = sh.warehouse_id
      LEFT JOIN wms_shipment_line sl ON sl.shipment_id = sh.shipment_id
      LEFT JOIN wms_location l ON l.location_id = sl.location_id
      LEFT JOIN wms_area a ON a.area_id = l.area_id
      LEFT JOIN wms_item i ON i.item_id = sl.item_id
     WHERE sh.shipment_no REGEXP '^DEMO-'
        OR w.warehouse_code REGEXP '^DEMO-'
        OR a.area_code REGEXP '^DEMO-'
        OR l.location_code REGEXP '^DEMO-'
        OR i.item_code REGEXP '^DEMO-'
        OR sl.batch_no REGEXP '^DEMO-';

    DELETE s
      FROM wms_stock s
      LEFT JOIN wms_warehouse w ON w.warehouse_id = s.warehouse_id
      LEFT JOIN wms_location l ON l.location_id = s.location_id
      LEFT JOIN wms_area a ON a.area_id = l.area_id
      LEFT JOIN wms_item i ON i.item_id = s.item_id
     WHERE w.warehouse_code REGEXP '^DEMO-'
        OR a.area_code REGEXP '^DEMO-'
        OR l.location_code REGEXP '^DEMO-'
        OR i.item_code REGEXP '^DEMO-'
        OR s.batch_no REGEXP '^DEMO-';

    -- 引用清空后删除不在当前白名单的旧 DEMO 主数据，兼容旧版种子升级。
    DELETE l
      FROM wms_location l
      JOIN wms_warehouse w ON w.warehouse_id = l.warehouse_id
      JOIN wms_area a ON a.area_id = l.area_id
     WHERE (w.warehouse_code REGEXP '^DEMO-' OR a.area_code REGEXP '^DEMO-' OR l.location_code REGEXP '^DEMO-')
       AND NOT (
            (w.warehouse_code = 'DEMO-WH-SH' AND l.location_code IN (
                'DEMO-SH-RCV-01', 'DEMO-SH-A-01', 'DEMO-SH-A-02', 'DEMO-SH-A-03',
                'DEMO-SH-FRZ-01', 'DEMO-SH-PICK-01', 'DEMO-SH-SHIP-01',
                'DEMO-SH-RET-01', 'DEMO-SH-DEF-01'
            ))
            OR
            (w.warehouse_code = 'DEMO-WH-SZ' AND l.location_code IN (
                'DEMO-SZ-RCV-01', 'DEMO-SZ-B-01', 'DEMO-SZ-B-02',
                'DEMO-SZ-PICK-01', 'DEMO-SZ-SHIP-01'
            ))
       );

    DELETE a
      FROM wms_area a
      JOIN wms_warehouse w ON w.warehouse_id = a.warehouse_id
     WHERE (w.warehouse_code REGEXP '^DEMO-' OR a.area_code REGEXP '^DEMO-')
       AND NOT (
            (w.warehouse_code = 'DEMO-WH-SH' AND a.area_code IN (
                'DEMO-SH-RCV', 'DEMO-SH-STO', 'DEMO-SH-PICK', 'DEMO-SH-SHIP', 'DEMO-SH-RET'
            ))
            OR
            (w.warehouse_code = 'DEMO-WH-SZ' AND a.area_code IN (
                'DEMO-SZ-RCV', 'DEMO-SZ-STO', 'DEMO-SZ-PICK', 'DEMO-SZ-SHIP'
            ))
       );

    DELETE FROM wms_warehouse
     WHERE warehouse_code REGEXP '^DEMO-'
       AND warehouse_code NOT IN ('DEMO-WH-SH', 'DEMO-WH-SZ', 'DEMO-WH-BJ');

    DELETE FROM wms_item
     WHERE item_code REGEXP '^DEMO-'
       AND item_code NOT IN (
            'DEMO-IOT-GW', 'DEMO-SCAN-PDA', 'DEMO-SENSOR-TEMP', 'DEMO-SENSOR-DOOR',
            'DEMO-CAMERA-AI', 'DEMO-LOCK-SMART', 'DEMO-PRINTER-LBL', 'DEMO-TAG-RFID',
            'DEMO-BATTERY-LT', 'DEMO-CABLE-TYPEC', 'DEMO-ADAPTER-65W',
            'DEMO-MOUNT-BRACKET', 'DEMO-PACK-CARTON', 'DEMO-SEAL-LABEL'
       );

    -- 三仓业务故事：上海中心仓、苏州电商仓启用；北京备件仓为规划停用仓且不被业务引用。
    INSERT INTO wms_warehouse
        (warehouse_code, warehouse_name, address, manager, phone, status,
         create_by, create_time, update_by, update_time, remark)
    VALUES
        ('DEMO-WH-SH', '上海智能硬件中心仓', '上海市浦东新区川沙路 5888 号', '周明远', '13800001001', '0', 'admin', NOW(), 'admin', NOW(), '演示数据：华东采购、质检、存储与门店履约中心'),
        ('DEMO-WH-SZ', '苏州电商履约仓',     '江苏省苏州市工业园区星湖街 328 号', '陈晓楠', '13800001002', '0', 'admin', NOW(), 'admin', NOW(), '演示数据：电商订单波次拣选与全国快递发运'),
        ('DEMO-WH-BJ', '北京备件仓（规划）', '北京市顺义区临空经济核心区',       '赵博文', '13800001003', '1', 'admin', NOW(), 'admin', NOW(), '演示数据：尚未启用，不配置库区且不承载任何业务')
    ON DUPLICATE KEY UPDATE
        warehouse_name = VALUES(warehouse_name), address = VALUES(address),
        manager = VALUES(manager), phone = VALUES(phone), status = VALUES(status),
        update_by = 'admin', update_time = NOW(), remark = VALUES(remark);

    -- 五类库区全部覆盖：RECEIVING / STORAGE / PICKING / SHIPPING / RETURN。
    INSERT INTO wms_area
        (warehouse_id, area_code, area_name, area_type, status, create_by, create_time, update_by, update_time, remark)
    SELECT w.warehouse_id, x.area_code, x.area_name, x.area_type, '0', 'admin', NOW(), 'admin', NOW(), x.remark
      FROM wms_warehouse w
      JOIN (
            SELECT 'DEMO-WH-SH' warehouse_code, 'DEMO-SH-RCV' area_code, '上海收货质检区' area_name, 'RECEIVING' area_type, '采购到货、退货验收' remark
            UNION ALL SELECT 'DEMO-WH-SH', 'DEMO-SH-STO', '上海智能设备存储区', 'STORAGE', '成品与配件批次存储'
            UNION ALL SELECT 'DEMO-WH-SH', 'DEMO-SH-PICK', '上海订单拣选区', 'PICKING', '门店与项目订单拣选'
            UNION ALL SELECT 'DEMO-WH-SH', 'DEMO-SH-SHIP', '上海集货发运区', 'SHIPPING', '复核、集货与装车'
            UNION ALL SELECT 'DEMO-WH-SH', 'DEMO-SH-RET', '上海售后退货区', 'RETURN', '售后检测与不良品隔离'
            UNION ALL SELECT 'DEMO-WH-SZ', 'DEMO-SZ-RCV', '苏州电商收货区', 'RECEIVING', '电商补货验收'
            UNION ALL SELECT 'DEMO-WH-SZ', 'DEMO-SZ-STO', '苏州电商存储区', 'STORAGE', '电商可售库存'
            UNION ALL SELECT 'DEMO-WH-SZ', 'DEMO-SZ-PICK', '苏州波次拣选区', 'PICKING', '按波次拣选订单'
            UNION ALL SELECT 'DEMO-WH-SZ', 'DEMO-SZ-SHIP', '苏州快递发运区', 'SHIPPING', '快递称重与交接'
      ) x ON x.warehouse_code = w.warehouse_code
    ON DUPLICATE KEY UPDATE
        area_name = VALUES(area_name), area_type = VALUES(area_type), status = VALUES(status),
        update_by = 'admin', update_time = NOW(), remark = VALUES(remark);

    -- 14 个库位，含冷冻、正常退货、不良品和停用库位；不良品位与停用位均不放演示库存。
    INSERT INTO wms_location
        (warehouse_id, area_id, location_code, location_name, location_type, capacity_qty,
         status, create_by, create_time, update_by, update_time, remark)
    SELECT w.warehouse_id, a.area_id, x.location_code, x.location_name, x.location_type,
           x.capacity_qty, x.status, 'admin', NOW(), 'admin', NOW(), x.remark
      FROM wms_warehouse w
      JOIN (
            SELECT 'DEMO-WH-SH' warehouse_code, 'DEMO-SH-RCV' area_code, 'DEMO-SH-RCV-01' location_code, '上海收货暂存位 01' location_name, 'NORMAL' location_type, 500.0000 capacity_qty, '0' status, '到货待检' remark
            UNION ALL SELECT 'DEMO-WH-SH', 'DEMO-SH-STO', 'DEMO-SH-A-01', '上海 A 区高值设备位', 'NORMAL', 300.0000, '0', '网关、手持终端与线材'
            UNION ALL SELECT 'DEMO-WH-SH', 'DEMO-SH-STO', 'DEMO-SH-A-02', '上海 A 区传感配件位', 'NORMAL', 800.0000, '0', '传感器、电子标签与电源'
            UNION ALL SELECT 'DEMO-WH-SH', 'DEMO-SH-STO', 'DEMO-SH-A-03', '上海 A 区维护停用位', 'NORMAL', 300.0000, '1', '货架年度维护，禁止上架'
            UNION ALL SELECT 'DEMO-WH-SH', 'DEMO-SH-STO', 'DEMO-SH-FRZ-01', '上海低温器件位', 'FROZEN', 120.0000, '0', '低温电池恒温保管'
            UNION ALL SELECT 'DEMO-WH-SH', 'DEMO-SH-PICK', 'DEMO-SH-PICK-01', '上海项目订单拣选位', 'NORMAL', 400.0000, '0', '项目订单拣选'
            UNION ALL SELECT 'DEMO-WH-SH', 'DEMO-SH-SHIP', 'DEMO-SH-SHIP-01', '上海发运暂存位 01', 'NORMAL', 600.0000, '0', '待发运订单集货'
            UNION ALL SELECT 'DEMO-WH-SH', 'DEMO-SH-RET', 'DEMO-SH-RET-01', '上海售后合格品复入位', 'NORMAL', 400.0000, '0', '退货验收合格品存放与复入库'
            UNION ALL SELECT 'DEMO-WH-SH', 'DEMO-SH-RET', 'DEMO-SH-DEF-01', '上海不良品隔离位', 'DEFECTIVE', 100.0000, '0', '不良品隔离；演示库存保持为空'
            UNION ALL SELECT 'DEMO-WH-SZ', 'DEMO-SZ-RCV', 'DEMO-SZ-RCV-01', '苏州补货暂存位 01', 'NORMAL', 500.0000, '0', '到仓补货待检'
            UNION ALL SELECT 'DEMO-WH-SZ', 'DEMO-SZ-STO', 'DEMO-SZ-B-01', '苏州 B 区设备位', 'NORMAL', 500.0000, '0', '小型智能设备'
            UNION ALL SELECT 'DEMO-WH-SZ', 'DEMO-SZ-STO', 'DEMO-SZ-B-02', '苏州 B 区配件包材位', 'NORMAL', 1200.0000, '0', '配件与包材'
            UNION ALL SELECT 'DEMO-WH-SZ', 'DEMO-SZ-PICK', 'DEMO-SZ-PICK-01', '苏州波次拣选位 01', 'NORMAL', 600.0000, '0', '电商波次拣选'
            UNION ALL SELECT 'DEMO-WH-SZ', 'DEMO-SZ-SHIP', 'DEMO-SZ-SHIP-01', '苏州快递交接位 01', 'NORMAL', 800.0000, '0', '快递交接暂存'
      ) x ON x.warehouse_code = w.warehouse_code
      JOIN wms_area a ON a.warehouse_id = w.warehouse_id AND a.area_code = x.area_code
    ON DUPLICATE KEY UPDATE
        area_id = VALUES(area_id), location_name = VALUES(location_name),
        location_type = VALUES(location_type), capacity_qty = VALUES(capacity_qty), status = VALUES(status),
        update_by = 'admin', update_time = NOW(), remark = VALUES(remark);

    -- 14 个智能硬件、配件及包材物料。
    INSERT INTO wms_item
        (item_code, item_name, category, specification, unit, barcode, min_stock, max_stock,
         status, create_by, create_time, update_by, update_time, remark)
    VALUES
        ('DEMO-IOT-GW',       '边缘计算网关',       '智能终端', 'YAG-500 / 4G+WiFi',       '台', '6979000100011',   8.0000,  80.0000, '0', 'admin', NOW(), 'admin', NOW(), '演示物料：门店物联网数据汇聚'),
        ('DEMO-SCAN-PDA',     '工业手持终端',       '智能终端', 'YAP-6 / Android 14',       '台', '6979000100028',  10.0000, 100.0000, '0', 'admin', NOW(), 'admin', NOW(), '演示物料：扫码拣选与盘点'),
        ('DEMO-SENSOR-TEMP',  '温湿度传感器',       '传感器',   'YAT-2 / ±0.3℃',            '个', '6979000100035',  20.0000, 200.0000, '0', 'admin', NOW(), 'admin', NOW(), '演示物料：含多批次、临期与过期批次'),
        ('DEMO-SENSOR-DOOR',  '无线门磁传感器',     '传感器',   'YAD-1 / LoRa',             '个', '6979000100042',  30.0000, 300.0000, '0', 'admin', NOW(), 'admin', NOW(), '演示物料：盘盈调整'),
        ('DEMO-CAMERA-AI',    'AI盘点摄像机',       '智能终端', 'YAC-8 / 8MP',              '台', '6979000100059',   6.0000,  60.0000, '0', 'admin', NOW(), 'admin', NOW(), '演示物料：视觉盘点'),
        ('DEMO-LOCK-SMART',   '智能电子锁',         '智能终端', 'YAL-3 / NB-IoT',           '把', '6979000100066',  15.0000, 150.0000, '0', 'admin', NOW(), 'admin', NOW(), '演示物料：在途资产防护'),
        ('DEMO-PRINTER-LBL',  '热敏标签打印机',     '作业设备', 'YAP-80 / 203dpi',           '台', '6979000100073',   5.0000,  50.0000, '0', 'admin', NOW(), 'admin', NOW(), '演示物料：物流标签打印'),
        ('DEMO-TAG-RFID',     '超高频RFID标签',     '耗材',     'EPC Gen2 / 70×20mm',        '枚', '6979000100080', 100.0000, 2000.0000, '0', 'admin', NOW(), 'admin', NOW(), '演示物料：资产自动识别'),
        ('DEMO-BATTERY-LT',   '工业低温电池组',     '能源配件', '24V 20Ah / -30℃',          '组', '6979000100097',  20.0000, 120.0000, '0', 'admin', NOW(), 'admin', NOW(), '演示物料：低温保管、临期且低库存'),
        ('DEMO-CABLE-TYPEC',  '工业Type-C数据线',   '通用配件', '1.5m / 编织屏蔽',           '根', '6979000100103',  50.0000, 500.0000, '0', 'admin', NOW(), 'admin', NOW(), '演示物料：盘亏调整'),
        ('DEMO-ADAPTER-65W',  '65W电源适配器',      '能源配件', 'PD 3.0 / 国标',             '个', '6979000100110',  25.0000, 250.0000, '0', 'admin', NOW(), 'admin', NOW(), '演示物料：跨仓批次'),
        ('DEMO-MOUNT-BRACKET','设备安装支架',       '安装配件', '铝合金 / 可调角度',          '套', '6979000100127',  40.0000, 400.0000, '0', 'admin', NOW(), 'admin', NOW(), '演示物料：低库存预警'),
        ('DEMO-PACK-CARTON',  '智能设备运输箱',     '包装材料', '600×400×350mm / 五层',      '个', '6979000100134',  50.0000, 600.0000, '0', 'admin', NOW(), 'admin', NOW(), '演示物料：电商发运包材'),
        ('DEMO-SEAL-LABEL',   '防拆封签',           '包装材料', 'VOID / 30×80mm',           '枚', '6979000100141', 100.0000, 2000.0000, '0', 'admin', NOW(), 'admin', NOW(), '演示物料：高值设备封装')
    ON DUPLICATE KEY UPDATE
        item_name = VALUES(item_name), category = VALUES(category), specification = VALUES(specification),
        unit = VALUES(unit), barcode = VALUES(barcode), min_stock = VALUES(min_stock), max_stock = VALUES(max_stock),
        status = VALUES(status), update_by = 'admin', update_time = NOW(), remark = VALUES(remark);

    -- 5 张入库单：三类入库齐全，并覆盖已完成、草稿、已取消。
    INSERT INTO wms_receipt
        (receipt_no, receipt_type, warehouse_id, supplier_name, receipt_date, status, total_qty,
         create_by, create_time, update_by, update_time, remark)
    SELECT x.receipt_no, x.receipt_type, w.warehouse_id, x.supplier_name, x.receipt_date,
           x.status, x.total_qty, 'admin', x.receipt_date, 'admin', x.update_time, x.remark
      FROM wms_warehouse w
      JOIN (
            SELECT 'DEMO-IN-001' receipt_no, 'PURCHASE' receipt_type, 'DEMO-WH-SH' warehouse_code, '上海智联制造有限公司' supplier_name, NOW() - INTERVAL 6 DAY receipt_date, 'COMPLETED' status, 120.0000 total_qty, NOW() - INTERVAL 6 DAY update_time, '采购到货：网关、手持终端和RFID标签' remark
            UNION ALL SELECT 'DEMO-IN-002', 'RETURN', 'DEMO-WH-SH', '华东售后服务中心', NOW() - INTERVAL 3 DAY, 'COMPLETED', 18.0000, NOW() - INTERVAL 3 DAY, '客户退回检测合格后重新入库'
            UNION ALL SELECT 'DEMO-IN-003', 'OTHER', 'DEMO-WH-SZ', '内部调拨交接组', NOW(), 'COMPLETED', 75.0000, NOW(), '苏州电商仓今日补货入库'
            UNION ALL SELECT 'DEMO-IN-004', 'PURCHASE', 'DEMO-WH-SH', '上海视觉科技有限公司', NOW() + INTERVAL 1 DAY, 'DRAFT', 24.0000, NULL, '待到货采购单：摄像机与数据线'
            UNION ALL SELECT 'DEMO-IN-005', 'RETURN', 'DEMO-WH-SZ', '华东电商退货中心', NOW() - INTERVAL 2 DAY, 'CANCELLED', 5.0000, NOW() - INTERVAL 1 DAY, '重复创建后取消，保留单据用于状态演示'
      ) x ON x.warehouse_code = w.warehouse_code;

    INSERT INTO wms_receipt_line
        (receipt_id, item_id, location_id, batch_no, production_date, expiry_date, planned_qty, received_qty)
    SELECT r.receipt_id, i.item_id, l.location_id, x.batch_no, x.production_date, x.expiry_date, x.planned_qty, x.received_qty
      FROM wms_receipt r
      JOIN (
            SELECT 'DEMO-IN-001' receipt_no, 'DEMO-IOT-GW' item_code, 'DEMO-SH-A-01' location_code, 'DEMO-GW-2605' batch_no, CURDATE() - INTERVAL 100 DAY production_date, CURDATE() + INTERVAL 600 DAY expiry_date, 8.0000 planned_qty, 8.0000 received_qty
            UNION ALL SELECT 'DEMO-IN-001', 'DEMO-SCAN-PDA', 'DEMO-SH-A-01', 'DEMO-PDA-2606', CURDATE() - INTERVAL 70 DAY, CURDATE() + INTERVAL 400 DAY, 12.0000, 12.0000
            UNION ALL SELECT 'DEMO-IN-001', 'DEMO-TAG-RFID', 'DEMO-SH-A-02', 'DEMO-RFID-2607', CURDATE() - INTERVAL 35 DAY, NULL, 100.0000, 100.0000
            UNION ALL SELECT 'DEMO-IN-002', 'DEMO-SENSOR-DOOR', 'DEMO-SH-RET-01', 'DEMO-DOOR-2607', CURDATE() - INTERVAL 45 DAY, CURDATE() + INTERVAL 365 DAY, 10.0000, 10.0000
            UNION ALL SELECT 'DEMO-IN-002', 'DEMO-LOCK-SMART', 'DEMO-SH-RET-01', 'DEMO-LOCK-2607', CURDATE() - INTERVAL 40 DAY, CURDATE() + INTERVAL 365 DAY, 8.0000, 8.0000
            UNION ALL SELECT 'DEMO-IN-003', 'DEMO-PRINTER-LBL', 'DEMO-SZ-B-01', 'DEMO-PRN-2606', CURDATE() - INTERVAL 65 DAY, CURDATE() + INTERVAL 365 DAY, 5.0000, 5.0000
            UNION ALL SELECT 'DEMO-IN-003', 'DEMO-ADAPTER-65W', 'DEMO-SZ-B-02', 'DEMO-ADP-2606', CURDATE() - INTERVAL 75 DAY, CURDATE() + INTERVAL 365 DAY, 20.0000, 20.0000
            UNION ALL SELECT 'DEMO-IN-003', 'DEMO-PACK-CARTON', 'DEMO-SZ-B-02', 'DEMO-BOX-2607', CURDATE() - INTERVAL 30 DAY, NULL, 50.0000, 50.0000
            UNION ALL SELECT 'DEMO-IN-004', 'DEMO-CAMERA-AI', 'DEMO-SH-A-02', 'DEMO-CAM-2608', CURDATE(), CURDATE() + INTERVAL 365 DAY, 4.0000, 0.0000
            UNION ALL SELECT 'DEMO-IN-004', 'DEMO-CABLE-TYPEC', 'DEMO-SH-A-01', 'DEMO-CABLE-2608', CURDATE(), NULL, 20.0000, 0.0000
            UNION ALL SELECT 'DEMO-IN-005', 'DEMO-MOUNT-BRACKET', 'DEMO-SZ-B-01', 'DEMO-BRK-2607', CURDATE() - INTERVAL 30 DAY, NULL, 5.0000, 0.0000
      ) x ON x.receipt_no = r.receipt_no
      JOIN wms_item i ON i.item_code = x.item_code
      JOIN wms_location l ON l.location_code = x.location_code
                            AND l.warehouse_id = r.warehouse_id;

    -- 5 张出库单：销售、退供、其他三类齐全，并覆盖已完成、草稿、已取消。
    INSERT INTO wms_shipment
        (shipment_no, shipment_type, warehouse_id, customer_name, shipment_date, status, total_qty,
         create_by, create_time, update_by, update_time, remark)
    SELECT x.shipment_no, x.shipment_type, w.warehouse_id, x.customer_name, x.shipment_date,
           x.status, x.total_qty, 'admin', x.shipment_date, 'admin', x.update_time, x.remark
      FROM wms_warehouse w
      JOIN (
            SELECT 'DEMO-OUT-001' shipment_no, 'SALE' shipment_type, 'DEMO-WH-SH' warehouse_code, '杭州未来零售有限公司' customer_name, NOW() - INTERVAL 5 DAY shipment_date, 'COMPLETED' status, 71.0000 total_qty, NOW() - INTERVAL 5 DAY update_time, '门店数字化项目首批交付' remark
            UNION ALL SELECT 'DEMO-OUT-002', 'RETURN', 'DEMO-WH-SH', '华东配件供应中心', NOW() - INTERVAL 2 DAY, 'COMPLETED', 7.0000, NOW() - INTERVAL 2 DAY, '质检抽样后退回供应商'
            UNION ALL SELECT 'DEMO-OUT-003', 'OTHER', 'DEMO-WH-SZ', '上海产品体验中心', NOW(), 'COMPLETED', 27.0000, NOW(), '今日展厅样机与包装物内部领用'
            UNION ALL SELECT 'DEMO-OUT-004', 'SALE', 'DEMO-WH-SH', '南京智慧园区有限公司', NOW() + INTERVAL 1 DAY, 'DRAFT', 12.0000, NULL, '待审核销售订单：摄像机与数据线'
            UNION ALL SELECT 'DEMO-OUT-005', 'RETURN', 'DEMO-WH-SZ', '苏州设备配件厂', NOW() - INTERVAL 1 DAY, 'CANCELLED', 3.0000, NOW(), '供应商确认无需退货，单据取消'
      ) x ON x.warehouse_code = w.warehouse_code;

    INSERT INTO wms_shipment_line
        (shipment_id, item_id, location_id, batch_no, production_date, expiry_date, planned_qty, shipped_qty)
    SELECT s.shipment_id, i.item_id, l.location_id, x.batch_no, x.production_date, x.expiry_date, x.planned_qty, x.shipped_qty
      FROM wms_shipment s
      JOIN (
            SELECT 'DEMO-OUT-001' shipment_no, 'DEMO-IOT-GW' item_code, 'DEMO-SH-A-01' location_code, 'DEMO-GW-2605' batch_no, CURDATE() - INTERVAL 100 DAY production_date, CURDATE() + INTERVAL 600 DAY expiry_date, 4.0000 planned_qty, 4.0000 shipped_qty
            UNION ALL SELECT 'DEMO-OUT-001', 'DEMO-SCAN-PDA', 'DEMO-SH-A-01', 'DEMO-PDA-2606', CURDATE() - INTERVAL 70 DAY, CURDATE() + INTERVAL 400 DAY, 7.0000, 7.0000
            UNION ALL SELECT 'DEMO-OUT-001', 'DEMO-TAG-RFID', 'DEMO-SH-A-02', 'DEMO-RFID-2607', CURDATE() - INTERVAL 35 DAY, NULL, 60.0000, 60.0000
            UNION ALL SELECT 'DEMO-OUT-002', 'DEMO-ADAPTER-65W', 'DEMO-SH-A-02', 'DEMO-ADP-2606', CURDATE() - INTERVAL 75 DAY, CURDATE() + INTERVAL 365 DAY, 5.0000, 5.0000
            UNION ALL SELECT 'DEMO-OUT-002', 'DEMO-BATTERY-LT', 'DEMO-SH-FRZ-01', 'DEMO-BAT-2607', CURDATE() - INTERVAL 50 DAY, CURDATE() + INTERVAL 25 DAY, 2.0000, 2.0000
            UNION ALL SELECT 'DEMO-OUT-003', 'DEMO-PRINTER-LBL', 'DEMO-SZ-B-01', 'DEMO-PRN-2606', CURDATE() - INTERVAL 65 DAY, CURDATE() + INTERVAL 365 DAY, 2.0000, 2.0000
            UNION ALL SELECT 'DEMO-OUT-003', 'DEMO-PACK-CARTON', 'DEMO-SZ-B-02', 'DEMO-BOX-2607', CURDATE() - INTERVAL 30 DAY, NULL, 25.0000, 25.0000
            UNION ALL SELECT 'DEMO-OUT-004', 'DEMO-CAMERA-AI', 'DEMO-SH-A-02', 'DEMO-CAM-2606', CURDATE() - INTERVAL 70 DAY, CURDATE() + INTERVAL 365 DAY, 2.0000, 0.0000
            UNION ALL SELECT 'DEMO-OUT-004', 'DEMO-CABLE-TYPEC', 'DEMO-SH-A-01', 'DEMO-CABLE-2607', CURDATE() - INTERVAL 40 DAY, NULL, 10.0000, 0.0000
            UNION ALL SELECT 'DEMO-OUT-005', 'DEMO-MOUNT-BRACKET', 'DEMO-SZ-B-01', 'DEMO-BRK-2607', CURDATE() - INTERVAL 30 DAY, NULL, 3.0000, 0.0000
      ) x ON x.shipment_no = s.shipment_no
      JOIN wms_item i ON i.item_code = x.item_code
      JOIN wms_location l ON l.location_code = x.location_code
                            AND l.warehouse_id = s.warehouse_id;

    -- 17 个库存维度的批次属性。包含多批次、20天内临期、已过期与低库存；演示初始状态不预占库存。
    INSERT INTO demo_stock_meta VALUES
        ('DEMO-WH-SH', 'DEMO-SH-A-01',    'DEMO-IOT-GW',        'DEMO-GW-2605',    CURDATE() - INTERVAL 100 DAY, CURDATE() + INTERVAL 600 DAY, 0.0000),
        ('DEMO-WH-SH', 'DEMO-SH-A-01',    'DEMO-SCAN-PDA',      'DEMO-PDA-2606',   CURDATE() - INTERVAL 70 DAY,  CURDATE() + INTERVAL 400 DAY, 0.0000),
        ('DEMO-WH-SH', 'DEMO-SH-A-02',    'DEMO-SENSOR-TEMP',   'DEMO-TEMP-2607',  CURDATE() - INTERVAL 40 DAY,  CURDATE() + INTERVAL 20 DAY,  0.0000),
        ('DEMO-WH-SH', 'DEMO-SH-A-02',    'DEMO-SENSOR-TEMP',   'DEMO-TEMP-2507',  CURDATE() - INTERVAL 400 DAY, CURDATE() - INTERVAL 15 DAY,  0.0000),
        ('DEMO-WH-SH', 'DEMO-SH-RET-01',  'DEMO-SENSOR-DOOR',   'DEMO-DOOR-2607',  CURDATE() - INTERVAL 45 DAY,  CURDATE() + INTERVAL 365 DAY, 0.0000),
        ('DEMO-WH-SH', 'DEMO-SH-RET-01',  'DEMO-LOCK-SMART',    'DEMO-LOCK-2607',  CURDATE() - INTERVAL 40 DAY,  CURDATE() + INTERVAL 365 DAY, 0.0000),
        ('DEMO-WH-SH', 'DEMO-SH-A-02',    'DEMO-CAMERA-AI',     'DEMO-CAM-2606',   CURDATE() - INTERVAL 70 DAY,  CURDATE() + INTERVAL 365 DAY, 0.0000),
        ('DEMO-WH-SH', 'DEMO-SH-A-02',    'DEMO-TAG-RFID',      'DEMO-RFID-2607',  CURDATE() - INTERVAL 35 DAY,  NULL,                             0.0000),
        ('DEMO-WH-SH', 'DEMO-SH-FRZ-01',  'DEMO-BATTERY-LT',    'DEMO-BAT-2607',   CURDATE() - INTERVAL 50 DAY,  CURDATE() + INTERVAL 25 DAY,  0.0000),
        ('DEMO-WH-SH', 'DEMO-SH-A-01',    'DEMO-CABLE-TYPEC',   'DEMO-CABLE-2607', CURDATE() - INTERVAL 40 DAY,  NULL,                             0.0000),
        ('DEMO-WH-SH', 'DEMO-SH-A-02',    'DEMO-ADAPTER-65W',   'DEMO-ADP-2606',   CURDATE() - INTERVAL 75 DAY,  CURDATE() + INTERVAL 365 DAY, 0.0000),
        ('DEMO-WH-SZ', 'DEMO-SZ-B-01',    'DEMO-PRINTER-LBL',   'DEMO-PRN-2606',   CURDATE() - INTERVAL 65 DAY,  CURDATE() + INTERVAL 365 DAY, 0.0000),
        ('DEMO-WH-SZ', 'DEMO-SZ-B-01',    'DEMO-MOUNT-BRACKET', 'DEMO-BRK-2607',   CURDATE() - INTERVAL 30 DAY,  NULL,                             0.0000),
        ('DEMO-WH-SZ', 'DEMO-SZ-B-02',    'DEMO-PACK-CARTON',   'DEMO-BOX-2607',   CURDATE() - INTERVAL 30 DAY,  NULL,                             0.0000),
        ('DEMO-WH-SZ', 'DEMO-SZ-B-02',    'DEMO-SEAL-LABEL',    'DEMO-SEAL-2607',  CURDATE() - INTERVAL 25 DAY,  CURDATE() + INTERVAL 180 DAY,  0.0000),
        ('DEMO-WH-SZ', 'DEMO-SZ-B-02',    'DEMO-ADAPTER-65W',   'DEMO-ADP-2606',   CURDATE() - INTERVAL 75 DAY,  CURDATE() + INTERVAL 365 DAY,  0.0000),
        ('DEMO-WH-SZ', 'DEMO-SZ-B-01',    'DEMO-IOT-GW',        'DEMO-GW-2605',    CURDATE() - INTERVAL 100 DAY, CURDATE() + INTERVAL 600 DAY,  0.0000);

    -- 流水计划是库存的唯一演示事实来源；balance_qty 由窗口累计自动推导。
    INSERT INTO demo_movement_plan VALUES
        (101, 'INITIAL',     'DEMO-INIT-001', 'DEMO-WH-SH', 'DEMO-SH-A-01',    'DEMO-IOT-GW',        'DEMO-GW-2605',     12.0000, NOW() - INTERVAL 90 DAY, '演示期初：边缘网关'),
        (102, 'INITIAL',     'DEMO-INIT-002', 'DEMO-WH-SH', 'DEMO-SH-A-01',    'DEMO-SCAN-PDA',      'DEMO-PDA-2606',    18.0000, NOW() - INTERVAL 90 DAY, '演示期初：手持终端'),
        (103, 'INITIAL',     'DEMO-INIT-003', 'DEMO-WH-SH', 'DEMO-SH-A-02',    'DEMO-SENSOR-TEMP',   'DEMO-TEMP-2607',   40.0000, NOW() - INTERVAL 90 DAY, '演示期初：温湿度传感器新批次'),
        (104, 'INITIAL',     'DEMO-INIT-004', 'DEMO-WH-SH', 'DEMO-SH-A-02',    'DEMO-SENSOR-TEMP',   'DEMO-TEMP-2507',    6.0000, NOW() - INTERVAL 90 DAY, '演示期初：温湿度传感器过期批次'),
        (105, 'INITIAL',     'DEMO-INIT-005', 'DEMO-WH-SH', 'DEMO-SH-RET-01',  'DEMO-SENSOR-DOOR',   'DEMO-DOOR-2607',   25.0000, NOW() - INTERVAL 90 DAY, '演示期初：门磁传感器'),
        (106, 'INITIAL',     'DEMO-INIT-006', 'DEMO-WH-SH', 'DEMO-SH-RET-01',  'DEMO-LOCK-SMART',    'DEMO-LOCK-2607',   12.0000, NOW() - INTERVAL 90 DAY, '演示期初：智能电子锁'),
        (107, 'INITIAL',     'DEMO-INIT-007', 'DEMO-WH-SH', 'DEMO-SH-A-02',    'DEMO-CAMERA-AI',     'DEMO-CAM-2606',     8.0000, NOW() - INTERVAL 90 DAY, '演示期初：AI盘点摄像机'),
        (108, 'INITIAL',     'DEMO-INIT-008', 'DEMO-WH-SH', 'DEMO-SH-A-02',    'DEMO-TAG-RFID',      'DEMO-RFID-2607',  180.0000, NOW() - INTERVAL 90 DAY, '演示期初：RFID标签'),
        (109, 'INITIAL',     'DEMO-INIT-009', 'DEMO-WH-SH', 'DEMO-SH-FRZ-01',  'DEMO-BATTERY-LT',    'DEMO-BAT-2607',    14.0000, NOW() - INTERVAL 90 DAY, '演示期初：工业低温电池'),
        (110, 'INITIAL',     'DEMO-INIT-010', 'DEMO-WH-SH', 'DEMO-SH-A-01',    'DEMO-CABLE-TYPEC',   'DEMO-CABLE-2607',  80.0000, NOW() - INTERVAL 90 DAY, '演示期初：Type-C数据线'),
        (111, 'INITIAL',     'DEMO-INIT-011', 'DEMO-WH-SH', 'DEMO-SH-A-02',    'DEMO-ADAPTER-65W',   'DEMO-ADP-2606',    30.0000, NOW() - INTERVAL 90 DAY, '演示期初：电源适配器'),
        (112, 'INITIAL',     'DEMO-INIT-012', 'DEMO-WH-SZ', 'DEMO-SZ-B-01',    'DEMO-PRINTER-LBL',   'DEMO-PRN-2606',     6.0000, NOW() - INTERVAL 90 DAY, '演示期初：标签打印机'),
        (113, 'INITIAL',     'DEMO-INIT-013', 'DEMO-WH-SZ', 'DEMO-SZ-B-01',    'DEMO-MOUNT-BRACKET', 'DEMO-BRK-2607',    35.0000, NOW() - INTERVAL 90 DAY, '演示期初：安装支架'),
        (114, 'INITIAL',     'DEMO-INIT-014', 'DEMO-WH-SZ', 'DEMO-SZ-B-02',    'DEMO-PACK-CARTON',   'DEMO-BOX-2607',    90.0000, NOW() - INTERVAL 90 DAY, '演示期初：运输箱'),
        (115, 'INITIAL',     'DEMO-INIT-015', 'DEMO-WH-SZ', 'DEMO-SZ-B-02',    'DEMO-SEAL-LABEL',    'DEMO-SEAL-2607',  260.0000, NOW() - INTERVAL 90 DAY, '演示期初：防拆封签'),
        (201, 'RECEIPT',     'DEMO-IN-001',   'DEMO-WH-SH', 'DEMO-SH-A-01',    'DEMO-IOT-GW',        'DEMO-GW-2605',      8.0000, NOW() - INTERVAL 6 DAY, '采购入库完成'),
        (202, 'RECEIPT',     'DEMO-IN-001',   'DEMO-WH-SH', 'DEMO-SH-A-01',    'DEMO-SCAN-PDA',      'DEMO-PDA-2606',    12.0000, NOW() - INTERVAL 6 DAY, '采购入库完成'),
        (203, 'RECEIPT',     'DEMO-IN-001',   'DEMO-WH-SH', 'DEMO-SH-A-02',    'DEMO-TAG-RFID',      'DEMO-RFID-2607',  100.0000, NOW() - INTERVAL 6 DAY, '采购入库完成'),
        (211, 'RECEIPT',     'DEMO-IN-002',   'DEMO-WH-SH', 'DEMO-SH-RET-01',  'DEMO-SENSOR-DOOR',   'DEMO-DOOR-2607',   10.0000, NOW() - INTERVAL 3 DAY, '售后退货入库完成'),
        (212, 'RECEIPT',     'DEMO-IN-002',   'DEMO-WH-SH', 'DEMO-SH-RET-01',  'DEMO-LOCK-SMART',    'DEMO-LOCK-2607',    8.0000, NOW() - INTERVAL 3 DAY, '售后退货入库完成'),
        (221, 'RECEIPT',     'DEMO-IN-003',   'DEMO-WH-SZ', 'DEMO-SZ-B-01',    'DEMO-PRINTER-LBL',   'DEMO-PRN-2606',     5.0000, NOW(), '今日其他入库完成'),
        (222, 'RECEIPT',     'DEMO-IN-003',   'DEMO-WH-SZ', 'DEMO-SZ-B-02',    'DEMO-ADAPTER-65W',   'DEMO-ADP-2606',    20.0000, NOW(), '今日其他入库完成'),
        (223, 'RECEIPT',     'DEMO-IN-003',   'DEMO-WH-SZ', 'DEMO-SZ-B-02',    'DEMO-PACK-CARTON',   'DEMO-BOX-2607',    50.0000, NOW(), '今日其他入库完成'),
        (301, 'SHIPMENT',    'DEMO-OUT-001',  'DEMO-WH-SH', 'DEMO-SH-A-01',    'DEMO-IOT-GW',        'DEMO-GW-2605',     -4.0000, NOW() - INTERVAL 5 DAY, '销售出库完成'),
        (302, 'SHIPMENT',    'DEMO-OUT-001',  'DEMO-WH-SH', 'DEMO-SH-A-01',    'DEMO-SCAN-PDA',      'DEMO-PDA-2606',    -7.0000, NOW() - INTERVAL 5 DAY, '销售出库完成'),
        (303, 'SHIPMENT',    'DEMO-OUT-001',  'DEMO-WH-SH', 'DEMO-SH-A-02',    'DEMO-TAG-RFID',      'DEMO-RFID-2607',  -60.0000, NOW() - INTERVAL 5 DAY, '销售出库完成'),
        (311, 'SHIPMENT',    'DEMO-OUT-002',  'DEMO-WH-SH', 'DEMO-SH-A-02',    'DEMO-ADAPTER-65W',   'DEMO-ADP-2606',    -5.0000, NOW() - INTERVAL 2 DAY, '退供出库完成'),
        (312, 'SHIPMENT',    'DEMO-OUT-002',  'DEMO-WH-SH', 'DEMO-SH-FRZ-01',  'DEMO-BATTERY-LT',    'DEMO-BAT-2607',    -2.0000, NOW() - INTERVAL 2 DAY, '退供出库完成'),
        (321, 'SHIPMENT',    'DEMO-OUT-003',  'DEMO-WH-SZ', 'DEMO-SZ-B-01',    'DEMO-PRINTER-LBL',   'DEMO-PRN-2606',    -2.0000, NOW(), '今日内部领用出库完成'),
        (322, 'SHIPMENT',    'DEMO-OUT-003',  'DEMO-WH-SZ', 'DEMO-SZ-B-02',    'DEMO-PACK-CARTON',   'DEMO-BOX-2607',   -25.0000, NOW(), '今日内部领用出库完成'),
        (401, 'TRANSFER_OUT','DEMO-TR-001',   'DEMO-WH-SH', 'DEMO-SH-A-01',    'DEMO-IOT-GW',        'DEMO-GW-2605',     -3.0000, NOW() - INTERVAL 3 DAY, '上海向苏州调拨电商应急库存'),
        (402, 'TRANSFER_IN', 'DEMO-TR-001',   'DEMO-WH-SZ', 'DEMO-SZ-B-01',    'DEMO-IOT-GW',        'DEMO-GW-2605',      3.0000, NOW() - INTERVAL 3 DAY, '苏州接收电商应急库存'),
        (411, 'ADJUST_IN',   'DEMO-ADJ-001',  'DEMO-WH-SH', 'DEMO-SH-RET-01',  'DEMO-SENSOR-DOOR',   'DEMO-DOOR-2607',    2.0000, NOW() - INTERVAL 2 DAY, '循环盘点发现盘盈2个'),
        (421, 'ADJUST_OUT',  'DEMO-ADJ-002',  'DEMO-WH-SH', 'DEMO-SH-A-01',    'DEMO-CABLE-TYPEC',   'DEMO-CABLE-2607', -10.0000, NOW() - INTERVAL 1 DAY, '包装破损盘亏10根');

    INSERT INTO wms_stock_movement
        (biz_type, biz_no, warehouse_id, location_id, item_id, batch_no,
         change_qty, balance_qty, operator, operation_time, remark)
    SELECT p.biz_type, p.biz_no, w.warehouse_id, l.location_id, i.item_id, p.batch_no,
           p.change_qty,
           SUM(p.change_qty) OVER (
               PARTITION BY p.warehouse_code, p.location_code, p.item_code, p.batch_no
               ORDER BY p.movement_seq ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) AS balance_qty,
           'admin', p.operation_time, p.remark
      FROM demo_movement_plan p
      JOIN wms_warehouse w ON w.warehouse_code = p.warehouse_code
      JOIN wms_location l ON l.warehouse_id = w.warehouse_id AND l.location_code = p.location_code
      JOIN wms_item i ON i.item_code = p.item_code
     ORDER BY p.movement_seq;

    INSERT INTO wms_stock
        (warehouse_id, location_id, item_id, batch_no, production_date, expiry_date,
         quantity, locked_quantity, update_time)
    SELECT w.warehouse_id, l.location_id, i.item_id, p.batch_no,
           m.production_date, m.expiry_date, SUM(p.change_qty), m.locked_quantity, NOW()
      FROM demo_movement_plan p
      JOIN demo_stock_meta m
        ON m.warehouse_code = p.warehouse_code AND m.location_code = p.location_code
       AND m.item_code = p.item_code AND m.batch_no = p.batch_no
      JOIN wms_warehouse w ON w.warehouse_code = p.warehouse_code
      JOIN wms_location l ON l.warehouse_id = w.warehouse_id AND l.location_code = p.location_code
      JOIN wms_item i ON i.item_code = p.item_code
     GROUP BY w.warehouse_id, l.location_id, i.item_id, p.batch_no,
              m.production_date, m.expiry_date, m.locked_quantity;

    -- ========================= 提交前断言 =========================
    SELECT COUNT(*) INTO v_error_count
      FROM (
            SELECT p.warehouse_code, p.location_code, p.item_code, p.batch_no,
                   SUM(p.change_qty) OVER (
                       PARTITION BY p.warehouse_code, p.location_code, p.item_code, p.batch_no
                       ORDER BY p.movement_seq ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                   ) running_balance
              FROM demo_movement_plan p
      ) ledger
     WHERE ledger.running_balance < 0;
    IF v_error_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：流水出现负库存';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM wms_stock s
      JOIN wms_warehouse w ON w.warehouse_id = s.warehouse_id AND w.warehouse_code REGEXP '^DEMO-'
      JOIN wms_item i ON i.item_id = s.item_id AND i.item_code REGEXP '^DEMO-'
     WHERE s.quantity < 0 OR s.locked_quantity < 0 OR s.locked_quantity > s.quantity;
    IF v_error_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：库存为负或锁定数量超量';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM wms_stock s
      JOIN wms_warehouse w ON w.warehouse_id = s.warehouse_id
      JOIN wms_item i ON i.item_id = s.item_id
     WHERE w.warehouse_code REGEXP '^DEMO-WH-'
       AND i.item_code REGEXP '^DEMO-'
       AND s.batch_no REGEXP '^DEMO-'
       AND s.locked_quantity <> 0;
    IF v_error_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：初始演示库存不应存在锁定数量';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM demo_movement_plan p
      LEFT JOIN demo_stock_meta m
        ON m.warehouse_code = p.warehouse_code AND m.location_code = p.location_code
       AND m.item_code = p.item_code AND m.batch_no = p.batch_no
     WHERE m.item_code IS NULL;
    IF v_error_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：流水批次缺少库存元数据';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM wms_stock s
      JOIN wms_warehouse w ON w.warehouse_id = s.warehouse_id AND w.warehouse_code REGEXP '^DEMO-'
      JOIN wms_location l ON l.location_id = s.location_id
      JOIN wms_item i ON i.item_id = s.item_id AND i.item_code REGEXP '^DEMO-'
      LEFT JOIN (
            SELECT warehouse_code, location_code, item_code, batch_no, SUM(change_qty) expected_qty
              FROM demo_movement_plan
             GROUP BY warehouse_code, location_code, item_code, batch_no
      ) e ON e.warehouse_code = w.warehouse_code AND e.location_code = l.location_code
         AND e.item_code = i.item_code AND e.batch_no = s.batch_no
     WHERE s.batch_no REGEXP '^DEMO-'
       AND (e.item_code IS NULL OR s.quantity <> e.expected_qty);
    IF v_error_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：库存余额与流水汇总不一致';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM (
            SELECT m.movement_id, m.balance_qty,
                   SUM(m.change_qty) OVER (
                       PARTITION BY m.warehouse_id, m.location_id, m.item_id, m.batch_no
                       ORDER BY m.operation_time, m.movement_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                   ) expected_balance
              FROM wms_stock_movement m
              LEFT JOIN wms_warehouse w ON w.warehouse_id = m.warehouse_id
              LEFT JOIN wms_location l ON l.location_id = m.location_id
              LEFT JOIN wms_area a ON a.area_id = l.area_id
              LEFT JOIN wms_item i ON i.item_id = m.item_id
             WHERE m.biz_no REGEXP '^DEMO-'
                OR w.warehouse_code REGEXP '^DEMO-'
                OR a.area_code REGEXP '^DEMO-'
                OR l.location_code REGEXP '^DEMO-'
                OR i.item_code REGEXP '^DEMO-'
                OR m.batch_no REGEXP '^DEMO-'
      ) x
     WHERE x.balance_qty <> x.expected_balance;
    IF v_error_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：流水逐笔结存不一致';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM (
            SELECT r.receipt_no, rl.location_id, rl.item_id, rl.batch_no, rl.received_qty,
                   COALESCE(SUM(m.change_qty), 0) movement_qty
              FROM wms_receipt r
              JOIN wms_receipt_line rl ON rl.receipt_id = r.receipt_id
              LEFT JOIN wms_stock_movement m
                ON m.biz_type = 'RECEIPT' AND m.biz_no = r.receipt_no
               AND m.warehouse_id = r.warehouse_id AND m.location_id = rl.location_id
               AND m.item_id = rl.item_id AND m.batch_no = rl.batch_no
             WHERE r.receipt_no REGEXP '^DEMO-' AND r.status = 'COMPLETED'
             GROUP BY r.receipt_no, rl.location_id, rl.item_id, rl.batch_no, rl.received_qty
            HAVING movement_qty <> rl.received_qty
      ) x;
    IF v_error_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：完成入库单与流水不一致';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM (
            SELECT s.shipment_no, sl.location_id, sl.item_id, sl.batch_no, sl.shipped_qty,
                   COALESCE(SUM(m.change_qty), 0) movement_qty
              FROM wms_shipment s
              JOIN wms_shipment_line sl ON sl.shipment_id = s.shipment_id
              LEFT JOIN wms_stock_movement m
                ON m.biz_type = 'SHIPMENT' AND m.biz_no = s.shipment_no
               AND m.warehouse_id = s.warehouse_id AND m.location_id = sl.location_id
               AND m.item_id = sl.item_id AND m.batch_no = sl.batch_no
             WHERE s.shipment_no REGEXP '^DEMO-' AND s.status = 'COMPLETED'
             GROUP BY s.shipment_no, sl.location_id, sl.item_id, sl.batch_no, sl.shipped_qty
            HAVING movement_qty <> -sl.shipped_qty
      ) x;
    IF v_error_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：完成出库单与流水不一致';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM (
            SELECT r.receipt_no
              FROM wms_receipt r
              JOIN wms_receipt_line rl ON rl.receipt_id = r.receipt_id
             WHERE r.receipt_no REGEXP '^DEMO-'
             GROUP BY r.receipt_id, r.receipt_no, r.status, r.total_qty
            HAVING r.total_qty <> CASE WHEN r.status = 'COMPLETED' THEN SUM(rl.received_qty) ELSE SUM(rl.planned_qty) END
            UNION ALL
            SELECT s.shipment_no
              FROM wms_shipment s
              JOIN wms_shipment_line sl ON sl.shipment_id = s.shipment_id
             WHERE s.shipment_no REGEXP '^DEMO-'
             GROUP BY s.shipment_id, s.shipment_no, s.status, s.total_qty
            HAVING s.total_qty <> CASE WHEN s.status = 'COMPLETED' THEN SUM(sl.shipped_qty) ELSE SUM(sl.planned_qty) END
      ) x;
    IF v_error_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：单据头总数与明细不一致';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM (
            SELECT r.receipt_no biz_no
              FROM wms_receipt r JOIN wms_stock_movement m ON m.biz_no = r.receipt_no
             WHERE r.receipt_no REGEXP '^DEMO-' AND r.status IN ('DRAFT', 'CANCELLED')
            UNION ALL
            SELECT s.shipment_no
              FROM wms_shipment s JOIN wms_stock_movement m ON m.biz_no = s.shipment_no
             WHERE s.shipment_no REGEXP '^DEMO-' AND s.status IN ('DRAFT', 'CANCELLED')
      ) x;
    IF v_error_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：草稿或取消单据产生了库存流水';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM (
            SELECT l.location_id
              FROM wms_location l
              JOIN wms_area a ON a.area_id = l.area_id
             WHERE l.warehouse_id <> a.warehouse_id
               AND l.location_code REGEXP '^DEMO-'
            UNION ALL
            SELECT s.stock_id
              FROM wms_stock s JOIN wms_location l ON l.location_id = s.location_id
             WHERE s.warehouse_id <> l.warehouse_id AND s.batch_no REGEXP '^DEMO-'
            UNION ALL
            SELECT rl.line_id
              FROM wms_receipt_line rl
              JOIN wms_receipt r ON r.receipt_id = rl.receipt_id
              JOIN wms_location l ON l.location_id = rl.location_id
             WHERE r.receipt_no REGEXP '^DEMO-' AND r.warehouse_id <> l.warehouse_id
            UNION ALL
            SELECT sl.line_id
              FROM wms_shipment_line sl
              JOIN wms_shipment s ON s.shipment_id = sl.shipment_id
              JOIN wms_location l ON l.location_id = sl.location_id
             WHERE s.shipment_no REGEXP '^DEMO-' AND s.warehouse_id <> l.warehouse_id
            UNION ALL
            SELECT m.movement_id
              FROM wms_stock_movement m JOIN wms_location l ON l.location_id = m.location_id
             WHERE m.biz_no REGEXP '^DEMO-' AND m.warehouse_id <> l.warehouse_id
      ) orphan_or_mismatch;
    IF v_error_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：存在孤儿或跨仓引用';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM wms_stock s
      JOIN wms_location l ON l.location_id = s.location_id
      JOIN wms_area a ON a.area_id = l.area_id
      JOIN wms_warehouse w ON w.warehouse_id = s.warehouse_id
      JOIN wms_item i ON i.item_id = s.item_id
     WHERE w.warehouse_code REGEXP '^DEMO-' AND i.item_code REGEXP '^DEMO-' AND s.batch_no REGEXP '^DEMO-'
       AND (w.status <> '0' OR a.status <> '0' OR l.status <> '0' OR l.location_type = 'DEFECTIVE');
    IF v_error_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：停用或不良品库位承载了库存';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM wms_location l
      JOIN wms_warehouse w ON w.warehouse_id = l.warehouse_id
      JOIN wms_stock s ON s.location_id = l.location_id
     WHERE w.warehouse_code REGEXP '^DEMO-WH-'
       AND l.location_code REGEXP '^DEMO-'
       AND l.location_type = 'DEFECTIVE';
    IF v_error_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：不良品隔离位必须保持空库存';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM (
            SELECT a.area_id
              FROM wms_area a
              JOIN wms_warehouse w ON w.warehouse_id = a.warehouse_id
              LEFT JOIN wms_location l ON l.area_id = a.area_id AND l.status = '0'
             WHERE w.warehouse_code IN ('DEMO-WH-SH', 'DEMO-WH-SZ')
               AND w.status = '0' AND a.status = '0'
             GROUP BY a.area_id
            HAVING COUNT(l.location_id) = 0
      ) empty_operation_area;
    IF v_error_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：启用作业库区缺少启用库位';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM wms_stock s
      JOIN wms_location l ON l.location_id = s.location_id
      JOIN wms_area a ON a.area_id = l.area_id
      JOIN wms_warehouse w ON w.warehouse_id = s.warehouse_id
     WHERE w.warehouse_code IN ('DEMO-WH-SH', 'DEMO-WH-SZ')
       AND a.area_type IN ('RECEIVING', 'SHIPPING');
    IF v_error_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：收货或发运作业区不应承载结存库存';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM wms_receipt r
      JOIN wms_receipt_line rl ON rl.receipt_id = r.receipt_id
      JOIN wms_location l ON l.location_id = rl.location_id
      JOIN wms_area a ON a.area_id = l.area_id
     WHERE r.receipt_no = 'DEMO-IN-002'
       AND (r.receipt_type <> 'RETURN' OR l.location_code <> 'DEMO-SH-RET-01'
            OR l.location_type <> 'NORMAL' OR a.area_type <> 'RETURN');
    IF v_error_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：退货入库单未落在正常RETURN库位';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM wms_receipt r JOIN wms_receipt_line rl ON rl.receipt_id = r.receipt_id
     WHERE r.receipt_no = 'DEMO-IN-002';
    IF v_error_count <> 2 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：退货入库单应包含2条明细';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM (
            SELECT m.movement_id invalid_id
              FROM wms_stock_movement m
              JOIN wms_item i ON i.item_id = m.item_id
              JOIN wms_location l ON l.location_id = m.location_id
              JOIN wms_area a ON a.area_id = l.area_id
             WHERE ((i.item_code = 'DEMO-SENSOR-DOOR' AND m.batch_no = 'DEMO-DOOR-2607')
                 OR (i.item_code = 'DEMO-LOCK-SMART' AND m.batch_no = 'DEMO-LOCK-2607'))
               AND (l.location_code <> 'DEMO-SH-RET-01' OR l.location_type <> 'NORMAL' OR a.area_type <> 'RETURN')
            UNION ALL
            SELECT s.stock_id
              FROM wms_stock s
              JOIN wms_item i ON i.item_id = s.item_id
              JOIN wms_location l ON l.location_id = s.location_id
              JOIN wms_area a ON a.area_id = l.area_id
             WHERE ((i.item_code = 'DEMO-SENSOR-DOOR' AND s.batch_no = 'DEMO-DOOR-2607')
                 OR (i.item_code = 'DEMO-LOCK-SMART' AND s.batch_no = 'DEMO-LOCK-2607'))
               AND (l.location_code <> 'DEMO-SH-RET-01' OR l.location_type <> 'NORMAL' OR a.area_type <> 'RETURN')
      ) return_chain_mismatch;
    IF v_error_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：退货批次的流水或库存未完整迁移到RETURN库位';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM (
            SELECT l.location_id, l.capacity_qty, COALESCE(SUM(s.quantity), 0) stock_qty
              FROM wms_location l
              JOIN wms_warehouse w ON w.warehouse_id = l.warehouse_id
              LEFT JOIN wms_stock s ON s.warehouse_id = l.warehouse_id AND s.location_id = l.location_id
             WHERE w.warehouse_code REGEXP '^DEMO-WH-' AND l.location_code REGEXP '^DEMO-'
             GROUP BY l.location_id, l.capacity_qty
            HAVING l.capacity_qty > 0 AND stock_qty > l.capacity_qty
      ) over_capacity;
    IF v_error_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：库位库存超过容量';
    END IF;

    SELECT COUNT(*), SUM(status = '0'), SUM(status = '1')
      INTO v_error_count, @demo_enabled_warehouses, @demo_disabled_warehouses
      FROM wms_warehouse WHERE warehouse_code REGEXP '^DEMO-WH-';
    IF v_error_count <> 3 OR @demo_enabled_warehouses <> 2 OR @demo_disabled_warehouses <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：演示仓库必须为三仓、两启用一停用';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM (
            SELECT a.area_type
              FROM wms_area a JOIN wms_warehouse w ON w.warehouse_id = a.warehouse_id
             WHERE w.warehouse_code REGEXP '^DEMO-WH-'
             GROUP BY a.area_type
      ) x;
    IF v_error_count <> 5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：未完整覆盖五类库区';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM wms_area a JOIN wms_warehouse w ON w.warehouse_id = a.warehouse_id
     WHERE w.warehouse_code IN ('DEMO-WH-SH', 'DEMO-WH-SZ', 'DEMO-WH-BJ');
    IF v_error_count <> 9 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：演示库区必须为9个';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM wms_location l JOIN wms_warehouse w ON w.warehouse_id = l.warehouse_id
     WHERE w.warehouse_code IN ('DEMO-WH-SH', 'DEMO-WH-SZ', 'DEMO-WH-BJ');
    IF v_error_count <> 14 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：演示库位必须为14个';
    END IF;

    SELECT COUNT(DISTINCT l.location_type) INTO v_error_count
      FROM wms_location l JOIN wms_warehouse w ON w.warehouse_id = l.warehouse_id
     WHERE w.warehouse_code REGEXP '^DEMO-WH-'
       AND l.location_code REGEXP '^DEMO-'
       AND l.location_type IN ('NORMAL', 'FROZEN', 'DEFECTIVE');
    IF v_error_count <> 3 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：未完整覆盖普通、冷冻和不良品库位';
    END IF;

    SELECT COUNT(*) INTO v_error_count FROM wms_item WHERE item_code REGEXP '^DEMO-';
    IF v_error_count <> 14 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：演示物料必须为14个';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM wms_stock s
      JOIN wms_warehouse w ON w.warehouse_id = s.warehouse_id
      JOIN wms_item i ON i.item_id = s.item_id
     WHERE w.warehouse_code REGEXP '^DEMO-' AND i.item_code REGEXP '^DEMO-' AND s.batch_no REGEXP '^DEMO-';
    IF v_error_count <> 17 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：演示库存维度必须为17个';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM (
            SELECT item_id FROM wms_stock
             WHERE batch_no REGEXP '^DEMO-'
             GROUP BY item_id HAVING COUNT(DISTINCT batch_no) >= 2
      ) x;
    IF v_error_count < 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：缺少多批次库存';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM wms_stock s
      JOIN wms_warehouse w ON w.warehouse_id = s.warehouse_id
     WHERE w.warehouse_code REGEXP '^DEMO-'
       AND (s.expiry_date < CURDATE() OR s.expiry_date BETWEEN CURDATE() AND CURDATE() + INTERVAL 30 DAY);
    IF v_error_count < 2 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：缺少临期或过期库存';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM (
            SELECT i.item_id
              FROM wms_item i
              LEFT JOIN wms_stock s ON s.item_id = i.item_id
             WHERE i.item_code REGEXP '^DEMO-' AND i.status = '0' AND i.min_stock > 0
             GROUP BY i.item_id, i.min_stock
            HAVING COALESCE(SUM(s.quantity - s.locked_quantity), 0) < i.min_stock
      ) x;
    IF v_error_count < 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：缺少低库存预警样本';
    END IF;

    SELECT COUNT(*), COUNT(DISTINCT receipt_type), COUNT(DISTINCT status)
      INTO @demo_receipt_count, @demo_receipt_types, @demo_receipt_statuses
      FROM wms_receipt WHERE receipt_no REGEXP '^DEMO-';
    IF @demo_receipt_count <> 5 OR @demo_receipt_types <> 3 OR @demo_receipt_statuses <> 3 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：入库单数量、类型或状态覆盖不足';
    END IF;

    SELECT COUNT(*), COUNT(DISTINCT shipment_type), COUNT(DISTINCT status)
      INTO @demo_shipment_count, @demo_shipment_types, @demo_shipment_statuses
      FROM wms_shipment WHERE shipment_no REGEXP '^DEMO-';
    IF @demo_shipment_count <> 5 OR @demo_shipment_types <> 3 OR @demo_shipment_statuses <> 3 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：出库单数量、类型或状态覆盖不足';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM wms_receipt
     WHERE receipt_no REGEXP '^DEMO-' AND status = 'COMPLETED'
       AND receipt_date >= CURDATE() AND receipt_date < CURDATE() + INTERVAL 1 DAY;
    IF v_error_count < 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：缺少今日完成入库';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM wms_shipment
     WHERE shipment_no REGEXP '^DEMO-' AND status = 'COMPLETED'
       AND shipment_date >= CURDATE() AND shipment_date < CURDATE() + INTERVAL 1 DAY;
    IF v_error_count < 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：缺少今日完成出库';
    END IF;

    SELECT COUNT(DISTINCT business_date) INTO v_error_count
      FROM (
            SELECT DATE(receipt_date) business_date
              FROM wms_receipt
             WHERE receipt_no REGEXP '^DEMO-' AND status = 'COMPLETED'
               AND receipt_date >= CURDATE() - INTERVAL 6 DAY
               AND receipt_date < CURDATE() + INTERVAL 1 DAY
            UNION ALL
            SELECT DATE(shipment_date)
              FROM wms_shipment
             WHERE shipment_no REGEXP '^DEMO-' AND status = 'COMPLETED'
               AND shipment_date >= CURDATE() - INTERVAL 6 DAY
               AND shipment_date < CURDATE() + INTERVAL 1 DAY
      ) trend_dates;
    IF v_error_count < 5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：近7日出入库趋势节点少于5天';
    END IF;

    SELECT COUNT(DISTINCT biz_type) INTO v_error_count
      FROM wms_stock_movement
     WHERE biz_no REGEXP '^DEMO-'
       AND biz_type IN ('TRANSFER_IN', 'TRANSFER_OUT', 'ADJUST_IN', 'ADJUST_OUT');
    IF v_error_count <> 4 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：调拨或盘点流水类型不完整';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM wms_stock_movement
     WHERE biz_no REGEXP '^DEMO-';
    IF v_error_count <> 34 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：演示流水必须为34条';
    END IF;

    SELECT COUNT(*) INTO v_error_count
      FROM (
            SELECT 'area' ref_type FROM wms_area a JOIN wms_warehouse w ON w.warehouse_id = a.warehouse_id WHERE w.warehouse_code = 'DEMO-WH-BJ'
            UNION ALL SELECT 'receipt' FROM wms_receipt r JOIN wms_warehouse w ON w.warehouse_id = r.warehouse_id WHERE w.warehouse_code = 'DEMO-WH-BJ'
            UNION ALL SELECT 'shipment' FROM wms_shipment s JOIN wms_warehouse w ON w.warehouse_id = s.warehouse_id WHERE w.warehouse_code = 'DEMO-WH-BJ'
            UNION ALL SELECT 'stock' FROM wms_stock s JOIN wms_warehouse w ON w.warehouse_id = s.warehouse_id WHERE w.warehouse_code = 'DEMO-WH-BJ'
            UNION ALL SELECT 'movement' FROM wms_stock_movement m JOIN wms_warehouse w ON w.warehouse_id = m.warehouse_id WHERE w.warehouse_code = 'DEMO-WH-BJ'
      ) x;
    IF v_error_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '演示数据断言失败：停用的北京备件仓被业务引用';
    END IF;

    COMMIT;

    SELECT 'wms_demo_seed_ok' AS result,
           (SELECT COUNT(*) FROM wms_warehouse WHERE warehouse_code REGEXP '^DEMO-WH-') AS warehouses,
           (SELECT COUNT(*) FROM wms_location WHERE location_code REGEXP '^DEMO-') AS locations,
           (SELECT COUNT(*) FROM wms_item WHERE item_code REGEXP '^DEMO-') AS items,
           (SELECT COUNT(*) FROM wms_stock WHERE batch_no REGEXP '^DEMO-') AS stock_dimensions,
           (SELECT COUNT(*) FROM wms_receipt WHERE receipt_no REGEXP '^DEMO-') AS receipts,
           (SELECT COUNT(*) FROM wms_shipment WHERE shipment_no REGEXP '^DEMO-') AS shipments,
           (SELECT COUNT(*) FROM wms_stock_movement WHERE biz_no REGEXP '^DEMO-') AS movements;
END$$

CALL seed_yian_wms_demo()$$
DROP PROCEDURE IF EXISTS seed_yian_wms_demo$$

DELIMITER ;

DO RELEASE_LOCK('yian_wms_demo_seed_v1');
DROP TEMPORARY TABLE yian_wms_demo_seed_lock_guard;
