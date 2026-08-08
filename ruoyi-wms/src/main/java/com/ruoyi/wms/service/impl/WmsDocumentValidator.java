package com.ruoyi.wms.service.impl;

import java.util.Date;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import org.springframework.stereotype.Component;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.wms.domain.WmsArea;
import com.ruoyi.wms.domain.WmsItem;
import com.ruoyi.wms.domain.WmsLocation;
import com.ruoyi.wms.domain.WmsReceiptLine;
import com.ruoyi.wms.domain.WmsShipmentLine;
import com.ruoyi.wms.domain.WmsWarehouse;
import com.ruoyi.wms.mapper.WmsItemMapper;
import com.ruoyi.wms.mapper.WmsAreaMapper;
import com.ruoyi.wms.mapper.WmsLocationMapper;
import com.ruoyi.wms.mapper.WmsWarehouseMapper;

/** 入出库单共用业务校验。 */
@Component
class WmsDocumentValidator
{
    private final WmsWarehouseMapper warehouseMapper;
    private final WmsAreaMapper areaMapper;
    private final WmsLocationMapper locationMapper;
    private final WmsItemMapper itemMapper;

    WmsDocumentValidator(WmsWarehouseMapper warehouseMapper,WmsAreaMapper areaMapper,WmsLocationMapper locationMapper,WmsItemMapper itemMapper)
    {this.warehouseMapper=warehouseMapper;this.areaMapper=areaMapper;this.locationMapper=locationMapper;this.itemMapper=itemMapper;}

    void validateReceipt(Long warehouseId,List<WmsReceiptLine> lines,boolean completion)
    {
        validateWarehouse(warehouseId);if(lines==null||lines.isEmpty())throw new ServiceException("入库明细不能为空");
        Set<String> keys=new HashSet<>();int index=0;
        for(WmsReceiptLine line:lines)
        {
            index++;if(line==null)throw new ServiceException("第"+index+"行入库明细不能为空");normalizeBatch(line);validateCommon(warehouseId,line.getItemId(),line.getLocationId(),line.getProductionDate(),line.getExpiryDate(),index);
            if(line.getPlannedQty()==null||line.getPlannedQty().signum()<=0)throw new ServiceException("第"+index+"行计划数量必须大于0");
            if(line.getReceivedQty()==null)line.setReceivedQty(line.getPlannedQty());
            if(line.getReceivedQty().signum()<0||completion&&line.getReceivedQty().signum()<=0)throw new ServiceException("第"+index+"行实收数量必须大于0");
            String key=line.getItemId()+"|"+line.getLocationId()+"|"+line.getBatchNo();if(!keys.add(key))throw new ServiceException("第"+index+"行与前面明细的物料、库位和批次重复");
        }
    }

    void validateShipment(Long warehouseId,List<WmsShipmentLine> lines,boolean completion)
    {
        validateWarehouse(warehouseId);if(lines==null||lines.isEmpty())throw new ServiceException("出库明细不能为空");
        Set<String> keys=new HashSet<>();int index=0;
        for(WmsShipmentLine line:lines)
        {
            index++;if(line==null)throw new ServiceException("第"+index+"行出库明细不能为空");normalizeBatch(line);validateCommon(warehouseId,line.getItemId(),line.getLocationId(),line.getProductionDate(),line.getExpiryDate(),index);
            if(line.getPlannedQty()==null||line.getPlannedQty().signum()<=0)throw new ServiceException("第"+index+"行计划数量必须大于0");
            if(line.getShippedQty()==null)line.setShippedQty(line.getPlannedQty());
            if(line.getShippedQty().signum()<0||completion&&line.getShippedQty().signum()<=0)throw new ServiceException("第"+index+"行实发数量必须大于0");
            String key=line.getItemId()+"|"+line.getLocationId()+"|"+line.getBatchNo();if(!keys.add(key))throw new ServiceException("第"+index+"行与前面明细的物料、库位和批次重复");
        }
    }

    private void validateWarehouse(Long id)
    {
        WmsWarehouse warehouse=warehouseMapper.selectWarehouseById(id);if(warehouse==null)throw new ServiceException("单据仓库不存在");
        if(!"0".equals(warehouse.getStatus()))throw new ServiceException("单据仓库已停用");
    }
    private void validateCommon(Long warehouseId,Long itemId,Long locationId,Date productionDate,Date expiryDate,int index)
    {
        WmsItem item=itemMapper.selectItemById(itemId);if(item==null)throw new ServiceException("第"+index+"行物料不存在");if(!"0".equals(item.getStatus()))throw new ServiceException("第"+index+"行物料已停用");
        WmsLocation location=locationMapper.selectLocationById(locationId);if(location==null)throw new ServiceException("第"+index+"行库位不存在");
        if(!"0".equals(location.getStatus()))throw new ServiceException("第"+index+"行库位已停用");if(!warehouseId.equals(location.getWarehouseId()))throw new ServiceException("第"+index+"行库位不属于单据仓库");
        WmsArea area=areaMapper.selectAreaById(location.getAreaId());if(area==null||!"0".equals(area.getStatus()))throw new ServiceException("第"+index+"行库位所属库区不存在或已停用");
        if(productionDate!=null&&expiryDate!=null&&productionDate.after(expiryDate))throw new ServiceException("第"+index+"行生产日期不能晚于失效日期");
    }
    private void normalizeBatch(WmsReceiptLine line){line.setBatchNo(normalizeBatch(line.getBatchNo()));}
    private void normalizeBatch(WmsShipmentLine line){line.setBatchNo(normalizeBatch(line.getBatchNo()));}
    private String normalizeBatch(String raw)
    {
        String batch=StringUtils.trimToEmpty(raw).toUpperCase(Locale.ROOT);
        if(!batch.matches("[A-Z0-9._/-]*"))throw new ServiceException("批次号只能包含字母、数字、点、下划线、斜杠或短横线");
        return batch;
    }
}
