package com.cost.costserver.auth.dto;

import lombok.Data;

@Data
public class SearchConditionDTO {
    private String field;
    private String operator;
    private String value;
}
