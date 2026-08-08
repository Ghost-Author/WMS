package com.ruoyi.wms.service;

import java.util.List;
import java.util.Map;
import com.ruoyi.wms.domain.WmsStockMovement;

public interface IWmsDashboardService
{
    Map<String, Object> selectSummary();
    List<WmsStockMovement> selectRecentMovements();
}
