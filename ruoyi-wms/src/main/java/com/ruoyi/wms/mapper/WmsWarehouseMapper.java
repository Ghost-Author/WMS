package com.ruoyi.wms.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.wms.domain.WmsWarehouse;

public interface WmsWarehouseMapper
{
    WmsWarehouse selectWarehouseById(Long warehouseId);
    List<WmsWarehouse> selectWarehouseList(WmsWarehouse warehouse);
    int insertWarehouse(WmsWarehouse warehouse);
    int updateWarehouse(WmsWarehouse warehouse);
    int deleteWarehouseById(Long warehouseId);
    int countCode(@Param("warehouseCode") String warehouseCode, @Param("warehouseId") Long warehouseId);
    int countReferences(Long warehouseId);
}
