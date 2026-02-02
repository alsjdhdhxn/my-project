package com.cost.costserver.auth.dto;

import lombok.Data;
import java.util.List;

/**
 * 页面表格列信息VO（用于列权限配置）
 * 包含表格标识、表格名称和列列表
 */
@Data
public class PageTableColumnsVO {
    private String tableKey;      // 组件key，如 masterGrid, material, package
    private String tableName;     // 表格显示名称
    private List<PageColumnVO> columns;
}
