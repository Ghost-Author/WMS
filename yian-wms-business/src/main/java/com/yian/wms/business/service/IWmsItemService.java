package com.yian.wms.business.service;

import java.util.List;
import com.yian.wms.business.domain.WmsItem;

public interface IWmsItemService
{
    WmsItem selectItemById(Long id);
    List<WmsItem> selectItemList(WmsItem query);
    List<WmsItem> selectEnabledOptions();
    int insertItem(WmsItem item);
    int updateItem(WmsItem item);
    void deleteItemByIds(Long[] ids);
}
