package com.ruoyi.wms.service;

import java.util.List;
import com.ruoyi.wms.domain.WmsWarehouse;

public interface IWmsWarehouseService
{
    WmsWarehouse selectWarehouseById(Long id);
    List<WmsWarehouse> selectWarehouseList(WmsWarehouse query);
    List<WmsWarehouse> selectEnabledOptions();
    int insertWarehouse(WmsWarehouse warehouse);
    int updateWarehouse(WmsWarehouse warehouse);
    void deleteWarehouseByIds(Long[] ids);
}
