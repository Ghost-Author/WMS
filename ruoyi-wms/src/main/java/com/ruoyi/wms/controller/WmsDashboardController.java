package com.ruoyi.wms.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.wms.service.IWmsDashboardService;

@RestController @RequestMapping("/wms/dashboard")
public class WmsDashboardController extends BaseController
{
    private final IWmsDashboardService service;public WmsDashboardController(IWmsDashboardService service){this.service=service;}
    @PreAuthorize("@ss.hasPermi('wms:dashboard:list')") @GetMapping("/summary") public AjaxResult summary(){return success(service.selectSummary());}
    @PreAuthorize("@ss.hasPermi('wms:dashboard:list')") @GetMapping("/recentMovements") public AjaxResult recent(){return success(service.selectRecentMovements());}
}
