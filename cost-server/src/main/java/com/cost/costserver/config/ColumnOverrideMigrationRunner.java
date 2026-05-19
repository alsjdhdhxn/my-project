package com.cost.costserver.config;

import com.cost.costserver.metadata.service.ColumnOverrideMigrationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Map;

/**
 * 应用启动时自动执行 COLUMN_OVERRIDE → COLUMN_METADATA 迁移。
 * 幂等：已迁移的数据不会重复处理（按 MIGRATED 字段判断）。
 *
 * !! 迁移已于 2026-05-19 执行完成，本类已禁用。后续可删除。
 */
// @Component  // 迁移已完成，注释掉避免重复执行
@RequiredArgsConstructor
@Slf4j
public class ColumnOverrideMigrationRunner implements ApplicationRunner {

    private final ColumnOverrideMigrationService migrationService;

    @Override
    public void run(ApplicationArguments args) {
        log.info("========== COLUMN_OVERRIDE 迁移开始 ==========");

        try {
            // 1. 拆分共享表
            log.info("[迁移] 步骤1：拆分共享表...");
            Map<String, Object> splitResult = migrationService.splitSharedTables();
            log.info("[迁移] 拆分结果: splitCount={}, copiedColumns={}",
                    splitResult.get("splitCount"), splitResult.get("copiedColumns"));

            // 2. 验证
            log.info("[迁移] 步骤2：验证无共享表...");
            Map<String, List<String>> shared = migrationService.verify();
            if (!shared.isEmpty()) {
                log.error("[迁移] 仍有共享表未拆分: {}", shared);
                log.error("========== 迁移中断，请手动检查 ==========");
                return;
            }
            log.info("[迁移] 验证通过，无共享表残留");

            // 3. 迁移 COLUMN_OVERRIDE
            log.info("[迁移] 步骤3：迁移 COLUMN_OVERRIDE...");
            Map<String, Object> migrateResult = migrationService.migrateColumnOverrides();
            log.info("[迁移] 迁移结果: rules={}, columns={}, errors={}",
                    migrateResult.get("migratedRules"), migrateResult.get("migratedColumns"),
                    ((List<?>) migrateResult.get("errors")).size());
            List<?> errors = (List<?>) migrateResult.get("errors");
            if (!errors.isEmpty()) {
                log.warn("[迁移] 部分规则迁移失败: {}", errors);
            }

            // 4. 补默认值
            log.info("[迁移] 步骤4：补默认值...");
            int marked = migrationService.markUnmigratedTables();
            log.info("[迁移] 已补默认值并标记: {} 列", marked);

            log.info("========== COLUMN_OVERRIDE 迁移完成 ==========");
        } catch (Exception e) {
            log.error("========== 迁移执行异常 ==========", e);
        }
    }
}
