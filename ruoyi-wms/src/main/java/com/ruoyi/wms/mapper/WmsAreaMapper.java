package com.ruoyi.wms.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.wms.domain.WmsArea;

public interface WmsAreaMapper
{
    WmsArea selectAreaById(Long areaId);
    List<WmsArea> selectAreaList(WmsArea area);
    int insertArea(WmsArea area);
    int updateArea(WmsArea area);
    int deleteAreaById(Long areaId);
    int countCode(@Param("warehouseId") Long warehouseId, @Param("areaCode") String areaCode, @Param("areaId") Long areaId);
    int countReferences(Long areaId);
}
