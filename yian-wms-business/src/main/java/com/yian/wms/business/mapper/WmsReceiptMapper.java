package com.yian.wms.business.mapper;

import java.math.BigDecimal;
import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.yian.wms.business.domain.WmsReceipt;
import com.yian.wms.business.domain.WmsReceiptLine;

public interface WmsReceiptMapper
{
    WmsReceipt selectReceiptById(Long receiptId);
    WmsReceipt selectReceiptForUpdate(Long receiptId);
    List<WmsReceipt> selectReceiptList(WmsReceipt receipt);
    List<WmsReceiptLine> selectLinesByReceiptId(Long receiptId);
    int insertReceipt(WmsReceipt receipt);
    int updateReceipt(WmsReceipt receipt);
    int deleteReceiptById(Long receiptId);
    int deleteLinesByReceiptId(Long receiptId);
    int insertLines(@Param("receiptId") Long receiptId, @Param("lines") List<WmsReceiptLine> lines);
    int markCompleted(@Param("receiptId") Long receiptId, @Param("totalQty") BigDecimal totalQty, @Param("updateBy") String updateBy);
    int markCancelled(@Param("receiptId") Long receiptId, @Param("updateBy") String updateBy);
}
