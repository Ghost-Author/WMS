package com.yian.wms.business.domain;

import java.math.BigDecimal;
import com.yian.wms.common.annotation.Excel;
import com.yian.wms.common.core.domain.BaseEntity;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** 库位档案。 */
public class WmsLocation extends BaseEntity
{
    private static final long serialVersionUID = 1L;
    @Excel(name = "库位ID") private Long locationId;
    @Excel(name = "仓库ID") private Long warehouseId;
    @Excel(name = "仓库名称") private String warehouseName;
    @Excel(name = "库区ID") private Long areaId;
    @Excel(name = "库区名称") private String areaName;
    @Excel(name = "库区类型") private String areaType;
    @Excel(name = "库位编码") private String locationCode;
    @Excel(name = "库位名称") private String locationName;
    @Excel(name = "库位类型") private String locationType;
    @Excel(name = "容量") private BigDecimal capacityQty;
    @Excel(name = "状态", readConverterExp = "0=启用,1=停用") private String status;

    public Long getLocationId() { return locationId; }
    public void setLocationId(Long locationId) { this.locationId = locationId; }
    @NotNull(message = "所属仓库不能为空") public Long getWarehouseId() { return warehouseId; }
    public void setWarehouseId(Long warehouseId) { this.warehouseId = warehouseId; }
    public String getWarehouseName() { return warehouseName; }
    public void setWarehouseName(String warehouseName) { this.warehouseName = warehouseName; }
    @NotNull(message = "所属库区不能为空") public Long getAreaId() { return areaId; }
    public void setAreaId(Long areaId) { this.areaId = areaId; }
    public String getAreaName() { return areaName; }
    public void setAreaName(String areaName) { this.areaName = areaName; }
    public String getAreaType() { return areaType; }
    public void setAreaType(String areaType) { this.areaType = areaType; }
    @NotBlank(message = "库位编码不能为空") @Size(max = 32) public String getLocationCode() { return locationCode; }
    public void setLocationCode(String locationCode) { this.locationCode = locationCode; }
    @NotBlank(message = "库位名称不能为空") @Size(max = 100) public String getLocationName() { return locationName; }
    public void setLocationName(String locationName) { this.locationName = locationName; }
    @NotBlank(message = "库位类型不能为空") @Size(max = 20) public String getLocationType() { return locationType; }
    public void setLocationType(String locationType) { this.locationType = locationType; }
    @DecimalMin(value = "0", message = "库位容量不能小于0") @Digits(integer = 14, fraction = 4, message = "库位容量最多14位整数和4位小数") public BigDecimal getCapacityQty() { return capacityQty; }
    public void setCapacityQty(BigDecimal capacityQty) { this.capacityQty = capacityQty; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    @Override @Size(max = 500, message = "备注不能超过500个字符") public String getRemark() { return super.getRemark(); }
}
