package com.ruoyi.wms.service;

import java.util.List;
import com.ruoyi.wms.domain.WmsReceipt;

public interface IWmsReceiptService
{
    WmsReceipt selectReceiptById(Long id);
    List<WmsReceipt> selectReceiptList(WmsReceipt query);
    int insertReceipt(WmsReceipt receipt);
    int updateReceipt(WmsReceipt receipt);
    void deleteReceiptByIds(Long[] ids);
    void completeReceipt(Long id, String operator);
}
