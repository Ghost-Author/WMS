package com.yian.wms.web.controller.monitor;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.alibaba.druid.support.jakarta.ResourceServlet;
import com.yian.wms.common.core.domain.AjaxResult;
import com.yian.wms.common.utils.SecurityUtils;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;

/**
 * 数据库监控会话
 */
@RestController
@RequestMapping("/monitor/druid")
public class DruidSessionController
{
    private static final int SESSION_TIMEOUT_SECONDS = 15 * 60;

    /**
     * 为已通过 WMS 权限校验的用户创建短期 Druid 会话
     */
    @PreAuthorize("@ss.hasPermi('monitor:druid:list')")
    @PostMapping("/session")
    public AjaxResult createSession(HttpServletRequest request)
    {
        HttpSession previousSession = request.getSession(false);
        if (previousSession != null)
        {
            previousSession.invalidate();
        }

        HttpSession session = request.getSession(true);
        session.setMaxInactiveInterval(SESSION_TIMEOUT_SECONDS);
        session.setAttribute(ResourceServlet.SESSION_USER_KEY, SecurityUtils.getUsername());
        return AjaxResult.success("监控会话已建立");
    }

    /**
     * 主动销毁当前监控会话
     */
    @PreAuthorize("@ss.hasPermi('monitor:druid:list')")
    @DeleteMapping("/session")
    public AjaxResult deleteSession(HttpServletRequest request)
    {
        HttpSession session = request.getSession(false);
        if (session != null)
        {
            session.invalidate();
        }
        return AjaxResult.success();
    }
}
