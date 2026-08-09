package com.yian.wms.business.service.impl;

import java.util.List;
import java.util.Set;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.yian.wms.common.exception.ServiceException;
import com.yian.wms.common.utils.StringUtils;
import com.yian.wms.business.domain.WmsArea;
import com.yian.wms.business.domain.WmsWarehouse;
import com.yian.wms.business.mapper.WmsAreaMapper;
import com.yian.wms.business.mapper.WmsWarehouseMapper;
import com.yian.wms.business.service.IWmsAreaService;

@Service
public class WmsAreaServiceImpl implements IWmsAreaService
{
    private static final Set<String> AREA_TYPES=Set.of("RECEIVING","STORAGE","PICKING","SHIPPING","RETURN");
    private final WmsAreaMapper mapper;
    private final WmsWarehouseMapper warehouseMapper;
    public WmsAreaServiceImpl(WmsAreaMapper mapper, WmsWarehouseMapper warehouseMapper) { this.mapper=mapper; this.warehouseMapper=warehouseMapper; }

    @Override public WmsArea selectAreaById(Long id) { return mapper.selectAreaById(id); }
    @Override public List<WmsArea> selectAreaList(WmsArea query) { return mapper.selectAreaList(query); }
    @Override public int insertArea(WmsArea area) { normalizeAndValidate(area); checkCode(area); return mapper.insertArea(area); }
    @Override public int updateArea(WmsArea area)
    {
        WmsArea old=requireExists(area.getAreaId()); normalizeAndValidate(area); checkCode(area);
        if (!old.getWarehouseId().equals(area.getWarehouseId()) && mapper.countReferences(area.getAreaId()) > 0)
            throw new ServiceException("库区已有库位，不能变更所属仓库");
        return mapper.updateArea(area);
    }
    @Override @Transactional(rollbackFor=Exception.class) public void deleteAreaByIds(Long[] ids)
    {
        for (Long id:ids) { WmsArea area=requireExists(id); if(mapper.countReferences(id)>0) throw new ServiceException("库区【"+area.getAreaName()+"】已有库位，不能删除");
            try { mapper.deleteAreaById(id); } catch(DataIntegrityViolationException ex) { throw new ServiceException("库区已被业务数据引用，不能删除"); }}
    }
    private WmsArea requireExists(Long id) { if(id==null) throw new ServiceException("库区ID不能为空"); WmsArea v=mapper.selectAreaById(id); if(v==null) throw new ServiceException("库区不存在或已删除"); return v; }
    private void normalizeAndValidate(WmsArea v)
    {
        v.setAreaCode(v.getAreaCode().trim()); v.setAreaName(v.getAreaName().trim());v.setAreaType(StringUtils.upperCase(StringUtils.trim(v.getAreaType())));if(StringUtils.isBlank(v.getStatus()))v.setStatus("0");
        WmsWarehouse w=warehouseMapper.selectWarehouseById(v.getWarehouseId()); if(w==null)throw new ServiceException("所属仓库不存在");
        if(!"0".equals(w.getStatus()))throw new ServiceException("所属仓库已停用");
        if(!AREA_TYPES.contains(v.getAreaType()))throw new ServiceException("库区类型只能为 RECEIVING、STORAGE、PICKING、SHIPPING 或 RETURN");
        if(!"0".equals(v.getStatus())&&!"1".equals(v.getStatus()))throw new ServiceException("库区状态只能为0或1");
    }
    private void checkCode(WmsArea v) { if(mapper.countCode(v.getWarehouseId(),v.getAreaCode(),v.getAreaId())>0)throw new ServiceException("该仓库下库区编码已存在"); }
}
