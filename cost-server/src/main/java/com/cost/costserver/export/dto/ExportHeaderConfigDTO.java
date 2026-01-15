package com.cost.costserver.export.dto;

public record ExportHeaderConfigDTO(
    String field,
    String defaultHeader,
    String customHeader,
    Boolean visible
) {
}
