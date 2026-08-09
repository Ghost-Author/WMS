package com.yian.wms.business.service;

import java.util.List;
import com.yian.wms.business.domain.WmsWarehouse;

public interface IWmsWarehouseService
{
    WmsWarehouse selectWarehouseById(Long id);
    List<WmsWarehouse> selectWarehouseList(WmsWarehouse query);
    List<WmsWarehouse> selectEnabledOptions();
    int insertWarehouse(WmsWarehouse warehouse);
    int updateWarehouse(WmsWarehouse warehouse);
    void deleteWarehouseByIds(Long[] ids);
}
