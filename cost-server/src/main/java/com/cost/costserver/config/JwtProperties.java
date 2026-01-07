package com.cost.costserver.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Data
@Component
@ConfigurationProperties(prefix = "jwt")
public class JwtProperties {
    
    /**
     * JWT 签名密钥
     */
    private String secret;
    
    /**
     * AccessToken 过期时间（毫秒），默认 2 小时
     */
    private long accessTokenExpire = 7200000;
    
    /**
     * RefreshToken 过期时间（毫秒），默认 7 天
     */
    private long refreshTokenExpire = 604800000;
}
