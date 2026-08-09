package com.yian.wms.business.service;

import java.util.List;
import com.yian.wms.business.domain.WmsLocation;

public interface IWmsLocationService
{
    WmsLocation selectLocationById(Long id);
    List<WmsLocation> selectLocationList(WmsLocation query);
    List<WmsLocation> selectEnabledOptions(Long warehouseId);
    int insertLocation(WmsLocation location);
    int updateLocation(WmsLocation location);
    void deleteLocationByIds(Long[] ids);
}
