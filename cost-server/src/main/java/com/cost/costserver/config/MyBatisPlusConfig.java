package com.cost.costserver.config;

import com.baomidou.mybatisplus.annotation.DbType;
import com.baomidou.mybatisplus.autoconfigure.ConfigurationCustomizer;
import com.baomidou.mybatisplus.autoconfigure.MybatisPlusProperties;
import com.baomidou.mybatisplus.extension.plugins.MybatisPlusInterceptor;
import com.baomidou.mybatisplus.extension.plugins.inner.PaginationInnerInterceptor;
import org.springframework.core.env.Environment;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.Arrays;

@Configuration
public class MyBatisPlusConfig {

    @Bean
    public MybatisPlusInterceptor mybatisPlusInterceptor() {
        MybatisPlusInterceptor interceptor = new MybatisPlusInterceptor();
        interceptor.addInnerInterceptor(new PaginationInnerInterceptor(DbType.ORACLE));
        return interceptor;
    }

    /**
     * 强制应用 YAML 中的 log-impl 配置
     * 解决 MyBatis-Plus 自动配置时序问题
     */
    @Bean
    public ConfigurationCustomizer mybatisConfigurationCustomizer(MybatisPlusProperties properties, Environment environment) {
        return configuration -> {
            if (properties.getConfiguration() != null 
                && properties.getConfiguration().getLogImpl() != null) {
                configuration.setLogImpl(properties.getConfiguration().getLogImpl());
            }

            boolean enabledByProfile = Arrays.asList(environment.getActiveProfiles()).contains("dev");
            boolean enabledByProperty = environment.getProperty("app.sql-log.enabled", Boolean.class, false);
            configuration.addInterceptor(new SqlLogInterceptor(enabledByProfile || enabledByProperty));
        };
    }
}
