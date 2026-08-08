package com.ruoyi.wms.service;

import java.util.List;
import com.ruoyi.wms.domain.WmsArea;

public interface IWmsAreaService
{
    WmsArea selectAreaById(Long id);
    List<WmsArea> selectAreaList(WmsArea query);
    int insertArea(WmsArea area);
    int updateArea(WmsArea area);
    void deleteAreaByIds(Long[] ids);
}
