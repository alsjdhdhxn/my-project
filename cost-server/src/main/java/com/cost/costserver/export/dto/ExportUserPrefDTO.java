package com.cost.costserver.export.dto;

public record ExportUserPrefDTO(
    Boolean autoExport,
    Boolean useUserConfig
) {
}
