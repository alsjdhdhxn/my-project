package com.cost.costserver.dynamic.controller;

import com.cost.costserver.common.PageResult;
import com.cost.costserver.common.Result;
import com.cost.costserver.dynamic.service.DynamicDataService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@Tag(name = "Lookup 数据接口")
@RestController
@RequestMapping("/api/lookup")
@RequiredArgsConstructor
public class LookupDataController {

    private final DynamicDataService dynamicDataService;

    @Operation(summary = "Lookup 查询（不依赖元数据）")
    @GetMapping("/{lookupCode}/data")
    public Result<PageResult<Map<String, Object>>> queryLookupData(
            @PathVariable String lookupCode,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(required = false) Integer pageSize,
            @RequestParam(required = false) String filterColumn,
            @RequestParam(required = false) String filterValue,
            @RequestParam(required = false) String keyword) {
        return Result.ok(dynamicDataService.queryLookupData(lookupCode, page, pageSize, filterColumn, filterValue, keyword));
    }
}
