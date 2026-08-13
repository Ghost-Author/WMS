package com.yian.wms.business.service;

import java.util.List;
import java.util.Map;
import com.yian.wms.business.domain.WmsStockMovement;

public interface IWmsDashboardService
{
    Map<String, Object> selectSummary();
    List<WmsStockMovement> selectRecentMovements();
    List<Map<String, Object>> selectOperationTrend();
    List<Map<String, Object>> selectWarehouseStockDistribution();
}
