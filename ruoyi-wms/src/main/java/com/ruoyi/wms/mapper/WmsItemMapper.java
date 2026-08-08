package com.ruoyi.wms.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.wms.domain.WmsItem;

public interface WmsItemMapper
{
    WmsItem selectItemById(Long itemId);
    List<WmsItem> selectItemList(WmsItem item);
    int insertItem(WmsItem item);
    int updateItem(WmsItem item);
    int deleteItemById(Long itemId);
    int countCode(@Param("itemCode") String itemCode, @Param("itemId") Long itemId);
    int countBarcode(@Param("barcode") String barcode, @Param("itemId") Long itemId);
    int countReferences(Long itemId);
}
