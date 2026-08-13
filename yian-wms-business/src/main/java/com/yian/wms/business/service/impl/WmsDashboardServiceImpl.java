package com.yian.wms.business.service.impl;

import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;
import com.yian.wms.business.domain.WmsStockMovement;
import com.yian.wms.business.mapper.WmsDashboardMapper;
import com.yian.wms.business.service.IWmsDashboardService;

@Service
public class WmsDashboardServiceImpl implements IWmsDashboardService
{
    private final WmsDashboardMapper mapper;
    public WmsDashboardServiceImpl(WmsDashboardMapper mapper){this.mapper=mapper;}
    @Override public Map<String,Object> selectSummary(){return mapper.selectSummary();}
    @Override public List<WmsStockMovement> selectRecentMovements(){return mapper.selectRecentMovements();}
    @Override public List<Map<String,Object>> selectOperationTrend(){return mapper.selectOperationTrend();}
    @Override public List<Map<String,Object>> selectWarehouseStockDistribution(){return mapper.selectWarehouseStockDistribution();}
}
