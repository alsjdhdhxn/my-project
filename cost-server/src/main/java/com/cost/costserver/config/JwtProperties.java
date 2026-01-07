package com.cost.costserver.config;

import jakarta.annotation.PostConstruct;
import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

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
    
    @PostConstruct
    public void validate() {
        if (!StringUtils.hasText(secret)) {
            throw new IllegalStateException("jwt.secret 未配置，请检查环境变量或配置文件");
        }
        if (secret.length() < 32) {
            throw new IllegalStateException("jwt.secret 长度不足 32 字符，安全性不足");
        }
    }
}
