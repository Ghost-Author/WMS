package com.yian.wms.business.service;

import java.util.List;
import com.yian.wms.business.domain.WmsShipment;

public interface IWmsShipmentService
{
    WmsShipment selectShipmentById(Long id);
    List<WmsShipment> selectShipmentList(WmsShipment query);
    int insertShipment(WmsShipment shipment);
    int updateShipment(WmsShipment shipment);
    void deleteShipmentByIds(Long[] ids);
    void completeShipment(Long id, String operator);
}
