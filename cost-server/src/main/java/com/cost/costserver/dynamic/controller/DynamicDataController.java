package com.cost.costserver.dynamic.controller;

import com.cost.costserver.common.PageResult;
import com.cost.costserver.common.Result;
import com.cost.costserver.dynamic.dto.QueryParam;
import com.cost.costserver.dynamic.service.DynamicDataService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@Tag(name = "动态数据接口")
@RestController
@RequestMapping("/api/data")
@RequiredArgsConstructor
public class DynamicDataController {

    private final DynamicDataService dynamicDataService;

    @Operation(summary = "分页查询")
    @GetMapping("/{tableCode}")
    public Result<PageResult<Map<String, Object>>> query(
            @PathVariable String tableCode,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @RequestParam(required = false) String sortField,
            @RequestParam(required = false) String sortOrder) {

        QueryParam param = new QueryParam();
        param.setPage(page);
        param.setPageSize(pageSize);
        param.setSortField(sortField);
        param.setSortOrder(sortOrder);

        return Result.ok(dynamicDataService.query(tableCode, param));
    }

    @Operation(summary = "高级查询")
    @PostMapping("/{tableCode}/search")
    public Result<PageResult<Map<String, Object>>> search(
            @PathVariable String tableCode,
            @RequestBody QueryParam param) {
        return Result.ok(dynamicDataService.query(tableCode, param));
    }

    @Operation(summary = "查询单条")
    @GetMapping("/{tableCode}/{id}")
    public Result<Map<String, Object>> getById(
            @PathVariable String tableCode,
            @PathVariable Long id) {
        return Result.ok(dynamicDataService.getById(tableCode, id));
    }

    @Operation(summary = "新增")
    @PostMapping("/{tableCode}")
    public Result<Long> insert(
            @PathVariable String tableCode,
            @RequestBody Map<String, Object> data) {
        return Result.ok(dynamicDataService.insert(tableCode, data));
    }

    @Operation(summary = "更新")
    @PutMapping("/{tableCode}/{id}")
    public Result<Void> update(
            @PathVariable String tableCode,
            @PathVariable Long id,
            @RequestBody Map<String, Object> data) {
        dynamicDataService.update(tableCode, id, data);
        return Result.ok();
    }

    @Operation(summary = "删除")
    @DeleteMapping("/{tableCode}/{id}")
    public Result<Void> delete(
            @PathVariable String tableCode,
            @PathVariable Long id) {
        dynamicDataService.delete(tableCode, id);
        return Result.ok();
    }
}
