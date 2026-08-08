package com.ruoyi.wms.service.impl;

import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;
import com.ruoyi.wms.domain.WmsStockMovement;
import com.ruoyi.wms.mapper.WmsDashboardMapper;
import com.ruoyi.wms.service.IWmsDashboardService;

@Service
public class WmsDashboardServiceImpl implements IWmsDashboardService
{
    private final WmsDashboardMapper mapper;
    public WmsDashboardServiceImpl(WmsDashboardMapper mapper){this.mapper=mapper;}
    @Override public Map<String,Object> selectSummary(){return mapper.selectSummary();}
    @Override public List<WmsStockMovement> selectRecentMovements(){return mapper.selectRecentMovements();}
}
