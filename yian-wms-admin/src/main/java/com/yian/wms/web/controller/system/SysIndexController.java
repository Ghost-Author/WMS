package com.yian.wms.web.controller.system;

import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.yian.wms.common.config.YianWmsConfig;
import com.yian.wms.common.core.domain.AjaxResult;
import com.yian.wms.common.core.domain.entity.SysUser;
import com.yian.wms.common.utils.SecurityUtils;
import com.yian.wms.common.utils.StringUtils;
import com.yian.wms.system.service.ISysUserService;

/**
 * 首页
 *
 */
@RestController
public class SysIndexController
{
    /** 系统基础配置 */
    @Autowired
    private YianWmsConfig yianWmsConfig;

    @Autowired
    private ISysUserService userService;

    /**
     * 访问首页，提示语
     */
    @RequestMapping("/")
    public String index()
    {
        return StringUtils.format("{} 服务运行正常，当前版本：v{}。", yianWmsConfig.getName(), yianWmsConfig.getVersion());
    }

    /**
     * 解锁屏幕
     */
    @PostMapping("/unlockscreen")
    public AjaxResult unlockScreen(@RequestBody Map<String, String> body)
    {
        String password = body.get("password");
        if (StringUtils.isEmpty(password))
        {
            return AjaxResult.error("密码不能为空");
        }
        String username = SecurityUtils.getUsername();
        SysUser user = userService.selectUserByUserName(username);
        if (user == null)
        {
            return AjaxResult.error("服务器超时，请重新登录");
        }
        if (!SecurityUtils.matchesPassword(password, user.getPassword()))
        {
            return AjaxResult.error("密码错误，请重新输入");
        }

        return AjaxResult.success("解锁成功");
    }
}
