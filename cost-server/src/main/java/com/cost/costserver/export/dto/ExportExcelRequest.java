package com.cost.costserver.export.dto;

import lombok.Data;

import java.util.List;

@Data
public class ExportExcelRequest {
    private String mode;
    private Boolean useUserConfig;
    private List<Long> masterIds;
    private String masterGridKey;
}
