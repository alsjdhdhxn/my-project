package com.cost.costserver.export.dto;

import lombok.Data;

import java.util.List;

@Data
public class SaveExportHeaderConfigRequest {
    private List<ExportHeaderItemRequest> headers;
}
