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
import com.yian.wms.business.domain.WmsArea;
import com.yian.wms.business.service.IWmsAreaService;

@RestController @RequestMapping("/wms/area")
public class WmsAreaController extends BaseController
{
    private final IWmsAreaService service;public WmsAreaController(IWmsAreaService service){this.service=service;}
    @PreAuthorize("@ss.hasAnyPermi('wms:area:list,wms:location:list')") @GetMapping("/list") public TableDataInfo list(WmsArea q){startPage();return getDataTable(service.selectAreaList(q));}
    @PreAuthorize("@ss.hasAnyPermi('wms:area:query,wms:area:edit')") @GetMapping("/{id}") public AjaxResult getInfo(@PathVariable Long id){return success(service.selectAreaById(id));}
    @PreAuthorize("@ss.hasPermi('wms:area:add')") @Log(title="库区管理",businessType=BusinessType.INSERT) @PostMapping public AjaxResult add(@Validated @RequestBody WmsArea v){v.setCreateBy(getUsername());return toAjax(service.insertArea(v));}
    @PreAuthorize("@ss.hasPermi('wms:area:edit')") @Log(title="库区管理",businessType=BusinessType.UPDATE) @PutMapping public AjaxResult edit(@Validated @RequestBody WmsArea v){v.setUpdateBy(getUsername());return toAjax(service.updateArea(v));}
    @PreAuthorize("@ss.hasPermi('wms:area:remove')") @Log(title="库区管理",businessType=BusinessType.DELETE) @DeleteMapping("/{ids}") public AjaxResult remove(@PathVariable Long[] ids){service.deleteAreaByIds(ids);return success();}
    @PreAuthorize("@ss.hasPermi('wms:area:export')") @Log(title="库区管理",businessType=BusinessType.EXPORT) @PostMapping("/export") public void export(HttpServletResponse r,WmsArea q){List<WmsArea> l=service.selectAreaList(q);new ExcelUtil<WmsArea>(WmsArea.class).exportExcel(r,l,"库区数据");}
}
