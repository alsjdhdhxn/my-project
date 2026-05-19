package com.cost.costserver.config;

import com.cost.costserver.metadata.service.ColumnOverrideMigrationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

/**
 * 迁移已完成，本类已禁用。
 */
// @Component
@RequiredArgsConstructor
@Slf4j
public class ColumnOverrideMigrationRunner implements ApplicationRunner {

    private final ColumnOverrideMigrationService migrationService;

    @Override
    public void run(ApplicationArguments args) {
        log.info("========== 多选值默认值迁移开始 ==========");
        try {
            int count = migrationService.migrateMultiDefaultToEditorParams();
            log.info("[迁移] 多选值迁移完成: {} 列已处理", count);
            log.info("========== 多选值默认值迁移完成 ==========");
        } catch (Exception e) {
            log.error("========== 迁移执行异常 ==========", e);
        }
    }
}
