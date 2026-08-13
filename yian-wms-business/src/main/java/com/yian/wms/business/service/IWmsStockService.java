package com.yian.wms.business.service;

import java.util.List;
import com.yian.wms.business.domain.WmsStock;
import com.yian.wms.business.domain.WmsStockMovement;
import com.yian.wms.business.domain.dto.WmsStockAdjustRequest;
import com.yian.wms.business.domain.dto.WmsStockTransferRequest;

public interface IWmsStockService
{
    List<WmsStock> selectStockList(WmsStock query);
    List<WmsStock> selectLowStockList(WmsStock query);
    List<WmsStockMovement> selectMovementList(WmsStockMovement query);
    String transferStock(WmsStockTransferRequest request, String operator);
    String adjustStock(WmsStockAdjustRequest request, String operator);
}
