package com.ruoyi.wms.domain;

import java.io.Serializable;
import java.math.BigDecimal;
import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.annotation.Excel;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** 入库单明细。 */
public class WmsReceiptLine implements Serializable
{
    private static final long serialVersionUID = 1L;
    private Long lineId;
    private Long receiptId;
    @Excel(name = "物料ID") private Long itemId;
    private String itemCode;
    private String itemName;
    private String specification;
    private String unit;
    @Excel(name = "库位ID") private Long locationId;
    private String locationCode;
    private String locationName;
    @Excel(name = "批次号") private String batchNo;
    @JsonFormat(pattern = "yyyy-MM-dd") @Excel(name = "生产日期", dateFormat = "yyyy-MM-dd") private Date productionDate;
    @JsonFormat(pattern = "yyyy-MM-dd") @Excel(name = "失效日期", dateFormat = "yyyy-MM-dd") private Date expiryDate;
    @Excel(name = "计划数量") private BigDecimal plannedQty;
    @Excel(name = "实收数量") private BigDecimal receivedQty;

    public Long getLineId() { return lineId; }
    public void setLineId(Long lineId) { this.lineId = lineId; }
    public Long getReceiptId() { return receiptId; }
    public void setReceiptId(Long receiptId) { this.receiptId = receiptId; }
    @NotNull(message = "物料不能为空") public Long getItemId() { return itemId; }
    public void setItemId(Long itemId) { this.itemId = itemId; }
    public String getItemCode() { return itemCode; }
    public void setItemCode(String itemCode) { this.itemCode = itemCode; }
    public String getItemName() { return itemName; }
    public void setItemName(String itemName) { this.itemName = itemName; }
    public String getSpecification() { return specification; }
    public void setSpecification(String specification) { this.specification = specification; }
    public String getUnit() { return unit; }
    public void setUnit(String unit) { this.unit = unit; }
    @NotNull(message = "库位不能为空") public Long getLocationId() { return locationId; }
    public void setLocationId(Long locationId) { this.locationId = locationId; }
    public String getLocationCode() { return locationCode; }
    public void setLocationCode(String locationCode) { this.locationCode = locationCode; }
    public String getLocationName() { return locationName; }
    public void setLocationName(String locationName) { this.locationName = locationName; }
    @Size(max = 64, message = "批次号不能超过64个字符") public String getBatchNo() { return batchNo; }
    public void setBatchNo(String batchNo) { this.batchNo = batchNo; }
    public Date getProductionDate() { return productionDate; }
    public void setProductionDate(Date productionDate) { this.productionDate = productionDate; }
    public Date getExpiryDate() { return expiryDate; }
    public void setExpiryDate(Date expiryDate) { this.expiryDate = expiryDate; }
    @NotNull(message = "计划数量不能为空") @DecimalMin(value = "0.0001", message = "计划数量必须大于等于0.0001") @Digits(integer = 14, fraction = 4, message = "计划数量最多14位整数和4位小数")
    public BigDecimal getPlannedQty() { return plannedQty; }
    public void setPlannedQty(BigDecimal plannedQty) { this.plannedQty = plannedQty; }
    @DecimalMin(value = "0", message = "实收数量不能小于0") @Digits(integer = 14, fraction = 4, message = "实收数量最多14位整数和4位小数") public BigDecimal getReceivedQty() { return receivedQty; }
    public void setReceivedQty(BigDecimal receivedQty) { this.receivedQty = receivedQty; }
}
