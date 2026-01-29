package com.cost.costserver.config;

import com.baomidou.mybatisplus.annotation.DbType;
import com.baomidou.mybatisplus.autoconfigure.ConfigurationCustomizer;
import com.baomidou.mybatisplus.autoconfigure.MybatisPlusProperties;
import com.baomidou.mybatisplus.extension.plugins.MybatisPlusInterceptor;
import com.baomidou.mybatisplus.extension.plugins.inner.PaginationInnerInterceptor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

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
    public ConfigurationCustomizer mybatisConfigurationCustomizer(MybatisPlusProperties properties) {
        return configuration -> {
            if (properties.getConfiguration() != null 
                && properties.getConfiguration().getLogImpl() != null) {
                configuration.setLogImpl(properties.getConfiguration().getLogImpl());
            }
        };
    }

    /**
     * SQL 日志拦截器 - 仅开发环境启用
     */
    @Bean
    @Profile("dev")
    public SqlLogInterceptor sqlLogInterceptor() {
        return new SqlLogInterceptor();
    }
}
