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
import com.yian.wms.business.domain.WmsLocation;
import com.yian.wms.business.service.IWmsLocationService;

@RestController @RequestMapping("/wms/location")
public class WmsLocationController extends BaseController
{
    private final IWmsLocationService service;public WmsLocationController(IWmsLocationService service){this.service=service;}
    @PreAuthorize("@ss.hasPermi('wms:location:list')") @GetMapping("/list") public TableDataInfo list(WmsLocation q){startPage();return getDataTable(service.selectLocationList(q));}
    @PreAuthorize("@ss.hasAnyPermi('wms:location:list,wms:stock:list,wms:receipt:list,wms:shipment:list')") @GetMapping("/options") public AjaxResult options(@RequestParam(required=false) Long warehouseId){return success(service.selectEnabledOptions(warehouseId));}
    @PreAuthorize("@ss.hasAnyPermi('wms:location:query,wms:location:edit')") @GetMapping("/{id}") public AjaxResult getInfo(@PathVariable Long id){return success(service.selectLocationById(id));}
    @PreAuthorize("@ss.hasPermi('wms:location:add')") @Log(title="库位管理",businessType=BusinessType.INSERT) @PostMapping public AjaxResult add(@Validated @RequestBody WmsLocation v){v.setCreateBy(getUsername());return toAjax(service.insertLocation(v));}
    @PreAuthorize("@ss.hasPermi('wms:location:edit')") @Log(title="库位管理",businessType=BusinessType.UPDATE) @PutMapping public AjaxResult edit(@Validated @RequestBody WmsLocation v){v.setUpdateBy(getUsername());return toAjax(service.updateLocation(v));}
    @PreAuthorize("@ss.hasPermi('wms:location:remove')") @Log(title="库位管理",businessType=BusinessType.DELETE) @DeleteMapping("/{ids}") public AjaxResult remove(@PathVariable Long[] ids){service.deleteLocationByIds(ids);return success();}
    @PreAuthorize("@ss.hasPermi('wms:location:export')") @Log(title="库位管理",businessType=BusinessType.EXPORT) @PostMapping("/export") public void export(HttpServletResponse r,WmsLocation q){List<WmsLocation> l=service.selectLocationList(q);new ExcelUtil<WmsLocation>(WmsLocation.class).exportExcel(r,l,"库位数据");}
}
