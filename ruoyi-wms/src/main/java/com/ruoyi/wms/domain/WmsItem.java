package com.ruoyi.wms.domain;

import java.math.BigDecimal;
import com.ruoyi.common.annotation.Excel;
import com.ruoyi.common.core.domain.BaseEntity;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** 物料档案。 */
public class WmsItem extends BaseEntity
{
    private static final long serialVersionUID = 1L;
    @Excel(name = "物料ID") private Long itemId;
    @Excel(name = "物料编码") private String itemCode;
    @Excel(name = "物料名称") private String itemName;
    @Excel(name = "分类") private String category;
    @Excel(name = "规格") private String specification;
    @Excel(name = "单位") private String unit;
    @Excel(name = "条码") private String barcode;
    @Excel(name = "最低库存") private BigDecimal minStock;
    @Excel(name = "最高库存") private BigDecimal maxStock;
    @Excel(name = "状态", readConverterExp = "0=启用,1=停用") private String status;

    public Long getItemId() { return itemId; }
    public void setItemId(Long itemId) { this.itemId = itemId; }
    @NotBlank(message = "物料编码不能为空") @Size(max = 32) public String getItemCode() { return itemCode; }
    public void setItemCode(String itemCode) { this.itemCode = itemCode; }
    @NotBlank(message = "物料名称不能为空") @Size(max = 100) public String getItemName() { return itemName; }
    public void setItemName(String itemName) { this.itemName = itemName; }
    @Size(max = 50, message = "物料分类不能超过50个字符") public String getCategory() { return category; }
    public void setCategory(String category) { this.category = category; }
    @Size(max = 100, message = "规格型号不能超过100个字符") public String getSpecification() { return specification; }
    public void setSpecification(String specification) { this.specification = specification; }
    @NotBlank(message = "单位不能为空") @Size(max = 20) public String getUnit() { return unit; }
    public void setUnit(String unit) { this.unit = unit; }
    @Size(max = 64, message = "条码不能超过64个字符") public String getBarcode() { return barcode; }
    public void setBarcode(String barcode) { this.barcode = barcode; }
    @DecimalMin(value = "0", message = "最低库存不能小于0") @Digits(integer = 14, fraction = 4, message = "最低库存最多14位整数和4位小数") public BigDecimal getMinStock() { return minStock; }
    public void setMinStock(BigDecimal minStock) { this.minStock = minStock; }
    @DecimalMin(value = "0", message = "最高库存不能小于0") @Digits(integer = 14, fraction = 4, message = "最高库存最多14位整数和4位小数") public BigDecimal getMaxStock() { return maxStock; }
    public void setMaxStock(BigDecimal maxStock) { this.maxStock = maxStock; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    @Override @Size(max = 500, message = "备注不能超过500个字符") public String getRemark() { return super.getRemark(); }
}
