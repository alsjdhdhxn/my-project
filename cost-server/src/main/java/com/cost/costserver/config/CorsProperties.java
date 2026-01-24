package com.cost.costserver.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

import java.util.List;

@Data
@Component
@ConfigurationProperties(prefix = "cors")
public class CorsProperties {
    
    /**
     * 允许的跨域来源列表
     * 开发环境默认允许所有来源，生产环境应配置具体域名
     */
    private List<String> allowedOrigins = List.of("*");
    
    /**
     * 是否允许携带凭证（Cookie），默认 false
     * 注意：allowCredentials=true 时不能使用 allowedOrigins=*
     */
    private boolean allowCredentials = false;
}
