package com.yian.wms.business.service.impl;

import java.util.List;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.yian.wms.common.exception.ServiceException;
import com.yian.wms.common.utils.StringUtils;
import com.yian.wms.business.domain.WmsWarehouse;
import com.yian.wms.business.mapper.WmsWarehouseMapper;
import com.yian.wms.business.service.IWmsWarehouseService;

@Service
public class WmsWarehouseServiceImpl implements IWmsWarehouseService
{
    private final WmsWarehouseMapper mapper;

    public WmsWarehouseServiceImpl(WmsWarehouseMapper mapper) { this.mapper = mapper; }

    @Override public WmsWarehouse selectWarehouseById(Long id) { return mapper.selectWarehouseById(id); }
    @Override public List<WmsWarehouse> selectWarehouseList(WmsWarehouse query) { return mapper.selectWarehouseList(query); }
    @Override public List<WmsWarehouse> selectEnabledOptions()
    {
        WmsWarehouse query = new WmsWarehouse(); query.setStatus("0"); return mapper.selectWarehouseList(query);
    }
    @Override public int insertWarehouse(WmsWarehouse warehouse)
    {
        normalize(warehouse);
        if (mapper.countCode(warehouse.getWarehouseCode(), null) > 0) throw new ServiceException("仓库编码已存在");
        return mapper.insertWarehouse(warehouse);
    }
    @Override public int updateWarehouse(WmsWarehouse warehouse)
    {
        requireExists(warehouse.getWarehouseId()); normalize(warehouse);
        if (mapper.countCode(warehouse.getWarehouseCode(), warehouse.getWarehouseId()) > 0) throw new ServiceException("仓库编码已存在");
        return mapper.updateWarehouse(warehouse);
    }
    @Override @Transactional(rollbackFor = Exception.class)
    public void deleteWarehouseByIds(Long[] ids)
    {
        for (Long id : ids)
        {
            WmsWarehouse warehouse = requireExists(id);
            if (mapper.countReferences(id) > 0) throw new ServiceException("仓库【" + warehouse.getWarehouseName() + "】已被库区、单据或库存引用，不能删除");
            try { mapper.deleteWarehouseById(id); }
            catch (DataIntegrityViolationException ex) { throw new ServiceException("仓库已被业务数据引用，不能删除"); }
        }
    }
    private WmsWarehouse requireExists(Long id)
    {
        if (id == null) throw new ServiceException("仓库ID不能为空");
        WmsWarehouse value = mapper.selectWarehouseById(id);
        if (value == null) throw new ServiceException("仓库不存在或已删除");
        return value;
    }
    private void normalize(WmsWarehouse value)
    {
        value.setWarehouseCode(value.getWarehouseCode().trim());
        value.setWarehouseName(value.getWarehouseName().trim());
        if (StringUtils.isBlank(value.getStatus())) value.setStatus("0");
        if (!"0".equals(value.getStatus()) && !"1".equals(value.getStatus())) throw new ServiceException("仓库状态只能为0或1");
    }
}
