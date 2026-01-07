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
     */
    private List<String> allowedOrigins = List.of("http://localhost:9527");
    
    /**
     * 是否允许携带凭证（Cookie），默认 true（开发环境），生产环境建议 false
     */
    private boolean allowCredentials = true;
}
