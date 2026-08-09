package com.yian.wms.business.domain;

import com.yian.wms.common.annotation.Excel;
import com.yian.wms.common.core.domain.BaseEntity;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** 仓库档案。 */
public class WmsWarehouse extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    @Excel(name = "仓库ID")
    private Long warehouseId;
    @Excel(name = "仓库编码")
    private String warehouseCode;
    @Excel(name = "仓库名称")
    private String warehouseName;
    @Excel(name = "地址")
    private String address;
    @Excel(name = "负责人")
    private String manager;
    @Excel(name = "联系电话")
    private String phone;
    @Excel(name = "状态", readConverterExp = "0=启用,1=停用")
    private String status;

    public Long getWarehouseId() { return warehouseId; }
    public void setWarehouseId(Long warehouseId) { this.warehouseId = warehouseId; }
    @NotBlank(message = "仓库编码不能为空")
    @Size(max = 32, message = "仓库编码不能超过32个字符")
    public String getWarehouseCode() { return warehouseCode; }
    public void setWarehouseCode(String warehouseCode) { this.warehouseCode = warehouseCode; }
    @NotBlank(message = "仓库名称不能为空")
    @Size(max = 100, message = "仓库名称不能超过100个字符")
    public String getWarehouseName() { return warehouseName; }
    public void setWarehouseName(String warehouseName) { this.warehouseName = warehouseName; }
    @Size(max = 255, message = "仓库地址不能超过255个字符") public String getAddress() { return address; }
    public void setAddress(String address) { this.address = address; }
    @Size(max = 50, message = "负责人不能超过50个字符") public String getManager() { return manager; }
    public void setManager(String manager) { this.manager = manager; }
    @Size(max = 20, message = "联系电话不能超过20个字符") public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    @Override @Size(max = 500, message = "备注不能超过500个字符") public String getRemark() { return super.getRemark(); }
}
