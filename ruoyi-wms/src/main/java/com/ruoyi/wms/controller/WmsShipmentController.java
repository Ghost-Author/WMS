package com.ruoyi.wms.controller;

import java.util.List;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.common.utils.poi.ExcelUtil;
import com.ruoyi.wms.domain.WmsShipment;
import com.ruoyi.wms.service.IWmsShipmentService;

@RestController @RequestMapping("/wms/shipment")
public class WmsShipmentController extends BaseController
{
    private final IWmsShipmentService service;public WmsShipmentController(IWmsShipmentService service){this.service=service;}
    @PreAuthorize("@ss.hasPermi('wms:shipment:list')") @GetMapping("/list") public TableDataInfo list(WmsShipment q){startPage();return getDataTable(service.selectShipmentList(q));}
    @PreAuthorize("@ss.hasAnyPermi('wms:shipment:query,wms:shipment:edit')") @GetMapping("/{id}") public AjaxResult getInfo(@PathVariable Long id){return success(service.selectShipmentById(id));}
    @PreAuthorize("@ss.hasPermi('wms:shipment:add')") @Log(title="出库单",businessType=BusinessType.INSERT) @PostMapping public AjaxResult add(@Validated @RequestBody WmsShipment v){v.setCreateBy(getUsername());return toAjax(service.insertShipment(v));}
    @PreAuthorize("@ss.hasPermi('wms:shipment:edit')") @Log(title="出库单",businessType=BusinessType.UPDATE) @PutMapping public AjaxResult edit(@Validated @RequestBody WmsShipment v){v.setUpdateBy(getUsername());return toAjax(service.updateShipment(v));}
    @PreAuthorize("@ss.hasPermi('wms:shipment:remove')") @Log(title="出库单",businessType=BusinessType.DELETE) @DeleteMapping("/{ids}") public AjaxResult remove(@PathVariable Long[] ids){service.deleteShipmentByIds(ids);return success();}
    @PreAuthorize("@ss.hasPermi('wms:shipment:complete')") @Log(title="出库单完成",businessType=BusinessType.UPDATE) @PutMapping("/{id}/complete") public AjaxResult complete(@PathVariable Long id){service.completeShipment(id,getUsername());return success();}
    @PreAuthorize("@ss.hasPermi('wms:shipment:export')") @Log(title="出库单",businessType=BusinessType.EXPORT) @PostMapping("/export") public void export(HttpServletResponse r,WmsShipment q){List<WmsShipment> l=service.selectShipmentList(q);new ExcelUtil<WmsShipment>(WmsShipment.class).exportExcel(r,l,"出库单数据");}
}
