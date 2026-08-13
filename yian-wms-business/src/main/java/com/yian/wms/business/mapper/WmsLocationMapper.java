package com.yian.wms.business.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.yian.wms.business.domain.WmsLocation;

public interface WmsLocationMapper
{
    WmsLocation selectLocationById(Long locationId);
    WmsLocation selectLocationByIdForUpdate(Long locationId);
    List<WmsLocation> selectLocationList(WmsLocation location);
    List<WmsLocation> selectEnabledOptions(Long warehouseId);
    int insertLocation(WmsLocation location);
    int updateLocation(WmsLocation location);
    int deleteLocationById(Long locationId);
    int countCode(@Param("warehouseId") Long warehouseId, @Param("locationCode") String locationCode, @Param("locationId") Long locationId);
    int countReferences(Long locationId);
}
