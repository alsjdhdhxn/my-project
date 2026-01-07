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
}
