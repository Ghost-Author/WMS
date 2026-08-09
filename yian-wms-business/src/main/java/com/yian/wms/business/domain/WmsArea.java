package com.yian.wms.business.domain;

import com.yian.wms.common.annotation.Excel;
import com.yian.wms.common.core.domain.BaseEntity;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** 库区档案。 */
public class WmsArea extends BaseEntity
{
    private static final long serialVersionUID = 1L;
    @Excel(name = "库区ID") private Long areaId;
    @Excel(name = "仓库ID") private Long warehouseId;
    @Excel(name = "仓库名称") private String warehouseName;
    @Excel(name = "库区编码") private String areaCode;
    @Excel(name = "库区名称") private String areaName;
    @Excel(name = "库区类型") private String areaType;
    @Excel(name = "状态", readConverterExp = "0=启用,1=停用") private String status;

    public Long getAreaId() { return areaId; }
    public void setAreaId(Long areaId) { this.areaId = areaId; }
    @NotNull(message = "所属仓库不能为空") public Long getWarehouseId() { return warehouseId; }
    public void setWarehouseId(Long warehouseId) { this.warehouseId = warehouseId; }
    public String getWarehouseName() { return warehouseName; }
    public void setWarehouseName(String warehouseName) { this.warehouseName = warehouseName; }
    @NotBlank(message = "库区编码不能为空") @Size(max = 32) public String getAreaCode() { return areaCode; }
    public void setAreaCode(String areaCode) { this.areaCode = areaCode; }
    @NotBlank(message = "库区名称不能为空") @Size(max = 100) public String getAreaName() { return areaName; }
    public void setAreaName(String areaName) { this.areaName = areaName; }
    @NotBlank(message = "库区类型不能为空") @Size(max = 20) public String getAreaType() { return areaType; }
    public void setAreaType(String areaType) { this.areaType = areaType; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    @Override @Size(max = 500, message = "备注不能超过500个字符") public String getRemark() { return super.getRemark(); }
}
