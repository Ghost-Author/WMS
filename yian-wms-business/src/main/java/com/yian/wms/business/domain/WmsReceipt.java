package com.yian.wms.business.domain;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.yian.wms.common.annotation.Excel;
import com.yian.wms.common.core.domain.BaseEntity;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** 入库单主表。 */
public class WmsReceipt extends BaseEntity
{
    private static final long serialVersionUID = 1L;
    private Long receiptId;
    @Excel(name = "入库单号") private String receiptNo;
    @Excel(name = "入库类型") private String receiptType;
    private Long warehouseId;
    @Excel(name = "仓库") private String warehouseName;
    @Excel(name = "供应商") private String supplierName;
    @JsonFormat(pattern = "yyyy-MM-dd") @Excel(name = "入库日期", dateFormat = "yyyy-MM-dd") private Date receiptDate;
    @Excel(name = "状态") private String status;
    @Excel(name = "总数量") private BigDecimal totalQty;
    @Valid private List<WmsReceiptLine> lines = new ArrayList<>();

    public Long getReceiptId() { return receiptId; }
    public void setReceiptId(Long receiptId) { this.receiptId = receiptId; }
    public String getReceiptNo() { return receiptNo; }
    public void setReceiptNo(String receiptNo) { this.receiptNo = receiptNo; }
    @NotBlank(message = "入库类型不能为空") @Size(max = 20) public String getReceiptType() { return receiptType; }
    public void setReceiptType(String receiptType) { this.receiptType = receiptType; }
    @NotNull(message = "仓库不能为空") public Long getWarehouseId() { return warehouseId; }
    public void setWarehouseId(Long warehouseId) { this.warehouseId = warehouseId; }
    public String getWarehouseName() { return warehouseName; }
    public void setWarehouseName(String warehouseName) { this.warehouseName = warehouseName; }
    @Size(max = 100, message = "供应商名称不能超过100个字符") public String getSupplierName() { return supplierName; }
    public void setSupplierName(String supplierName) { this.supplierName = supplierName; }
    @NotNull(message = "入库日期不能为空") public Date getReceiptDate() { return receiptDate; }
    public void setReceiptDate(Date receiptDate) { this.receiptDate = receiptDate; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public BigDecimal getTotalQty() { return totalQty; }
    public void setTotalQty(BigDecimal totalQty) { this.totalQty = totalQty; }
    @NotEmpty(message = "入库明细不能为空") public List<WmsReceiptLine> getLines() { return lines; }
    public void setLines(List<WmsReceiptLine> lines) { this.lines = lines; }
    @Override @Size(max = 500, message = "备注不能超过500个字符") public String getRemark() { return super.getRemark(); }
}
