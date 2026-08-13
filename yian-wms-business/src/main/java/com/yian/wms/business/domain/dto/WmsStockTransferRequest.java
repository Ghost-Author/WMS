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

/** 库存调拨请求。 */
public class WmsStockTransferRequest implements Serializable
{
    private static final long serialVersionUID = 1L;

    @NotNull(message = "来源库存ID不能为空")
    @Positive(message = "来源库存ID必须大于0")
    private Long stockId;

    @NotNull(message = "目标库位不能为空")
    @Positive(message = "目标库位ID必须大于0")
    private Long targetLocationId;

    @NotNull(message = "调拨数量不能为空")
    @DecimalMin(value = "0.0001", message = "调拨数量必须大于0")
    @DecimalMax(value = "99999999999999.9999", message = "调拨数量超出系统可存储范围")
    @Digits(integer = 14, fraction = 4, message = "调拨数量最多14位整数和4位小数")
    private BigDecimal quantity;

    @NotBlank(message = "调拨原因不能为空")
    @Size(max = 500, message = "调拨原因不能超过500个字符")
    private String remark;

    public Long getStockId() { return stockId; }
    public void setStockId(Long stockId) { this.stockId = stockId; }
    public Long getTargetLocationId() { return targetLocationId; }
    public void setTargetLocationId(Long targetLocationId) { this.targetLocationId = targetLocationId; }
    public BigDecimal getQuantity() { return quantity; }
    public void setQuantity(BigDecimal quantity) { this.quantity = quantity; }
    public String getRemark() { return remark; }
    public void setRemark(String remark) { this.remark = remark; }
}
