package com.yian.wms.business.service.impl;

import java.math.BigDecimal;
import java.util.List;
import java.util.Set;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import com.yian.wms.common.exception.ServiceException;
import com.yian.wms.common.utils.StringUtils;
import com.yian.wms.business.domain.WmsArea;
import com.yian.wms.business.domain.WmsLocation;
import com.yian.wms.business.domain.WmsWarehouse;
import com.yian.wms.business.mapper.WmsAreaMapper;
import com.yian.wms.business.mapper.WmsLocationMapper;
import com.yian.wms.business.mapper.WmsStockMapper;
import com.yian.wms.business.mapper.WmsWarehouseMapper;
import com.yian.wms.business.service.IWmsLocationService;

@Service
public class WmsLocationServiceImpl implements IWmsLocationService
{
    private static final Set<String> LOCATION_TYPES=Set.of("NORMAL","FROZEN","DEFECTIVE");
    private final WmsLocationMapper mapper;
    private final WmsStockMapper stockMapper;
    private final WmsAreaMapper areaMapper;
    private final WmsWarehouseMapper warehouseMapper;
    public WmsLocationServiceImpl(WmsLocationMapper mapper,WmsStockMapper stockMapper,
            WmsAreaMapper areaMapper,WmsWarehouseMapper warehouseMapper)
    { this.mapper=mapper;this.stockMapper=stockMapper;this.areaMapper=areaMapper;this.warehouseMapper=warehouseMapper; }

    @Override public WmsLocation selectLocationById(Long id){return mapper.selectLocationById(id);}
    @Override public List<WmsLocation> selectLocationList(WmsLocation query){return mapper.selectLocationList(query);}
    @Override public List<WmsLocation> selectEnabledOptions(Long warehouseId){return mapper.selectEnabledOptions(warehouseId);}
    @Override public int insertLocation(WmsLocation location){normalizeAndValidate(location);checkCode(location);return mapper.insertLocation(location);}
    @Override @Transactional(isolation=Isolation.READ_COMMITTED,rollbackFor=Exception.class)
    public int updateLocation(WmsLocation location)
    {
        if(location==null||location.getLocationId()==null)throw new ServiceException("库位ID不能为空");
        WmsLocation old=mapper.selectLocationByIdForUpdate(location.getLocationId());
        if(old==null)throw new ServiceException("库位不存在或已删除");
        normalizeAndValidate(location);checkCode(location);
        BigDecimal current=stockMapper.selectTotalQuantityByLocation(location.getLocationId());
        if(current==null)current=BigDecimal.ZERO;
        if(location.getCapacityQty().signum()>0&&current.compareTo(location.getCapacityQty())>0)
            throw new ServiceException("库位【"+old.getLocationCode()+"】当前库存"+current.toPlainString()+"，容量不能下调至"+location.getCapacityQty().toPlainString());
        if(current.signum()>0&&"1".equals(location.getStatus())&&!"1".equals(old.getStatus()))
            throw new ServiceException("库位【"+old.getLocationCode()+"】仍有库存，不能停用");
        if(current.signum()>0&&"DEFECTIVE".equals(location.getLocationType())&&!"DEFECTIVE".equals(old.getLocationType()))
            throw new ServiceException("库位【"+old.getLocationCode()+"】仍有库存，不能直接改为不良品库位");
        if(mapper.countReferences(location.getLocationId())>0 && (!old.getWarehouseId().equals(location.getWarehouseId())||!old.getAreaId().equals(location.getAreaId())))
            throw new ServiceException("库位已被库存或单据引用，不能变更所属仓库/库区");
        int rows=mapper.updateLocation(location);if(rows!=1)throw new ServiceException("库位状态已变更，请刷新后重试");return rows;
    }
    @Override @Transactional(rollbackFor=Exception.class) public void deleteLocationByIds(Long[] ids)
    {
        for(Long id:ids){WmsLocation v=requireExists(id);if(mapper.countReferences(id)>0)throw new ServiceException("库位【"+v.getLocationName()+"】已被库存或单据引用，不能删除");
            try{mapper.deleteLocationById(id);}catch(DataIntegrityViolationException ex){throw new ServiceException("库位已被业务数据引用，不能删除");}}
    }
    private WmsLocation requireExists(Long id){if(id==null)throw new ServiceException("库位ID不能为空");WmsLocation v=mapper.selectLocationById(id);if(v==null)throw new ServiceException("库位不存在或已删除");return v;}
    private void normalizeAndValidate(WmsLocation v)
    {
        v.setLocationCode(v.getLocationCode().trim());v.setLocationName(v.getLocationName().trim());v.setLocationType(StringUtils.upperCase(StringUtils.trim(v.getLocationType())));if(v.getCapacityQty()==null)v.setCapacityQty(BigDecimal.ZERO);if(StringUtils.isBlank(v.getStatus()))v.setStatus("0");
        WmsWarehouse w=warehouseMapper.selectWarehouseById(v.getWarehouseId());if(w==null)throw new ServiceException("所属仓库不存在");if(!"0".equals(w.getStatus()))throw new ServiceException("所属仓库已停用");
        WmsArea a=areaMapper.selectAreaById(v.getAreaId());if(a==null)throw new ServiceException("所属库区不存在");if(!v.getWarehouseId().equals(a.getWarehouseId()))throw new ServiceException("库区不属于所选仓库");if(!"0".equals(a.getStatus()))throw new ServiceException("所属库区已停用");
        if(!LOCATION_TYPES.contains(v.getLocationType()))throw new ServiceException("库位类型只能为 NORMAL、FROZEN 或 DEFECTIVE");
        if(v.getCapacityQty().signum()<0)throw new ServiceException("库位容量不能小于0");if(!"0".equals(v.getStatus())&&!"1".equals(v.getStatus()))throw new ServiceException("库位状态只能为0或1");
    }
    private void checkCode(WmsLocation v){if(mapper.countCode(v.getWarehouseId(),v.getLocationCode(),v.getLocationId())>0)throw new ServiceException("该仓库下库位编码已存在");}
}
