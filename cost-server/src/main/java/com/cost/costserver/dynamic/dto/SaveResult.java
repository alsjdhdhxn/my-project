package com.cost.costserver.dynamic.dto;

import lombok.Data;
import java.util.List;
import java.util.Map;

@Data
public class SaveResult {
    private Long masterId;
    private Map<Long, Long> idMapping;
    /** 更新后的主表行数据 */
    private Map<String, Object> masterRow;
    /** 更新后的从表行数据，按 tableCode 分组 */
    private Map<String, List<Map<String, Object>>> detailRows;

    public SaveResult(Long masterId, Map<Long, Long> idMapping) {
        this.masterId = masterId;
        this.idMapping = idMapping;
    }
}
