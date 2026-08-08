package com.ruoyi.wms.service;

import java.util.List;
import com.ruoyi.wms.domain.WmsLocation;

public interface IWmsLocationService
{
    WmsLocation selectLocationById(Long id);
    List<WmsLocation> selectLocationList(WmsLocation query);
    List<WmsLocation> selectEnabledOptions(Long warehouseId);
    int insertLocation(WmsLocation location);
    int updateLocation(WmsLocation location);
    void deleteLocationByIds(Long[] ids);
}
