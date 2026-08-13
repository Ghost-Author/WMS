package com.yian.wms.business.domain.dto;

import java.io.Serializable;
import java.math.BigDecimal;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

/** 库存盘点调整请求。 */
public class WmsStockAdjustRequest implements Serializable
{
    private static final long serialVersionUID = 1L;

    @NotNull(message = "库存ID不能为空")
    @Positive(message = "库存ID必须大于0")
    private Long stockId;

    @NotNull(message = "实盘数量不能为空")
    @DecimalMin(value = "0", message = "实盘数量不能小于0")
    @DecimalMax(value = "99999999999999.9999", message = "实盘数量超出系统可存储范围")
    @Digits(integer = 14, fraction = 4, message = "实盘数量最多14位整数和4位小数")
    private BigDecimal countedQuantity;

    @NotBlank(message = "盘点说明不能为空")
    @Size(max = 500, message = "盘点说明不能超过500个字符")
    private String remark;

    public Long getStockId() { return stockId; }
    public void setStockId(Long stockId) { this.stockId = stockId; }
    public BigDecimal getCountedQuantity() { return countedQuantity; }
    public void setCountedQuantity(BigDecimal countedQuantity) { this.countedQuantity = countedQuantity; }
    public String getRemark() { return remark; }
    public void setRemark(String remark) { this.remark = remark; }
}
