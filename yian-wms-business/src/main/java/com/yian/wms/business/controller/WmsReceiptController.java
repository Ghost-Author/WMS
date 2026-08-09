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
import com.yian.wms.business.domain.WmsReceipt;
import com.yian.wms.business.service.IWmsReceiptService;

@RestController @RequestMapping("/wms/receipt")
public class WmsReceiptController extends BaseController
{
    private final IWmsReceiptService service;public WmsReceiptController(IWmsReceiptService service){this.service=service;}
    @PreAuthorize("@ss.hasPermi('wms:receipt:list')") @GetMapping("/list") public TableDataInfo list(WmsReceipt q){startPage();return getDataTable(service.selectReceiptList(q));}
    @PreAuthorize("@ss.hasAnyPermi('wms:receipt:query,wms:receipt:edit')") @GetMapping("/{id}") public AjaxResult getInfo(@PathVariable Long id){return success(service.selectReceiptById(id));}
    @PreAuthorize("@ss.hasPermi('wms:receipt:add')") @Log(title="入库单",businessType=BusinessType.INSERT) @PostMapping public AjaxResult add(@Validated @RequestBody WmsReceipt v){v.setCreateBy(getUsername());return toAjax(service.insertReceipt(v));}
    @PreAuthorize("@ss.hasPermi('wms:receipt:edit')") @Log(title="入库单",businessType=BusinessType.UPDATE) @PutMapping public AjaxResult edit(@Validated @RequestBody WmsReceipt v){v.setUpdateBy(getUsername());return toAjax(service.updateReceipt(v));}
    @PreAuthorize("@ss.hasPermi('wms:receipt:remove')") @Log(title="入库单",businessType=BusinessType.DELETE) @DeleteMapping("/{ids}") public AjaxResult remove(@PathVariable Long[] ids){service.deleteReceiptByIds(ids);return success();}
    @PreAuthorize("@ss.hasPermi('wms:receipt:complete')") @Log(title="入库单完成",businessType=BusinessType.UPDATE) @PutMapping("/{id}/complete") public AjaxResult complete(@PathVariable Long id){service.completeReceipt(id,getUsername());return success();}
    @PreAuthorize("@ss.hasPermi('wms:receipt:export')") @Log(title="入库单",businessType=BusinessType.EXPORT) @PostMapping("/export") public void export(HttpServletResponse r,WmsReceipt q){List<WmsReceipt> l=service.selectReceiptList(q);new ExcelUtil<WmsReceipt>(WmsReceipt.class).exportExcel(r,l,"入库单数据");}
}
