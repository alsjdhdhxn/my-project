package com.cost.costserver.export.dto;

public record ExportHeaderItemRequest(
    String field,
    String header,
    Boolean visible
) {
}
