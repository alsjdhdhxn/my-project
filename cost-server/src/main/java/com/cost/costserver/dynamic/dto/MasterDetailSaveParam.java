package com.cost.costserver.dynamic.dto;

import lombok.Data;
import java.util.List;
import java.util.Map;

/**
 * 主从表保存参数
 */
@Data
public class MasterDetailSaveParam {
    /** 主表编码 */
    private String masterTableCode;
    /** 主表数据，包含 tempId */
    private Map<String, Object> master;
    /** 从表列表 */
    private List<DetailData> details;

    @Data
    public static class DetailData {
        /** 从表编码 */
        private String tableCode;
        /** 从表数据列表，每条包含 tempId 和 masterTempId */
        private List<Map<String, Object>> rows;
    }
}
