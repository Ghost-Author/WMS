package com.yian.wms.business.mapper;

import java.util.List;
import java.util.Map;
import com.yian.wms.business.domain.WmsStockMovement;

public interface WmsDashboardMapper
{
    Map<String, Object> selectSummary();
    List<WmsStockMovement> selectRecentMovements();
}
