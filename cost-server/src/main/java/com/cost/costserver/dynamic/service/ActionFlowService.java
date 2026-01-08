package com.cost.costserver.dynamic.service;

import cn.hutool.core.util.StrUtil;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.dynamic.action.ActionExecutionReport;
import com.cost.costserver.dynamic.dto.ActionExecuteRequest;
import com.cost.costserver.dynamic.validation.ValidationReport;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class ActionFlowService {

    private final ValidationService validationService;
    private final ActionService actionService;

    @Transactional(rollbackFor = Exception.class)
    public ActionExecutionReport execute(String tableCode, ActionExecuteRequest request) {
        if (request == null) {
            throw new BusinessException(400, "执行请求不能为空");
        }
        List<String> actionCodes = request.getActionCodes();
        String group = request.getGroup();
        if ((actionCodes == null || actionCodes.isEmpty()) && StrUtil.isBlank(group)) {
            throw new BusinessException(400, "执行器分组或编码不能为空");
        }

        Map<String, Object> data = request.getData();
        if (data == null) {
            data = new HashMap<>();
        }

        boolean shouldValidate = Boolean.TRUE.equals(request.getValidate()) || StrUtil.isNotBlank(request.getValidateGroup());
        ValidationReport validationReport = null;
        if (shouldValidate) {
            validationReport = validationService.validate(tableCode, request.getValidateGroup(), data);
            if (!validationReport.isPassed()) {
                throw new BusinessException(400, validationReport.getMessage());
            }
        }

        return actionService.execute(tableCode, group, actionCodes, data, validationReport);
    }
}
