package com.ruoyi.wms.service;

import java.util.List;
import com.ruoyi.wms.domain.WmsStock;
import com.ruoyi.wms.domain.WmsStockMovement;

public interface IWmsStockService
{
    List<WmsStock> selectStockList(WmsStock query);
    List<WmsStock> selectLowStockList(WmsStock query);
    List<WmsStockMovement> selectMovementList(WmsStockMovement query);
}
