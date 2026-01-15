package com.cost.costserver.dynamic.dto;

import lombok.Data;
import java.util.Map;

@Data
public class SaveResult {
    private Long masterId;
    private Map<Long, Long> idMapping;

    public SaveResult(Long masterId, Map<Long, Long> idMapping) {
        this.masterId = masterId;
        this.idMapping = idMapping;
    }
}
