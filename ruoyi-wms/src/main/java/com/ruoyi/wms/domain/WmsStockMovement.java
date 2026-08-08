package com.ruoyi.wms.domain;

import java.math.BigDecimal;
import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/** 库存流水。 */
public class WmsStockMovement extends BaseEntity
{
    private static final long serialVersionUID = 1L;
    private Long movementId;
    @Excel(name = "业务类型") private String bizType;
    @Excel(name = "业务单号") private String bizNo;
    private Long warehouseId;
    @Excel(name = "仓库编码") private String warehouseCode;
    @Excel(name = "仓库名称") private String warehouseName;
    private Long locationId;
    @Excel(name = "库位编码") private String locationCode;
    @Excel(name = "库位名称") private String locationName;
    private Long itemId;
    @Excel(name = "物料编码") private String itemCode;
    @Excel(name = "物料名称") private String itemName;
    @Excel(name = "规格") private String specification;
    @Excel(name = "单位") private String unit;
    @Excel(name = "批次号") private String batchNo;
    @Excel(name = "变动数量") private BigDecimal changeQty;
    @Excel(name = "结存数量") private BigDecimal balanceQty;
    @Excel(name = "操作人") private String operator;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss") @Excel(name = "操作时间", dateFormat = "yyyy-MM-dd HH:mm:ss") private Date operationTime;
    /** 批次号是否精确匹配（仅用于查询）。 */
    private Boolean exactBatch;

    public Long getMovementId() { return movementId; }
    public void setMovementId(Long movementId) { this.movementId = movementId; }
    public String getBizType() { return bizType; }
    public void setBizType(String bizType) { this.bizType = bizType; }
    public String getBizNo() { return bizNo; }
    public void setBizNo(String bizNo) { this.bizNo = bizNo; }
    public Long getWarehouseId() { return warehouseId; }
    public void setWarehouseId(Long warehouseId) { this.warehouseId = warehouseId; }
    public String getWarehouseCode() { return warehouseCode; }
    public void setWarehouseCode(String warehouseCode) { this.warehouseCode = warehouseCode; }
    public String getWarehouseName() { return warehouseName; }
    public void setWarehouseName(String warehouseName) { this.warehouseName = warehouseName; }
    public Long getLocationId() { return locationId; }
    public void setLocationId(Long locationId) { this.locationId = locationId; }
    public String getLocationCode() { return locationCode; }
    public void setLocationCode(String locationCode) { this.locationCode = locationCode; }
    public String getLocationName() { return locationName; }
    public void setLocationName(String locationName) { this.locationName = locationName; }
    public Long getItemId() { return itemId; }
    public void setItemId(Long itemId) { this.itemId = itemId; }
    public String getItemCode() { return itemCode; }
    public void setItemCode(String itemCode) { this.itemCode = itemCode; }
    public String getItemName() { return itemName; }
    public void setItemName(String itemName) { this.itemName = itemName; }
    public String getSpecification() { return specification; }
    public void setSpecification(String specification) { this.specification = specification; }
    public String getUnit() { return unit; }
    public void setUnit(String unit) { this.unit = unit; }
    public String getBatchNo() { return batchNo; }
    public void setBatchNo(String batchNo) { this.batchNo = batchNo; }
    public BigDecimal getChangeQty() { return changeQty; }
    public void setChangeQty(BigDecimal changeQty) { this.changeQty = changeQty; }
    public BigDecimal getBalanceQty() { return balanceQty; }
    public void setBalanceQty(BigDecimal balanceQty) { this.balanceQty = balanceQty; }
    public String getOperator() { return operator; }
    public void setOperator(String operator) { this.operator = operator; }
    public Date getOperationTime() { return operationTime; }
    public void setOperationTime(Date operationTime) { this.operationTime = operationTime; }
    public Boolean getExactBatch() { return exactBatch; }
    public void setExactBatch(Boolean exactBatch) { this.exactBatch = exactBatch; }
}
