package com.cost.costserver.config;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class AdminPasswordInitializer implements CommandLineRunner {

    private final JdbcTemplate jdbcTemplate;
    private final PasswordEncoder passwordEncoder;

    @Override
    public void run(String... args) {
        String encodedPassword = passwordEncoder.encode("admin123..");
        int rows = jdbcTemplate.update(
            "UPDATE T_COST_USER SET PASSWORD = ? WHERE USERNAME = 'admin' AND DELETED = 0",
            encodedPassword
        );
        if (rows > 0) {
            log.info("admin 用户密码已重置为 admin123..");
        }
    }
}
