package com.yian.wms;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.jdbc.autoconfigure.DataSourceAutoConfiguration;

/**
 * 启动程序
 *
 */
@SpringBootApplication(exclude = { DataSourceAutoConfiguration.class })
public class YianWmsApplication
{
    public static void main(String[] args)
    {
        // System.setProperty("spring.devtools.restart.enabled", "false");
        SpringApplication.run(YianWmsApplication.class, args);
        System.out.println("以安WMS 启动成功");
    }
}
