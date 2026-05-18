package com.cost.costserver.metadata.entity;

import lombok.Data;
import java.util.List;

@Data
public class WizardTable {

    /** 查询视图名 */
    private String queryView;

    /** 目标表名 */
    private String targetTable;

    /** 表代码 (PascalCase) */
    private String tableCode;

    /** 表中文名 */
    private String tableName;

    /** 主键列名（从数据库约束获取） */
    private String pkColumn;

    /** 序列名 = "SEQ_" + targetTable */
    private String sequenceName;

    /** 从表关联字段（仅从表） */
    private String parentFkColumn;

    /** 列配置 */
    private List<WizardColumn> columns;
}
