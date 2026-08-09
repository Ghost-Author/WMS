package com.yian.wms.business.service;

import java.util.List;
import com.yian.wms.business.domain.WmsArea;

public interface IWmsAreaService
{
    WmsArea selectAreaById(Long id);
    List<WmsArea> selectAreaList(WmsArea query);
    int insertArea(WmsArea area);
    int updateArea(WmsArea area);
    void deleteAreaByIds(Long[] ids);
}
