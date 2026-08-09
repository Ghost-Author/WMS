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
import com.yian.wms.business.domain.WmsItem;
import com.yian.wms.business.service.IWmsItemService;

@RestController @RequestMapping("/wms/item")
public class WmsItemController extends BaseController
{
    private final IWmsItemService service;public WmsItemController(IWmsItemService service){this.service=service;}
    @PreAuthorize("@ss.hasPermi('wms:item:list')") @GetMapping("/list") public TableDataInfo list(WmsItem q){startPage();return getDataTable(service.selectItemList(q));}
    @PreAuthorize("@ss.hasAnyPermi('wms:item:list,wms:stock:list,wms:receipt:list,wms:shipment:list')") @GetMapping("/options") public AjaxResult options(){return success(service.selectEnabledOptions());}
    @PreAuthorize("@ss.hasAnyPermi('wms:item:query,wms:item:edit')") @GetMapping("/{id}") public AjaxResult getInfo(@PathVariable Long id){return success(service.selectItemById(id));}
    @PreAuthorize("@ss.hasPermi('wms:item:add')") @Log(title="物料管理",businessType=BusinessType.INSERT) @PostMapping public AjaxResult add(@Validated @RequestBody WmsItem v){v.setCreateBy(getUsername());return toAjax(service.insertItem(v));}
    @PreAuthorize("@ss.hasPermi('wms:item:edit')") @Log(title="物料管理",businessType=BusinessType.UPDATE) @PutMapping public AjaxResult edit(@Validated @RequestBody WmsItem v){v.setUpdateBy(getUsername());return toAjax(service.updateItem(v));}
    @PreAuthorize("@ss.hasPermi('wms:item:remove')") @Log(title="物料管理",businessType=BusinessType.DELETE) @DeleteMapping("/{ids}") public AjaxResult remove(@PathVariable Long[] ids){service.deleteItemByIds(ids);return success();}
    @PreAuthorize("@ss.hasPermi('wms:item:export')") @Log(title="物料管理",businessType=BusinessType.EXPORT) @PostMapping("/export") public void export(HttpServletResponse r,WmsItem q){List<WmsItem> l=service.selectItemList(q);new ExcelUtil<WmsItem>(WmsItem.class).exportExcel(r,l,"物料数据");}
}
