package com.yian.wms.business.service;

import java.util.List;
import com.yian.wms.business.domain.WmsStock;
import com.yian.wms.business.domain.WmsStockMovement;

public interface IWmsStockService
{
    List<WmsStock> selectStockList(WmsStock query);
    List<WmsStock> selectLowStockList(WmsStock query);
    List<WmsStockMovement> selectMovementList(WmsStockMovement query);
}
