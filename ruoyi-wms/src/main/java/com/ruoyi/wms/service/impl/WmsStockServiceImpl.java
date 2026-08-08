package com.ruoyi.wms.service.impl;

import java.util.List;
import org.springframework.stereotype.Service;
import com.ruoyi.wms.domain.WmsStock;
import com.ruoyi.wms.domain.WmsStockMovement;
import com.ruoyi.wms.mapper.WmsStockMapper;
import com.ruoyi.wms.service.IWmsStockService;

@Service
public class WmsStockServiceImpl implements IWmsStockService
{
    private final WmsStockMapper mapper;
    public WmsStockServiceImpl(WmsStockMapper mapper){this.mapper=mapper;}
    @Override public List<WmsStock> selectStockList(WmsStock query){return mapper.selectStockList(query);}
    @Override public List<WmsStock> selectLowStockList(WmsStock query){return mapper.selectLowStockList(query);}
    @Override public List<WmsStockMovement> selectMovementList(WmsStockMovement query){return mapper.selectMovementList(query);}
}
