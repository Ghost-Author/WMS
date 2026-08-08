-- 智仓 WMS 初始化脚本
-- 适用：MySQL 8.x / utf8mb4
-- 执行顺序：ry_20260320.sql -> quartz.sql -> wms.sql
-- 注意：重复执行会重建全部 wms_* 业务表，仅用于全新或可丢弃的开发环境。

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET @WMS_OLD_FOREIGN_KEY_CHECKS = @@FOREIGN_KEY_CHECKS;
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS wms_stock_movement;
DROP TABLE IF EXISTS wms_stock;
DROP TABLE IF EXISTS wms_shipment_line;
DROP TABLE IF EXISTS wms_shipment;
DROP TABLE IF EXISTS wms_receipt_line;
DROP TABLE IF EXISTS wms_receipt;
DROP TABLE IF EXISTS wms_location;
DROP TABLE IF EXISTS wms_area;
DROP TABLE IF EXISTS wms_item;
DROP TABLE IF EXISTS wms_warehouse;

CREATE TABLE wms_warehouse (
  warehouse_id    BIGINT       NOT NULL AUTO_INCREMENT COMMENT '仓库ID',
  warehouse_code  VARCHAR(32)  NOT NULL COMMENT '仓库编码',
  warehouse_name  VARCHAR(100) NOT NULL COMMENT '仓库名称',
  address         VARCHAR(255)          COMMENT '仓库地址',
  manager         VARCHAR(50)           COMMENT '负责人',
  phone           VARCHAR(20)           COMMENT '联系电话',
  status          CHAR(1)      NOT NULL DEFAULT '0' COMMENT '状态（0启用 1停用）',
  create_by       VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '创建者',
  create_time     DATETIME              DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  update_by       VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '更新者',
  update_time     DATETIME              DEFAULT NULL COMMENT '更新时间',
  remark          VARCHAR(500)          DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (warehouse_id),
  UNIQUE KEY uk_wms_warehouse_code (warehouse_code),
  KEY idx_wms_warehouse_name (warehouse_name),
  KEY idx_wms_warehouse_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='WMS仓库';

CREATE TABLE wms_area (
  area_id         BIGINT       NOT NULL AUTO_INCREMENT COMMENT '库区ID',
  warehouse_id    BIGINT       NOT NULL COMMENT '仓库ID',
  area_code       VARCHAR(32)  NOT NULL COMMENT '库区编码',
  area_name       VARCHAR(100) NOT NULL COMMENT '库区名称',
  area_type       VARCHAR(20)  NOT NULL COMMENT '库区类型',
  status          CHAR(1)      NOT NULL DEFAULT '0' COMMENT '状态（0启用 1停用）',
  create_by       VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '创建者',
  create_time     DATETIME              DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  update_by       VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '更新者',
  update_time     DATETIME              DEFAULT NULL COMMENT '更新时间',
  remark          VARCHAR(500)          DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (area_id),
  UNIQUE KEY uk_wms_area_warehouse_code (warehouse_id, area_code),
  KEY idx_wms_area_warehouse_status (warehouse_id, status),
  KEY idx_wms_area_name (area_name),
  CONSTRAINT fk_wms_area_warehouse FOREIGN KEY (warehouse_id)
    REFERENCES wms_warehouse (warehouse_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='WMS库区';

CREATE TABLE wms_location (
  location_id     BIGINT        NOT NULL AUTO_INCREMENT COMMENT '库位ID',
  warehouse_id    BIGINT        NOT NULL COMMENT '仓库ID',
  area_id         BIGINT        NOT NULL COMMENT '库区ID',
  location_code   VARCHAR(32)   NOT NULL COMMENT '库位编码',
  location_name   VARCHAR(100)  NOT NULL COMMENT '库位名称',
  location_type   VARCHAR(20)   NOT NULL COMMENT '库位类型',
  capacity_qty    DECIMAL(18,4) NOT NULL DEFAULT 0.0000 COMMENT '容量',
  status          CHAR(1)       NOT NULL DEFAULT '0' COMMENT '状态（0启用 1停用）',
  create_by       VARCHAR(64)   NOT NULL DEFAULT '' COMMENT '创建者',
  create_time     DATETIME               DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  update_by       VARCHAR(64)   NOT NULL DEFAULT '' COMMENT '更新者',
  update_time     DATETIME               DEFAULT NULL COMMENT '更新时间',
  remark          VARCHAR(500)           DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (location_id),
  UNIQUE KEY uk_wms_location_warehouse_code (warehouse_id, location_code),
  KEY idx_wms_location_area_status (area_id, status),
  KEY idx_wms_location_name (location_name),
  CONSTRAINT fk_wms_location_warehouse FOREIGN KEY (warehouse_id)
    REFERENCES wms_warehouse (warehouse_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_wms_location_area FOREIGN KEY (area_id)
    REFERENCES wms_area (area_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='WMS库位';

CREATE TABLE wms_item (
  item_id         BIGINT        NOT NULL AUTO_INCREMENT COMMENT '物料ID',
  item_code       VARCHAR(32)   NOT NULL COMMENT '物料编码',
  item_name       VARCHAR(100)  NOT NULL COMMENT '物料名称',
  category        VARCHAR(50)            DEFAULT NULL COMMENT '物料分类',
  specification   VARCHAR(100)           DEFAULT NULL COMMENT '规格型号',
  unit            VARCHAR(20)   NOT NULL COMMENT '计量单位',
  barcode         VARCHAR(64)            DEFAULT NULL COMMENT '条码',
  min_stock       DECIMAL(18,4) NOT NULL DEFAULT 0.0000 COMMENT '最低库存',
  max_stock       DECIMAL(18,4)          DEFAULT NULL COMMENT '最高库存',
  status          CHAR(1)       NOT NULL DEFAULT '0' COMMENT '状态（0启用 1停用）',
  create_by       VARCHAR(64)   NOT NULL DEFAULT '' COMMENT '创建者',
  create_time     DATETIME               DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  update_by       VARCHAR(64)   NOT NULL DEFAULT '' COMMENT '更新者',
  update_time     DATETIME               DEFAULT NULL COMMENT '更新时间',
  remark          VARCHAR(500)           DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (item_id),
  UNIQUE KEY uk_wms_item_code (item_code),
  UNIQUE KEY uk_wms_item_barcode (barcode),
  KEY idx_wms_item_name (item_name),
  KEY idx_wms_item_category_status (category, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='WMS物料';

CREATE TABLE wms_receipt (
  receipt_id      BIGINT        NOT NULL AUTO_INCREMENT COMMENT '入库单ID',
  receipt_no      VARCHAR(32)   NOT NULL COMMENT '入库单号',
  receipt_type    VARCHAR(20)   NOT NULL COMMENT '入库类型',
  warehouse_id    BIGINT        NOT NULL COMMENT '仓库ID',
  supplier_name   VARCHAR(100)           DEFAULT NULL COMMENT '供应商名称',
  receipt_date    DATETIME      NOT NULL COMMENT '入库日期',
  status          VARCHAR(20)   NOT NULL DEFAULT 'DRAFT' COMMENT '状态（DRAFT/COMPLETED/CANCELLED）',
  total_qty       DECIMAL(18,4) NOT NULL DEFAULT 0.0000 COMMENT '总数量',
  create_by       VARCHAR(64)   NOT NULL DEFAULT '' COMMENT '创建者',
  create_time     DATETIME               DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  update_by       VARCHAR(64)   NOT NULL DEFAULT '' COMMENT '更新者',
  update_time     DATETIME               DEFAULT NULL COMMENT '更新时间',
  remark          VARCHAR(500)           DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (receipt_id),
  UNIQUE KEY uk_wms_receipt_no (receipt_no),
  KEY idx_wms_receipt_warehouse_status (warehouse_id, status),
  KEY idx_wms_receipt_date (receipt_date),
  CONSTRAINT fk_wms_receipt_warehouse FOREIGN KEY (warehouse_id)
    REFERENCES wms_warehouse (warehouse_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='WMS入库单';

CREATE TABLE wms_receipt_line (
  line_id          BIGINT        NOT NULL AUTO_INCREMENT COMMENT '入库单明细ID',
  receipt_id       BIGINT        NOT NULL COMMENT '入库单ID',
  item_id          BIGINT        NOT NULL COMMENT '物料ID',
  location_id      BIGINT        NOT NULL COMMENT '目标库位ID',
  batch_no         VARCHAR(64)   NOT NULL DEFAULT '' COMMENT '批次号',
  production_date  DATE                   DEFAULT NULL COMMENT '生产日期',
  expiry_date      DATE                   DEFAULT NULL COMMENT '失效日期',
  planned_qty      DECIMAL(18,4) NOT NULL DEFAULT 0.0000 COMMENT '计划数量',
  received_qty     DECIMAL(18,4) NOT NULL DEFAULT 0.0000 COMMENT '实收数量',
  PRIMARY KEY (line_id),
  KEY idx_wms_receipt_line_receipt (receipt_id),
  KEY idx_wms_receipt_line_item (item_id),
  KEY idx_wms_receipt_line_location (location_id),
  CONSTRAINT fk_wms_receipt_line_receipt FOREIGN KEY (receipt_id)
    REFERENCES wms_receipt (receipt_id) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_wms_receipt_line_item FOREIGN KEY (item_id)
    REFERENCES wms_item (item_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_wms_receipt_line_location FOREIGN KEY (location_id)
    REFERENCES wms_location (location_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='WMS入库单明细';

CREATE TABLE wms_shipment (
  shipment_id     BIGINT        NOT NULL AUTO_INCREMENT COMMENT '出库单ID',
  shipment_no     VARCHAR(32)   NOT NULL COMMENT '出库单号',
  shipment_type   VARCHAR(20)   NOT NULL COMMENT '出库类型',
  warehouse_id    BIGINT        NOT NULL COMMENT '仓库ID',
  customer_name   VARCHAR(100)           DEFAULT NULL COMMENT '客户名称',
  shipment_date   DATETIME      NOT NULL COMMENT '出库日期',
  status          VARCHAR(20)   NOT NULL DEFAULT 'DRAFT' COMMENT '状态（DRAFT/COMPLETED/CANCELLED）',
  total_qty       DECIMAL(18,4) NOT NULL DEFAULT 0.0000 COMMENT '总数量',
  create_by       VARCHAR(64)   NOT NULL DEFAULT '' COMMENT '创建者',
  create_time     DATETIME               DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  update_by       VARCHAR(64)   NOT NULL DEFAULT '' COMMENT '更新者',
  update_time     DATETIME               DEFAULT NULL COMMENT '更新时间',
  remark          VARCHAR(500)           DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (shipment_id),
  UNIQUE KEY uk_wms_shipment_no (shipment_no),
  KEY idx_wms_shipment_warehouse_status (warehouse_id, status),
  KEY idx_wms_shipment_date (shipment_date),
  CONSTRAINT fk_wms_shipment_warehouse FOREIGN KEY (warehouse_id)
    REFERENCES wms_warehouse (warehouse_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='WMS出库单';

CREATE TABLE wms_shipment_line (
  line_id          BIGINT        NOT NULL AUTO_INCREMENT COMMENT '出库单明细ID',
  shipment_id      BIGINT        NOT NULL COMMENT '出库单ID',
  item_id          BIGINT        NOT NULL COMMENT '物料ID',
  location_id      BIGINT        NOT NULL COMMENT '来源库位ID',
  batch_no         VARCHAR(64)   NOT NULL DEFAULT '' COMMENT '批次号',
  production_date  DATE                   DEFAULT NULL COMMENT '生产日期',
  expiry_date      DATE                   DEFAULT NULL COMMENT '失效日期',
  planned_qty      DECIMAL(18,4) NOT NULL DEFAULT 0.0000 COMMENT '计划数量',
  shipped_qty      DECIMAL(18,4) NOT NULL DEFAULT 0.0000 COMMENT '实发数量',
  PRIMARY KEY (line_id),
  KEY idx_wms_shipment_line_shipment (shipment_id),
  KEY idx_wms_shipment_line_item (item_id),
  KEY idx_wms_shipment_line_location (location_id),
  CONSTRAINT fk_wms_shipment_line_shipment FOREIGN KEY (shipment_id)
    REFERENCES wms_shipment (shipment_id) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_wms_shipment_line_item FOREIGN KEY (item_id)
    REFERENCES wms_item (item_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_wms_shipment_line_location FOREIGN KEY (location_id)
    REFERENCES wms_location (location_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='WMS出库单明细';

CREATE TABLE wms_stock (
  stock_id          BIGINT        NOT NULL AUTO_INCREMENT COMMENT '库存ID',
  warehouse_id      BIGINT        NOT NULL COMMENT '仓库ID',
  location_id       BIGINT        NOT NULL COMMENT '库位ID',
  item_id           BIGINT        NOT NULL COMMENT '物料ID',
  batch_no          VARCHAR(64)   NOT NULL DEFAULT '' COMMENT '批次号',
  production_date   DATE                   DEFAULT NULL COMMENT '生产日期',
  expiry_date       DATE                   DEFAULT NULL COMMENT '失效日期',
  quantity          DECIMAL(18,4) NOT NULL DEFAULT 0.0000 COMMENT '库存数量',
  locked_quantity   DECIMAL(18,4) NOT NULL DEFAULT 0.0000 COMMENT '锁定数量',
  update_time       DATETIME               DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (stock_id),
  UNIQUE KEY uk_wms_stock_dimension (warehouse_id, location_id, item_id, batch_no),
  KEY idx_wms_stock_item (item_id),
  KEY idx_wms_stock_location (location_id),
  KEY idx_wms_stock_expiry_date (expiry_date),
  CONSTRAINT fk_wms_stock_warehouse FOREIGN KEY (warehouse_id)
    REFERENCES wms_warehouse (warehouse_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_wms_stock_location FOREIGN KEY (location_id)
    REFERENCES wms_location (location_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_wms_stock_item FOREIGN KEY (item_id)
    REFERENCES wms_item (item_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='WMS库存';

CREATE TABLE wms_stock_movement (
  movement_id     BIGINT        NOT NULL AUTO_INCREMENT COMMENT '库存流水ID',
  biz_type        VARCHAR(20)   NOT NULL COMMENT '业务类型',
  biz_no          VARCHAR(32)   NOT NULL COMMENT '业务单号',
  warehouse_id    BIGINT        NOT NULL COMMENT '仓库ID',
  location_id     BIGINT        NOT NULL COMMENT '库位ID',
  item_id         BIGINT        NOT NULL COMMENT '物料ID',
  batch_no        VARCHAR(64)   NOT NULL DEFAULT '' COMMENT '批次号',
  change_qty      DECIMAL(18,4) NOT NULL COMMENT '变动数量（入库为正，出库为负）',
  balance_qty     DECIMAL(18,4) NOT NULL COMMENT '变动后结存数量',
  operator        VARCHAR(64)   NOT NULL DEFAULT '' COMMENT '操作人',
  operation_time  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '操作时间',
  remark          VARCHAR(500)           DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (movement_id),
  KEY idx_wms_movement_biz (biz_type, biz_no),
  KEY idx_wms_movement_stock_time (warehouse_id, location_id, item_id, batch_no, operation_time),
  KEY idx_wms_movement_operation_time (operation_time),
  CONSTRAINT fk_wms_movement_warehouse FOREIGN KEY (warehouse_id)
    REFERENCES wms_warehouse (warehouse_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_wms_movement_location FOREIGN KEY (location_id)
    REFERENCES wms_location (location_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_wms_movement_item FOREIGN KEY (item_id)
    REFERENCES wms_item (item_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='WMS库存流水';

SET FOREIGN_KEY_CHECKS = @WMS_OLD_FOREIGN_KEY_CHECKS;

-- 演示基础数据：1 个仓库、3 个库区、4 个库位、3 个物料。
INSERT INTO wms_warehouse
  (warehouse_id, warehouse_code, warehouse_name, address, manager, phone, status, create_by, create_time, remark)
VALUES
  (1, 'WH-SH-01', '上海中心仓', '上海市浦东新区示范路 88 号', '仓库管理员', '13800000000', '0', 'admin', NOW(), 'WMS 演示仓库');

INSERT INTO wms_area
  (area_id, warehouse_id, area_code, area_name, area_type, status, create_by, create_time, remark)
VALUES
  (1, 1, 'RCV-01', '收货暂存区', 'RECEIVING', '0', 'admin', NOW(), '待验收入库'),
  (2, 1, 'STO-01', '常温存储区', 'STORAGE',   '0', 'admin', NOW(), '常规物料存储'),
  (3, 1, 'SHP-01', '发货暂存区', 'SHIPPING',  '0', 'admin', NOW(), '待装车出库');

INSERT INTO wms_location
  (location_id, warehouse_id, area_id, location_code, location_name, location_type, capacity_qty, status, create_by, create_time)
VALUES
  (1, 1, 1, 'RCV-01-01', '收货暂存位 01', 'NORMAL', 1000.0000, '0', 'admin', NOW()),
  (2, 1, 2, 'A-01-01',   'A 区 01 排 01 位', 'NORMAL',  500.0000, '0', 'admin', NOW()),
  (3, 1, 2, 'A-01-02',   'A 区 01 排 02 位', 'NORMAL',  500.0000, '0', 'admin', NOW()),
  (4, 1, 3, 'SHP-01-01', '发货暂存位 01', 'NORMAL', 1000.0000, '0', 'admin', NOW());

INSERT INTO wms_item
  (item_id, item_code, item_name, category, specification, unit, barcode, min_stock, max_stock, status, create_by, create_time)
VALUES
  (1, 'MAT-0001', '瓦楞纸箱', '包材', '600×400×350mm', '个', '6900000000011', 20.0000, 500.0000, '0', 'admin', NOW()),
  (2, 'MAT-0002', '封箱胶带', '包材', '60mm×100m',     '卷', '6900000000028', 10.0000, 200.0000, '0', 'admin', NOW()),
  (3, 'PRD-0001', '智能扫码枪', '成品', 'WMS-S100',       '台', '6900000000035',  5.0000, 100.0000, '0', 'admin', NOW());

-- 库存与 INITIAL 流水一一对应，便于开箱演示库存查询。
INSERT INTO wms_stock
  (stock_id, warehouse_id, location_id, item_id, batch_no, production_date, expiry_date, quantity, locked_quantity, update_time)
VALUES
  (1, 1, 2, 1, 'BATCH-20260801', '2026-08-01', NULL,         120.0000, 0.0000, NOW()),
  (2, 1, 3, 2, 'BATCH-20260715', '2026-07-15', '2028-07-14', 48.5000, 0.0000, NOW());

INSERT INTO wms_stock_movement
  (movement_id, biz_type, biz_no, warehouse_id, location_id, item_id, batch_no, change_qty, balance_qty, operator, operation_time, remark)
VALUES
  (1, 'INITIAL', 'INIT-20260806-001', 1, 2, 1, 'BATCH-20260801', 120.0000, 120.0000, 'admin', NOW(), '演示期初库存'),
  (2, 'INITIAL', 'INIT-20260806-002', 1, 3, 2, 'BATCH-20260715',  48.5000,  48.5000, 'admin', NOW(), '演示期初库存');

-- RuoYi 动态菜单。2000-2199 为本项目保留号段，重跑脚本时刷新该号段。
DELETE FROM sys_role_menu WHERE menu_id BETWEEN 2000 AND 2199;
DELETE FROM sys_menu WHERE menu_id BETWEEN 2000 AND 2199;

INSERT INTO sys_menu
  (menu_id, menu_name, parent_id, order_num, path, component, query, route_name,
   is_frame, is_cache, menu_type, visible, status, perms, icon,
   create_by, create_time, update_by, update_time, remark)
VALUES
  (2000, '仓储管理', 0,    1, 'wms',       NULL,                    '', '', 1, 0, 'M', '0', '0', '',                    'nested',      'admin', NOW(), '', NULL, 'WMS仓储管理目录'),
  (2001, 'WMS看板',  2000, 1, 'dashboard', 'wms/dashboard/index',   '', 'WmsDashboard', 1, 0, 'C', '0', '0', 'wms:dashboard:list',  'dashboard',   'admin', NOW(), '', NULL, 'WMS运营看板'),
  (2002, '仓库',     2000, 2, 'warehouse', 'wms/warehouse/index',   '', 'WmsWarehouse', 1, 0, 'C', '0', '0', 'wms:warehouse:list',  'table',       'admin', NOW(), '', NULL, '仓库管理菜单'),
  (2003, '库区',     2000, 3, 'area',      'wms/area/index',        '', 'WmsArea', 1, 0, 'C', '0', '0', 'wms:area:list',       'component',   'admin', NOW(), '', NULL, '库区管理菜单'),
  (2004, '库位',     2000, 4, 'location',  'wms/location/index',    '', 'WmsLocation', 1, 0, 'C', '0', '0', 'wms:location:list',   'row',         'admin', NOW(), '', NULL, '库位管理菜单'),
  (2005, '物料',     2000, 5, 'item',      'wms/item/index',        '', 'WmsItem', 1, 0, 'C', '0', '0', 'wms:item:list',       'shopping',    'admin', NOW(), '', NULL, '物料管理菜单'),
  (2006, '库存',     2000, 6, 'stock',     'wms/stock/index',       '', 'WmsStock', 1, 0, 'C', '0', '0', 'wms:stock:list',      'chart',       'admin', NOW(), '', NULL, '实时库存菜单'),
  (2007, '入库单',   2000, 7, 'receipt',   'wms/receipt/index',     '', 'WmsReceipt', 1, 0, 'C', '0', '0', 'wms:receipt:list',    'download',    'admin', NOW(), '', NULL, '入库单管理菜单'),
  (2008, '出库单',   2000, 8, 'shipment',  'wms/shipment/index',    '', 'WmsShipment', 1, 0, 'C', '0', '0', 'wms:shipment:list',   'upload',      'admin', NOW(), '', NULL, '出库单管理菜单'),

  (2100, '仓库查询', 2002, 1, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:warehouse:query',  '#', 'admin', NOW(), '', NULL, ''),
  (2101, '仓库新增', 2002, 2, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:warehouse:add',    '#', 'admin', NOW(), '', NULL, ''),
  (2102, '仓库修改', 2002, 3, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:warehouse:edit',   '#', 'admin', NOW(), '', NULL, ''),
  (2103, '仓库删除', 2002, 4, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:warehouse:remove', '#', 'admin', NOW(), '', NULL, ''),
  (2104, '仓库导出', 2002, 5, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:warehouse:export', '#', 'admin', NOW(), '', NULL, ''),

  (2110, '库区查询', 2003, 1, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:area:query',  '#', 'admin', NOW(), '', NULL, ''),
  (2111, '库区新增', 2003, 2, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:area:add',    '#', 'admin', NOW(), '', NULL, ''),
  (2112, '库区修改', 2003, 3, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:area:edit',   '#', 'admin', NOW(), '', NULL, ''),
  (2113, '库区删除', 2003, 4, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:area:remove', '#', 'admin', NOW(), '', NULL, ''),
  (2114, '库区导出', 2003, 5, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:area:export', '#', 'admin', NOW(), '', NULL, ''),

  (2120, '库位查询', 2004, 1, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:location:query',  '#', 'admin', NOW(), '', NULL, ''),
  (2121, '库位新增', 2004, 2, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:location:add',    '#', 'admin', NOW(), '', NULL, ''),
  (2122, '库位修改', 2004, 3, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:location:edit',   '#', 'admin', NOW(), '', NULL, ''),
  (2123, '库位删除', 2004, 4, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:location:remove', '#', 'admin', NOW(), '', NULL, ''),
  (2124, '库位导出', 2004, 5, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:location:export', '#', 'admin', NOW(), '', NULL, ''),

  (2130, '物料查询', 2005, 1, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:item:query',  '#', 'admin', NOW(), '', NULL, ''),
  (2131, '物料新增', 2005, 2, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:item:add',    '#', 'admin', NOW(), '', NULL, ''),
  (2132, '物料修改', 2005, 3, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:item:edit',   '#', 'admin', NOW(), '', NULL, ''),
  (2133, '物料删除', 2005, 4, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:item:remove', '#', 'admin', NOW(), '', NULL, ''),
  (2134, '物料导出', 2005, 5, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:item:export', '#', 'admin', NOW(), '', NULL, ''),

  (2140, '库存查询', 2006, 1, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:stock:query',  '#', 'admin', NOW(), '', NULL, ''),
  (2141, '库存导出', 2006, 2, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:stock:export', '#', 'admin', NOW(), '', NULL, ''),

  (2150, '入库查询', 2007, 1, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:receipt:query',    '#', 'admin', NOW(), '', NULL, ''),
  (2151, '入库新增', 2007, 2, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:receipt:add',      '#', 'admin', NOW(), '', NULL, ''),
  (2152, '入库修改', 2007, 3, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:receipt:edit',     '#', 'admin', NOW(), '', NULL, ''),
  (2153, '入库删除', 2007, 4, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:receipt:remove',   '#', 'admin', NOW(), '', NULL, ''),
  (2154, '入库导出', 2007, 5, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:receipt:export',   '#', 'admin', NOW(), '', NULL, ''),
  (2155, '完成入库', 2007, 6, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:receipt:complete', '#', 'admin', NOW(), '', NULL, ''),

  (2160, '出库查询', 2008, 1, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:shipment:query',    '#', 'admin', NOW(), '', NULL, ''),
  (2161, '出库新增', 2008, 2, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:shipment:add',      '#', 'admin', NOW(), '', NULL, ''),
  (2162, '出库修改', 2008, 3, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:shipment:edit',     '#', 'admin', NOW(), '', NULL, ''),
  (2163, '出库删除', 2008, 4, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:shipment:remove',   '#', 'admin', NOW(), '', NULL, ''),
  (2164, '出库导出', 2008, 5, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:shipment:export',   '#', 'admin', NOW(), '', NULL, ''),
  (2165, '完成出库', 2008, 6, '#', '', '', '', 1, 0, 'F', '0', '0', 'wms:shipment:complete', '#', 'admin', NOW(), '', NULL, '');

INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT 1, menu_id
FROM sys_menu
WHERE menu_id BETWEEN 2000 AND 2199;
