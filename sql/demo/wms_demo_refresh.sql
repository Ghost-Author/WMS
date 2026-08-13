-- Keep the six immutable completed demo documents useful for dashboard demonstrations.
-- This is a business-date projection only: it never changes audit timestamps, lines, stock or movements.

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE TEMPORARY TABLE yian_wms_demo_refresh_guard
(
    receipt_rows INT NOT NULL CHECK (receipt_rows = 3),
    shipment_rows INT NOT NULL CHECK (shipment_rows = 3)
);

START TRANSACTION;

SELECT COUNT(*) INTO @yian_wms_demo_refreshed_receipts
  FROM wms_receipt
 WHERE status = 'COMPLETED'
   AND receipt_no IN ('DEMO-IN-001', 'DEMO-IN-002', 'DEMO-IN-003');
UPDATE wms_receipt
   SET receipt_date = CASE receipt_no
           WHEN 'DEMO-IN-001' THEN CURDATE() - INTERVAL 6 DAY + INTERVAL 9 HOUR
           WHEN 'DEMO-IN-002' THEN CURDATE() - INTERVAL 3 DAY + INTERVAL 10 HOUR
           WHEN 'DEMO-IN-003' THEN CURDATE() + INTERVAL 8 HOUR
       END
 WHERE status = 'COMPLETED'
   AND receipt_no IN ('DEMO-IN-001', 'DEMO-IN-002', 'DEMO-IN-003');

SELECT COUNT(*) INTO @yian_wms_demo_refreshed_shipments
  FROM wms_shipment
 WHERE status = 'COMPLETED'
   AND shipment_no IN ('DEMO-OUT-001', 'DEMO-OUT-002', 'DEMO-OUT-003');
UPDATE wms_shipment
   SET shipment_date = CASE shipment_no
           WHEN 'DEMO-OUT-001' THEN CURDATE() - INTERVAL 5 DAY + INTERVAL 14 HOUR
           WHEN 'DEMO-OUT-002' THEN CURDATE() - INTERVAL 2 DAY + INTERVAL 15 HOUR
           WHEN 'DEMO-OUT-003' THEN CURDATE() + INTERVAL 13 HOUR
       END
 WHERE status = 'COMPLETED'
   AND shipment_no IN ('DEMO-OUT-001', 'DEMO-OUT-002', 'DEMO-OUT-003');

INSERT INTO yian_wms_demo_refresh_guard (receipt_rows, shipment_rows)
VALUES (@yian_wms_demo_refreshed_receipts, @yian_wms_demo_refreshed_shipments);

COMMIT;
DROP TEMPORARY TABLE yian_wms_demo_refresh_guard;
