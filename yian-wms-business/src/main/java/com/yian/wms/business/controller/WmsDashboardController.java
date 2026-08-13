package com.yian.wms.business.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.yian.wms.common.core.controller.BaseController;
import com.yian.wms.common.core.domain.AjaxResult;
import com.yian.wms.business.service.IWmsDashboardService;

@RestController @RequestMapping("/wms/dashboard")
public class WmsDashboardController extends BaseController
{
    private final IWmsDashboardService service;public WmsDashboardController(IWmsDashboardService service){this.service=service;}
    @PreAuthorize("@ss.hasPermi('wms:dashboard:list')") @GetMapping("/summary") public AjaxResult summary(){return success(service.selectSummary());}
    @PreAuthorize("@ss.hasPermi('wms:dashboard:list')") @GetMapping("/recentMovements") public AjaxResult recent(){return success(service.selectRecentMovements());}
    @PreAuthorize("@ss.hasPermi('wms:dashboard:list')") @GetMapping("/operationTrend") public AjaxResult operationTrend(){return success(service.selectOperationTrend());}
    @PreAuthorize("@ss.hasPermi('wms:dashboard:list')") @GetMapping("/warehouseStockDistribution") public AjaxResult warehouseStockDistribution(){return success(service.selectWarehouseStockDistribution());}
}
