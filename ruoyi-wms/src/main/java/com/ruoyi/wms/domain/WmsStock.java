package com.ruoyi.wms.domain;

import java.math.BigDecimal;
import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;

/** 库存余额。 */
public class WmsStock extends BaseEntity
{
    private static final long serialVersionUID = 1L;
    private Long stockId;
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
    @JsonFormat(pattern = "yyyy-MM-dd") @Excel(name = "生产日期", dateFormat = "yyyy-MM-dd") private Date productionDate;
    @JsonFormat(pattern = "yyyy-MM-dd") @Excel(name = "失效日期", dateFormat = "yyyy-MM-dd") private Date expiryDate;
    @Excel(name = "库存数量") private BigDecimal quantity;
    @Excel(name = "锁定数量") private BigDecimal lockedQuantity;
    @Excel(name = "可用数量") private BigDecimal availableQty;
    private BigDecimal minStock;
    private Boolean lowStock;

    public Long getStockId() { return stockId; }
    public void setStockId(Long stockId) { this.stockId = stockId; }
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
    public Date getProductionDate() { return productionDate; }
    public void setProductionDate(Date productionDate) { this.productionDate = productionDate; }
    public Date getExpiryDate() { return expiryDate; }
    public void setExpiryDate(Date expiryDate) { this.expiryDate = expiryDate; }
    public BigDecimal getQuantity() { return quantity; }
    public void setQuantity(BigDecimal quantity) { this.quantity = quantity; }
    public BigDecimal getLockedQuantity() { return lockedQuantity; }
    public void setLockedQuantity(BigDecimal lockedQuantity) { this.lockedQuantity = lockedQuantity; }
    public BigDecimal getAvailableQty() { return availableQty; }
    public void setAvailableQty(BigDecimal availableQty) { this.availableQty = availableQty; }
    public BigDecimal getMinStock() { return minStock; }
    public void setMinStock(BigDecimal minStock) { this.minStock = minStock; }
    public Boolean getLowStock() { return lowStock; }
    public void setLowStock(Boolean lowStock) { this.lowStock = lowStock; }
}
