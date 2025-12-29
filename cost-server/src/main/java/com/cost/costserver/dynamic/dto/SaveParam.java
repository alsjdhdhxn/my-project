package com.cost.costserver.dynamic.dto;

import lombok.Data;
import java.util.List;
import java.util.Map;

/**
 * 通用保存参数 - 支持单表/主从表/主从多Tab
 */
@Data
public class SaveParam {

    /** 页面编码（用于审计日志） */
    private String pageCode;

    /** 主表数据 */
    private RecordItem master;

    /** 从表数据 Map<tableCode, List<RecordItem>> */
    private Map<String, List<RecordItem>> details;

    @Data
    public static class RecordItem {
        /** 记录ID，新增时为null */
        private Long id;

        /** 状态：added/modified/deleted/unchanged */
        private String status;

        /** 当前数据 */
        private Map<String, Object> data;

        /** 变更记录 */
        private List<FieldChange> changes;

        /** 乐观锁版本（UPDATE_TIME） */
        private String updateTime;
    }

    @Data
    public static class FieldChange {
        /** 字段名 */
        private String field;

        /** 原值 */
        private Object oldValue;

        /** 新值 */
        private Object newValue;

        /** 变更类型：user(用户修改) / cascade(级联计算) */
        private String changeType;
    }
}
