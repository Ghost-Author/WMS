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
import com.yian.wms.business.domain.WmsStock;
import com.yian.wms.business.domain.WmsStockMovement;
import com.yian.wms.business.domain.dto.WmsStockAdjustRequest;
import com.yian.wms.business.domain.dto.WmsStockTransferRequest;
import com.yian.wms.business.service.IWmsStockService;

@RestController @RequestMapping("/wms/stock")
public class WmsStockController extends BaseController
{
    private final IWmsStockService service;public WmsStockController(IWmsStockService service){this.service=service;}
    @PreAuthorize("@ss.hasPermi('wms:stock:list')") @GetMapping("/list") public TableDataInfo list(WmsStock q){startPage();return getDataTable(service.selectStockList(q));}
    @PreAuthorize("@ss.hasAnyPermi('wms:stock:list,wms:dashboard:list')") @GetMapping("/lowStock") public TableDataInfo lowStock(WmsStock q){startPage();return getDataTable(service.selectLowStockList(q));}
    @PreAuthorize("@ss.hasPermi('wms:stock:list')") @GetMapping("/movement/list") public TableDataInfo movements(WmsStockMovement q){startPage();return getDataTable(service.selectMovementList(q));}
    @PreAuthorize("@ss.hasPermi('wms:stock:transfer')") @Log(title="库存调拨",businessType=BusinessType.UPDATE) @PostMapping("/transfer") public AjaxResult transfer(@Validated @RequestBody WmsStockTransferRequest request){return AjaxResult.success("库存调拨成功",service.transferStock(request,getUsername()));}
    @PreAuthorize("@ss.hasPermi('wms:stock:adjust')") @Log(title="库存盘点",businessType=BusinessType.UPDATE) @PostMapping("/adjust") public AjaxResult adjust(@Validated @RequestBody WmsStockAdjustRequest request){return AjaxResult.success("库存盘点调整成功",service.adjustStock(request,getUsername()));}
    @PreAuthorize("@ss.hasPermi('wms:stock:export')") @Log(title="库存余额",businessType=BusinessType.EXPORT) @PostMapping("/export") public void export(HttpServletResponse r,WmsStock q){List<WmsStock> l=service.selectStockList(q);new ExcelUtil<WmsStock>(WmsStock.class).exportExcel(r,l,"库存数据");}
    @PreAuthorize("@ss.hasPermi('wms:stock:export')") @Log(title="低库存预警",businessType=BusinessType.EXPORT) @PostMapping("/lowStock/export") public void exportLowStock(HttpServletResponse r,WmsStock q){List<WmsStock> l=service.selectLowStockList(q);new ExcelUtil<WmsStock>(WmsStock.class).exportExcel(r,l,"低库存预警");}
    @PreAuthorize("@ss.hasPermi('wms:stock:export')") @Log(title="库存流水",businessType=BusinessType.EXPORT) @PostMapping("/movement/export") public void exportMovements(HttpServletResponse r,WmsStockMovement q){List<WmsStockMovement> l=service.selectMovementList(q);new ExcelUtil<WmsStockMovement>(WmsStockMovement.class).exportExcel(r,l,"库存流水");}
}
