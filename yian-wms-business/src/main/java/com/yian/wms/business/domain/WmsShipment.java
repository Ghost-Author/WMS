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

/** 出库单主表。 */
public class WmsShipment extends BaseEntity
{
    private static final long serialVersionUID = 1L;
    private Long shipmentId;
    @Excel(name = "出库单号") private String shipmentNo;
    @Excel(name = "出库类型") private String shipmentType;
    private Long warehouseId;
    @Excel(name = "仓库") private String warehouseName;
    @Excel(name = "客户") private String customerName;
    @JsonFormat(pattern = "yyyy-MM-dd") @Excel(name = "出库日期", dateFormat = "yyyy-MM-dd") private Date shipmentDate;
    @Excel(name = "状态") private String status;
    @Excel(name = "总数量") private BigDecimal totalQty;
    @Valid private List<WmsShipmentLine> lines = new ArrayList<>();

    public Long getShipmentId() { return shipmentId; }
    public void setShipmentId(Long shipmentId) { this.shipmentId = shipmentId; }
    public String getShipmentNo() { return shipmentNo; }
    public void setShipmentNo(String shipmentNo) { this.shipmentNo = shipmentNo; }
    @NotBlank(message = "出库类型不能为空") @Size(max = 20) public String getShipmentType() { return shipmentType; }
    public void setShipmentType(String shipmentType) { this.shipmentType = shipmentType; }
    @NotNull(message = "仓库不能为空") public Long getWarehouseId() { return warehouseId; }
    public void setWarehouseId(Long warehouseId) { this.warehouseId = warehouseId; }
    public String getWarehouseName() { return warehouseName; }
    public void setWarehouseName(String warehouseName) { this.warehouseName = warehouseName; }
    @Size(max = 100, message = "客户名称不能超过100个字符") public String getCustomerName() { return customerName; }
    public void setCustomerName(String customerName) { this.customerName = customerName; }
    @NotNull(message = "出库日期不能为空") public Date getShipmentDate() { return shipmentDate; }
    public void setShipmentDate(Date shipmentDate) { this.shipmentDate = shipmentDate; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public BigDecimal getTotalQty() { return totalQty; }
    public void setTotalQty(BigDecimal totalQty) { this.totalQty = totalQty; }
    @NotEmpty(message = "出库明细不能为空") public List<WmsShipmentLine> getLines() { return lines; }
    public void setLines(List<WmsShipmentLine> lines) { this.lines = lines; }
    @Override @Size(max = 500, message = "备注不能超过500个字符") public String getRemark() { return super.getRemark(); }
}
