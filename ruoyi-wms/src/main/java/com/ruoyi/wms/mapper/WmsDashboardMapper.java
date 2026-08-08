package com.ruoyi.wms.mapper;

import java.util.List;
import java.util.Map;
import com.ruoyi.wms.domain.WmsStockMovement;

public interface WmsDashboardMapper
{
    Map<String, Object> selectSummary();
    List<WmsStockMovement> selectRecentMovements();
}
