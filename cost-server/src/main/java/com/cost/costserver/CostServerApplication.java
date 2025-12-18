package com.cost.costserver;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class CostServerApplication {

    public static void main(String[] args) {
        // Oracle JDBC 返回标准 Java 类型而非 oracle.sql.* 类型
        System.setProperty("oracle.jdbc.J2EE13Compliant", "true");
        SpringApplication.run(CostServerApplication.class, args);
    }
}
