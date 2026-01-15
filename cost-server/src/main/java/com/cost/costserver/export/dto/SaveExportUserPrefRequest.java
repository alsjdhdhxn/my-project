package com.cost.costserver.export.dto;

import lombok.Data;

@Data
public class SaveExportUserPrefRequest {
    private Boolean autoExport;
    private Boolean useUserConfig;
}
