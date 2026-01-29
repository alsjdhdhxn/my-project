package com.cost.costserver;

import lombok.extern.slf4j.Slf4j;
import org.apache.ibatis.session.SqlSessionFactory;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ConfigurableApplicationContext;

@Slf4j
@SpringBootApplication
public class CostServerApplication {

    public static void main(String[] args) {
        // Oracle JDBC 返回标准 Java 类型而非 oracle.sql.* 类型
        System.setProperty("oracle.jdbc.J2EE13Compliant", "true");
        ConfigurableApplicationContext context = SpringApplication.run(CostServerApplication.class, args);
        
        // 打印实际生效的 MyBatis log-impl 配置
        try {
            SqlSessionFactory sqlSessionFactory = context.getBean(SqlSessionFactory.class);
            Class<?> logImpl = sqlSessionFactory.getConfiguration().getLogImpl();
            log.info("[MyBatis] Effective log-impl = {}", logImpl != null ? logImpl.getName() : "null");
        } catch (Exception e) {
            log.warn("[MyBatis] Failed to get log-impl: {}", e.getMessage());
        }
    }
}
