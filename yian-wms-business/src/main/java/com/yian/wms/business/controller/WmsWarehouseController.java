package com.yian.wms.business.controller;

import java.util.List;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import com.yian.wms.common.annotation.Log;
import com.yian.wms.common.core.controller.BaseController;
import com.yian.wms.common.core.domain.AjaxResult;
import com.yian.wms.common.core.page.TableDataInfo;
import com.yian.wms.common.enums.BusinessType;
import com.yian.wms.common.utils.poi.ExcelUtil;
import com.yian.wms.business.domain.WmsWarehouse;
import com.yian.wms.business.service.IWmsWarehouseService;

@RestController
@RequestMapping("/wms/warehouse")
public class WmsWarehouseController extends BaseController
{
    private final IWmsWarehouseService service;
    public WmsWarehouseController(IWmsWarehouseService service){this.service=service;}
    @PreAuthorize("@ss.hasPermi('wms:warehouse:list')") @GetMapping("/list")
    public TableDataInfo list(WmsWarehouse query){startPage();return getDataTable(service.selectWarehouseList(query));}
    @PreAuthorize("@ss.hasAnyPermi('wms:warehouse:list,wms:area:list,wms:location:list,wms:stock:list,wms:receipt:list,wms:shipment:list')") @GetMapping("/options")
    public AjaxResult options(){return success(service.selectEnabledOptions());}
    @PreAuthorize("@ss.hasAnyPermi('wms:warehouse:query,wms:warehouse:edit')") @GetMapping("/{id}")
    public AjaxResult getInfo(@PathVariable Long id){return success(service.selectWarehouseById(id));}
    @PreAuthorize("@ss.hasPermi('wms:warehouse:add')") @Log(title="仓库管理",businessType=BusinessType.INSERT) @PostMapping
    public AjaxResult add(@Validated @RequestBody WmsWarehouse value){value.setCreateBy(getUsername());return toAjax(service.insertWarehouse(value));}
    @PreAuthorize("@ss.hasPermi('wms:warehouse:edit')") @Log(title="仓库管理",businessType=BusinessType.UPDATE) @PutMapping
    public AjaxResult edit(@Validated @RequestBody WmsWarehouse value){value.setUpdateBy(getUsername());return toAjax(service.updateWarehouse(value));}
    @PreAuthorize("@ss.hasPermi('wms:warehouse:remove')") @Log(title="仓库管理",businessType=BusinessType.DELETE) @DeleteMapping("/{ids}")
    public AjaxResult remove(@PathVariable Long[] ids){service.deleteWarehouseByIds(ids);return success();}
    @PreAuthorize("@ss.hasPermi('wms:warehouse:export')") @Log(title="仓库管理",businessType=BusinessType.EXPORT) @PostMapping("/export")
    public void export(HttpServletResponse response,WmsWarehouse query){List<WmsWarehouse> list=service.selectWarehouseList(query);new ExcelUtil<WmsWarehouse>(WmsWarehouse.class).exportExcel(response,list,"仓库数据");}
}
