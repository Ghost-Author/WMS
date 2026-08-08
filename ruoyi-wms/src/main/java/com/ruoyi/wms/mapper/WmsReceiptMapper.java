package com.ruoyi.wms.mapper;

import java.math.BigDecimal;
import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.wms.domain.WmsReceipt;
import com.ruoyi.wms.domain.WmsReceiptLine;

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
}
