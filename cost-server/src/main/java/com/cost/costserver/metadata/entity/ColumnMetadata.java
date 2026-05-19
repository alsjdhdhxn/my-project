package com.cost.costserver.metadata.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("T_COST_COLUMN_METADATA")
public class ColumnMetadata {

    @TableId(type = IdType.INPUT)
    private Long id;

    private Long tableMetadataId;
    private String columnName;
    private String queryColumn;
    private String targetColumn;
    private String headerText;
    private String dataType;
    private Integer displayOrder;
    private Integer sortable;
    private Integer filterable;
    private String dictType;
    
    /** 是否虚拟列：0-物理列 1-虚拟列（不存不取，只有公式） */
    private Integer isVirtual;

    /** 是否显示：1=是 0=否（迁移前为null） */
    private Integer visible;
    /** 是否可编辑：1=是 0=否（迁移前为null） */
    private Integer editable;
    /** 是否必填：1=是 0=否 */
    private Integer required;
    /** 是否可搜索：1=是 0=否 */
    private Integer searchable;
    /** 列宽(px) */
    private Integer width;
    /** 固定列方向：left/right */
    private String pinned;
    /** 编辑器类型 */
    private String cellEditor;
    /** 默认值 */
    private String defaultValue;
    /** 扩展配置JSON */
    private String rulesConfig;
    /** 迁移状态：0=未迁移 1=已迁移 */
    private Integer migrated;

    @TableLogic
    private Integer deleted;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createTime;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updateTime;

    @TableField(fill = FieldFill.INSERT)
    private String createBy;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private String updateBy;
}
