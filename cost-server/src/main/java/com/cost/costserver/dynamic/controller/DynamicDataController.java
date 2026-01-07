package com.cost.costserver.dynamic.controller;

import com.cost.costserver.common.PageResult;
import com.cost.costserver.common.Result;
import com.cost.costserver.dynamic.dto.MasterDetailSaveParam;
import com.cost.costserver.dynamic.dto.QueryParam;
import com.cost.costserver.dynamic.dto.SaveParam;
import com.cost.costserver.dynamic.service.DynamicDataService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

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
            @RequestParam(required = false) String sortOrder,
            @RequestParam(required = false) String pageCode,
            @RequestParam(required = false) Boolean lookup,
            @RequestParam Map<String, String> allParams) {

        QueryParam param = new QueryParam();
        param.setPage(page);
        param.setPageSize(pageSize);
        param.setSortField(sortField);
        param.setSortOrder(sortOrder);
        param.setPageCode(pageCode);
        param.setLookup(lookup);

        // 将其他参数转为查询条件（排除分页、排序、权限参数）
        List<QueryParam.QueryCondition> conditions = new ArrayList<>();
        for (Map.Entry<String, String> entry : allParams.entrySet()) {
            String key = entry.getKey();
            if (Set.of("page", "pageSize", "sortField", "sortOrder", "pageCode", "lookup").contains(key)) {
                continue;
            }
            if (entry.getValue() != null && !entry.getValue().isEmpty()) {
                // 支持大写下划线格式，自动转为小驼峰
                String fieldName = key.contains("_") ? underscoreToCamel(key) : key;
                conditions.add(new QueryParam.QueryCondition(fieldName, "eq", entry.getValue(), null));
            }
        }
        param.setConditions(conditions);

        return Result.ok(dynamicDataService.query(tableCode, param));
    }

    @Operation(summary = "高级查询")
    @PostMapping("/{tableCode}/search")
    public Result<PageResult<Map<String, Object>>> search(
            @PathVariable String tableCode,
            @RequestBody QueryParam param) {
        return Result.ok(dynamicDataService.query(tableCode, param));
    }

    @Operation(summary = "查询全部（不分页）")
    @GetMapping("/{tableCode}/all")
    public Result<java.util.List<Map<String, Object>>> queryAll(
            @PathVariable String tableCode,
            @RequestParam(required = false) String sortField,
            @RequestParam(required = false) String sortOrder) {
        return Result.ok(dynamicDataService.queryAll(tableCode, sortField, sortOrder));
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

    @Operation(summary = "主从表保存")
    @PostMapping("/master-detail")
    public Result<Long> saveMasterDetail(@RequestBody MasterDetailSaveParam param) {
        return Result.ok(dynamicDataService.saveMasterDetail(param));
    }

    @Operation(summary = "通用保存（支持单表/主从表/主从多Tab，含变更追踪和乐观锁）")
    @PostMapping("/save")
    public Result<Long> save(@RequestBody SaveParam param) {
        return Result.ok(dynamicDataService.save(param));
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

    private String underscoreToCamel(String name) {
        StringBuilder sb = new StringBuilder();
        boolean upper = false;
        for (char c : name.toLowerCase().toCharArray()) {
            if (c == '_') {
                upper = true;
            } else {
                sb.append(upper ? Character.toUpperCase(c) : c);
                upper = false;
            }
        }
        return sb.toString();
    }
}
