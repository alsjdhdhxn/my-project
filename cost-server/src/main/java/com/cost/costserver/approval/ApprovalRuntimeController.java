package com.cost.costserver.approval;

import com.cost.costserver.common.Result;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/approval/runtime")
@RequiredArgsConstructor
public class ApprovalRuntimeController {

    private final ApprovalRuntimeService approvalRuntimeService;

    @PostMapping("/apply")
    public Result<Map<String, Object>> apply(@RequestBody Map<String, Object> request) {
        return Result.ok(approvalRuntimeService.apply(request));
    }

    @PostMapping("/approve")
    public Result<Map<String, Object>> approve(@RequestBody Map<String, Object> request) {
        return Result.ok(approvalRuntimeService.approve(request));
    }

    @PostMapping("/reject")
    public Result<Map<String, Object>> reject(@RequestBody Map<String, Object> request) {
        return Result.ok(approvalRuntimeService.reject(request));
    }

    @GetMapping("/progress")
    public Result<Map<String, Object>> progress(
            @RequestParam String pageCode,
            @RequestParam String tableCode,
            @RequestParam Long billId) {
        return Result.ok(approvalRuntimeService.progress(pageCode, tableCode, billId));
    }
}
