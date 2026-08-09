package com.yian.wms.business.mapper;

import java.math.BigDecimal;
import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.yian.wms.business.domain.WmsShipment;
import com.yian.wms.business.domain.WmsShipmentLine;

public interface WmsShipmentMapper
{
    WmsShipment selectShipmentById(Long shipmentId);
    WmsShipment selectShipmentForUpdate(Long shipmentId);
    List<WmsShipment> selectShipmentList(WmsShipment shipment);
    List<WmsShipmentLine> selectLinesByShipmentId(Long shipmentId);
    int insertShipment(WmsShipment shipment);
    int updateShipment(WmsShipment shipment);
    int deleteShipmentById(Long shipmentId);
    int deleteLinesByShipmentId(Long shipmentId);
    int insertLines(@Param("shipmentId") Long shipmentId, @Param("lines") List<WmsShipmentLine> lines);
    int markCompleted(@Param("shipmentId") Long shipmentId, @Param("totalQty") BigDecimal totalQty, @Param("updateBy") String updateBy);
}
