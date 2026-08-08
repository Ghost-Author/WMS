package com.ruoyi.wms.service;

import java.util.List;
import com.ruoyi.wms.domain.WmsItem;

public interface IWmsItemService
{
    WmsItem selectItemById(Long id);
    List<WmsItem> selectItemList(WmsItem query);
    List<WmsItem> selectEnabledOptions();
    int insertItem(WmsItem item);
    int updateItem(WmsItem item);
    void deleteItemByIds(Long[] ids);
}
