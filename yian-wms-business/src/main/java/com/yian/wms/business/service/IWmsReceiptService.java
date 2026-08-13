package com.yian.wms.business.service;

import java.util.List;
import com.yian.wms.business.domain.WmsReceipt;

public interface IWmsReceiptService
{
    WmsReceipt selectReceiptById(Long id);
    List<WmsReceipt> selectReceiptList(WmsReceipt query);
    int insertReceipt(WmsReceipt receipt);
    int updateReceipt(WmsReceipt receipt);
    void deleteReceiptByIds(Long[] ids);
    void completeReceipt(Long id, String operator);
    void cancelReceipt(Long id, String operator);
}
