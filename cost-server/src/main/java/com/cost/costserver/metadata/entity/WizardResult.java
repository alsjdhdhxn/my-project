package com.cost.costserver.metadata.entity;

import lombok.Data;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class WizardResult {

    /** 生成的页面编码 */
    private String pageCode;

    /** 创建的实体总数 */
    private int createdCount;
}
