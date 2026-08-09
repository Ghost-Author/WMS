package com.yian.wms.business.controller;

import java.util.List;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.yian.wms.common.annotation.Log;
import com.yian.wms.common.core.controller.BaseController;
import com.yian.wms.common.core.page.TableDataInfo;
import com.yian.wms.common.enums.BusinessType;
import com.yian.wms.common.utils.poi.ExcelUtil;
import com.yian.wms.business.domain.WmsStock;
import com.yian.wms.business.domain.WmsStockMovement;
import com.yian.wms.business.service.IWmsStockService;

@RestController @RequestMapping("/wms/stock")
public class WmsStockController extends BaseController
{
    private final IWmsStockService service;public WmsStockController(IWmsStockService service){this.service=service;}
    @PreAuthorize("@ss.hasPermi('wms:stock:list')") @GetMapping("/list") public TableDataInfo list(WmsStock q){startPage();return getDataTable(service.selectStockList(q));}
    @PreAuthorize("@ss.hasAnyPermi('wms:stock:list,wms:dashboard:list')") @GetMapping("/lowStock") public TableDataInfo lowStock(WmsStock q){startPage();return getDataTable(service.selectLowStockList(q));}
    @PreAuthorize("@ss.hasPermi('wms:stock:list')") @GetMapping("/movement/list") public TableDataInfo movements(WmsStockMovement q){startPage();return getDataTable(service.selectMovementList(q));}
    @PreAuthorize("@ss.hasPermi('wms:stock:export')") @Log(title="库存余额",businessType=BusinessType.EXPORT) @PostMapping("/export") public void export(HttpServletResponse r,WmsStock q){List<WmsStock> l=service.selectStockList(q);new ExcelUtil<WmsStock>(WmsStock.class).exportExcel(r,l,"库存数据");}
    @PreAuthorize("@ss.hasPermi('wms:stock:export')") @Log(title="库存流水",businessType=BusinessType.EXPORT) @PostMapping("/movement/export") public void exportMovements(HttpServletResponse r,WmsStockMovement q){List<WmsStockMovement> l=service.selectMovementList(q);new ExcelUtil<WmsStockMovement>(WmsStockMovement.class).exportExcel(r,l,"库存流水");}
}
