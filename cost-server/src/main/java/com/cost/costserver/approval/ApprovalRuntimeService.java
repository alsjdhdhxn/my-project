package com.cost.costserver.approval;

import cn.hutool.core.util.StrUtil;
import com.cost.costserver.common.BusinessException;
import com.cost.costserver.common.SecurityUtils;
import com.cost.costserver.auth.dto.PagePermission;
import com.cost.costserver.auth.service.PermissionService;
import com.cost.costserver.dynamic.mapper.DynamicMapper;
import com.cost.costserver.metadata.dto.TableMetadataDTO;
import com.cost.costserver.metadata.service.MetadataService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.CallableStatement;
import java.sql.Clob;
import java.sql.Connection;
import java.sql.Types;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class ApprovalRuntimeService {

    private final JdbcTemplate jdbcTemplate;
    private final DynamicMapper dynamicMapper;
    private final PermissionService permissionService;
    private final MetadataService metadataService;
    private final ObjectMapper objectMapper;

    @Transactional
    public Map<String, Object> apply(Map<String, Object> request) {
        Long currentUserId = currentUserId();
        String pageCode = requiredText(request, "pageCode");
        requireButton(pageCode, "approval.apply");
        String tableCode = requiredText(request, "tableCode");
        Long billId = requiredLong(request, "billId");
        requireApplicantForConfiguredFlow(pageCode, tableCode, billId, currentUserId);

        return jdbcTemplate.execute((Connection connection) -> {
            CallableStatement statement = connection.prepareCall("{call PKG_WF_APPROVAL.APPLY_APPROVAL(?,?,?,?,?,?,?,?,?,?,?)}");
            statement.setString(1, pageCode);
            statement.setString(2, text(request.get("pageName")));
            statement.setString(3, tableCode);
            statement.setLong(4, billId);
            statement.setString(5, text(request.get("billNo")));
            statement.setString(6, text(request.get("billTitle")));
            statement.setLong(7, currentUserId);
            statement.setString(8, text(request.get("conditionJson")));
            statement.registerOutParameter(9, Types.NUMERIC);
            statement.registerOutParameter(10, Types.VARCHAR);
            statement.registerOutParameter(11, Types.VARCHAR);
            return statement;
        }, (CallableStatement statement) -> {
            statement.execute();
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("approvalId", statement.getObject(9));
            result.put("status", statement.getString(10));
            result.put("message", statement.getString(11));
            return result;
        });
    }

    @Transactional
    public Map<String, Object> approve(Map<String, Object> request) {
        String pageCode = requiredText(request, "pageCode");
        requireButton(pageCode, "approval.approve");
        Long detailId = resolvePendingDetailId(request);
        Map<String, Object> context = resolveDetailContext(detailId);
        Map<String, Object> result = executeDetailProcedure("PKG_WF_APPROVAL.APPROVE_DETAIL", detailId, currentUserId(), text(request.get("comment")));
        Map<String, Object> actionResult = executeNodeAction("approve", context, request);
        if (!actionResult.isEmpty()) {
            result.put("nodeAction", actionResult);
        }
        return result;
    }

    @Transactional
    public Map<String, Object> reject(Map<String, Object> request) {
        String pageCode = requiredText(request, "pageCode");
        requireButton(pageCode, "approval.reject");
        String comment = requiredText(request, "comment");
        Long detailId = resolvePendingDetailId(request);
        Map<String, Object> context = resolveDetailContext(detailId);
        Map<String, Object> result = executeDetailProcedure("PKG_WF_APPROVAL.REJECT_DETAIL", detailId, currentUserId(), comment);
        Map<String, Object> actionResult = executeNodeAction("reject", context, request);
        if (!actionResult.isEmpty()) {
            result.put("nodeAction", actionResult);
        }
        return result;
    }

    @Transactional
    public Map<String, Object> cancel(Map<String, Object> request) {
        String pageCode = requiredText(request, "pageCode");
        requireButton(pageCode, "approval.cancel");
        Long currentUserId = currentUserId();
        String tableCode = requiredText(request, "tableCode");
        Long billId = requiredLong(request, "billId");
        requireApplicantForConfiguredFlow(pageCode, tableCode, billId, currentUserId);
        Long approvalId = resolveApprovalId(request);
        return executeApprovalProcedure(
            "PKG_WF_APPROVAL.CANCEL_APPROVAL",
            approvalId,
            currentUserId,
            text(request.get("comment"))
        );
    }

    public Map<String, Object> progress(String pageCode, String tableCode, Long billId) {
        requireButton(pageCode, "approval.progress");
        Map<String, Object> main = one(
            "SELECT * FROM (" +
                "SELECT APPROVAL_ID as \"approvalId\", FLOW_ID as \"flowId\", PAGE_CODE as \"pageCode\", PAGE_NAME as \"pageName\", " +
                "TABLE_CODE as \"tableCode\", BILL_ID as \"billId\", BILL_NO as \"billNo\", BILL_TITLE as \"billTitle\", " +
                "START_USER_ID as \"startUserId\", START_USERNAME as \"startUsername\", START_REAL_NAME as \"startRealName\", " +
                "START_TIME as \"startTime\", STATUS as \"status\", CURRENT_LEVEL as \"currentLevel\", CURRENT_ROUND as \"currentRound\", FINISHED_TIME as \"finishedTime\" " +
                "FROM WF_APPROVAL_MAIN WHERE PAGE_CODE=" + sqlString(pageCode) +
                " AND TABLE_CODE=" + sqlString(tableCode) +
                " AND BILL_ID=" + billId +
                " ORDER BY APPROVAL_ID DESC" +
            ") WHERE ROWNUM=1"
        );

        if (main.isEmpty()) {
            return Map.of("main", Map.of(), "details", List.of(), "logs", List.of());
        }

        Long approvalId = longValue(main.get("approvalId"));
        List<Map<String, Object>> details = dynamicMapper.selectList(
            "SELECT DETAIL_ID as \"detailId\", ROUND_NO as \"roundNo\", NODE_ID as \"nodeId\", APPROVAL_LEVEL as \"approvalLevel\", NODE_NAME as \"nodeName\", " +
                "APPROVAL_MODE as \"approvalMode\", TARGET_TYPE as \"targetType\", TARGET_USER_ID as \"targetUserId\", " +
                "TARGET_USER_NAME as \"targetUserName\", TARGET_ROLE_ID as \"targetRoleId\", TARGET_ROLE_NAME as \"targetRoleName\", " +
                "STATUS as \"status\", OPERATE_USER_ID as \"operateUserId\", OPERATE_USERNAME as \"operateUsername\", " +
                "OPERATE_REAL_NAME as \"operateRealName\", APPROVE_COMMENT as \"approveComment\", APPROVE_TIME as \"approveTime\", " +
                "OPERATE_TIME as \"operateTime\" FROM WF_APPROVAL_DETAIL WHERE APPROVAL_ID=" + approvalId +
                " ORDER BY ROUND_NO DESC, APPROVAL_LEVEL, DETAIL_ID"
        );
        List<Map<String, Object>> logs = dynamicMapper.selectList(
            "SELECT LOG_ID as \"logId\", APPROVAL_ID as \"approvalId\", ROUND_NO as \"roundNo\", DETAIL_ID as \"detailId\", ACTION_TYPE as \"actionType\", " +
                "ACTION_USER_ID as \"actionUserId\", ACTION_USERNAME as \"actionUsername\", ACTION_REAL_NAME as \"actionRealName\", " +
                "ACTION_TIME as \"actionTime\", FROM_STATUS as \"fromStatus\", TO_STATUS as \"toStatus\", " +
                "ACTION_COMMENT as \"actionComment\", DETAIL_MESSAGE as \"detailMessage\" FROM WF_APPROVAL_LOG " +
                "WHERE APPROVAL_ID=" + approvalId + " ORDER BY LOG_ID"
        );

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("main", main);
        result.put("details", details);
        result.put("logs", logs);
        return result;
    }

    public Map<String, Object> actionConfig(String pageCode, String tableCode, Long billId, String action) {
        String normalizedAction = normalizeAction(action);
        requireButton(pageCode, "approve".equals(normalizedAction) ? "approval.approve" : "approval.reject");
        Long detailId = resolvePendingDetailId(Map.of("pageCode", pageCode, "tableCode", tableCode, "billId", billId));
        Map<String, Object> context = resolveDetailContext(detailId);
        NodeAction actionConfig = resolveNodeAction(context, normalizedAction);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("enabled", actionConfig.enabled());
        result.put("mode", actionConfig.mode());
        result.put("procedure", actionConfig.procedure());
        result.put("params", actionConfig.params());
        result.put("action", normalizedAction);
        result.put("detailId", detailId);
        return result;
    }

    private Map<String, Object> executeDetailProcedure(String procedure, Long detailId, Long currentUserId, String comment) {
        return jdbcTemplate.execute((Connection connection) -> {
            CallableStatement statement = connection.prepareCall("{call " + procedure + "(?,?,?,?,?)}");
            statement.setLong(1, detailId);
            statement.setLong(2, currentUserId);
            statement.setString(3, comment);
            statement.registerOutParameter(4, Types.VARCHAR);
            statement.registerOutParameter(5, Types.VARCHAR);
            return statement;
        }, (CallableStatement statement) -> {
            statement.execute();
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("detailId", detailId);
            result.put("status", statement.getString(4));
            result.put("message", statement.getString(5));
            return result;
        });
    }

    private Map<String, Object> executeApprovalProcedure(String procedure, Long approvalId, Long currentUserId, String comment) {
        return jdbcTemplate.execute((Connection connection) -> {
            CallableStatement statement = connection.prepareCall("{call " + procedure + "(?,?,?,?,?)}");
            statement.setLong(1, approvalId);
            statement.setLong(2, currentUserId);
            statement.setString(3, comment);
            statement.registerOutParameter(4, Types.VARCHAR);
            statement.registerOutParameter(5, Types.VARCHAR);
            return statement;
        }, (CallableStatement statement) -> {
            statement.execute();
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("approvalId", approvalId);
            result.put("status", statement.getString(4));
            result.put("message", statement.getString(5));
            return result;
        });
    }

    private Map<String, Object> executeNodeAction(String action, Map<String, Object> context, Map<String, Object> request) {
        NodeAction nodeAction = resolveNodeAction(context, action);
        if (!nodeAction.enabled()) {
            return Map.of();
        }

        String procedure = validateProcedureName(nodeAction.procedure());
        Long billId = longValue(context.get("billId"));
        if (billId == null) {
            throw new BusinessException(400, "审批动作缺少页面主表ID");
        }

        String paramsJson = actionParamsJson(request);
        jdbcTemplate.execute((Connection connection) -> {
            CallableStatement statement = connection.prepareCall("{call " + procedure + "(?,?)}");
            statement.setLong(1, billId);
            statement.setString(2, paramsJson);
            return statement;
        }, (CallableStatement statement) -> {
            statement.execute();
            return null;
        });

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("procedure", procedure);
        result.put("mode", nodeAction.mode());
        result.put("billId", billId);
        return result;
    }

    private NodeAction resolveNodeAction(Map<String, Object> context, String action) {
        String actionConfig = text(context.get("actionConfig"));
        if (StrUtil.isBlank(actionConfig)) {
            return NodeAction.disabled();
        }
        try {
            JsonNode root = objectMapper.readTree(actionConfig);
            JsonNode node = root.path(action);
            String procedure = textValue(node, "procedure");
            String mode = StrUtil.blankToDefault(textValue(node, "mode"), "AUTO").trim().toUpperCase();
            boolean enabled = node.path("enabled").isMissingNode() || node.path("enabled").asBoolean(true);
            if (!enabled || StrUtil.isBlank(procedure)) {
                return NodeAction.disabled();
            }
            return new NodeAction(true, procedure, "MANUAL".equals(mode) ? "MANUAL" : "AUTO", parseActionParams(node.path("params")));
        } catch (Exception e) {
            throw new BusinessException(400, "审批节点动作配置JSON格式错误");
        }
    }

    private List<Map<String, Object>> parseActionParams(JsonNode paramsNode) {
        if (paramsNode == null || !paramsNode.isArray()) {
            return List.of();
        }
        try {
            return objectMapper.convertValue(
                paramsNode,
                objectMapper.getTypeFactory().constructCollectionType(List.class, Map.class)
            );
        } catch (Exception ignored) {
            return List.of();
        }
    }

    private String actionParamsJson(Map<String, Object> request) {
        Object raw = request.get("actionParamsJson");
        if (raw instanceof String rawText && StrUtil.isNotBlank(rawText)) {
            return rawText;
        }
        Object params = request.get("actionParams");
        if (params == null) {
            return "{}";
        }
        if (params instanceof String text && StrUtil.isNotBlank(text)) {
            return text;
        }
        try {
            return objectMapper.writeValueAsString(params);
        } catch (Exception e) {
            throw new BusinessException(400, "审批动作参数JSON序列化失败");
        }
    }

    private Map<String, Object> resolveDetailContext(Long detailId) {
        Map<String, Object> row = one(
            "SELECT D.DETAIL_ID as \"detailId\", D.APPROVAL_ID as \"approvalId\", D.NODE_ID as \"nodeId\", " +
                "D.ROUND_NO as \"roundNo\", D.APPROVAL_LEVEL as \"approvalLevel\", M.PAGE_CODE as \"pageCode\", " +
                "M.TABLE_CODE as \"tableCode\", M.BILL_ID as \"billId\", N.ACTION_CONFIG as \"actionConfig\" " +
                "FROM WF_APPROVAL_DETAIL D " +
                "JOIN WF_APPROVAL_MAIN M ON M.APPROVAL_ID=D.APPROVAL_ID " +
                "LEFT JOIN WF_FLOW_NODE N ON N.NODE_ID=D.NODE_ID " +
                "WHERE D.DETAIL_ID=" + detailId
        );
        if (row.isEmpty()) {
            throw new BusinessException(400, "未找到审批明细：" + detailId);
        }
        return row;
    }

    private String normalizeAction(String action) {
        String normalized = text(action);
        if (!"approve".equals(normalized) && !"reject".equals(normalized)) {
            throw new BusinessException(400, "审批动作只能是 approve 或 reject");
        }
        return normalized;
    }

    private String validateProcedureName(String procedure) {
        String value = text(procedure);
        if (StrUtil.isBlank(value) || !value.matches("[A-Za-z_][A-Za-z0-9_$#]*(\\.[A-Za-z_][A-Za-z0-9_$#]*){0,2}")) {
            throw new BusinessException(400, "非法存储过程名称");
        }
        return value;
    }

    private String textValue(JsonNode node, String key) {
        JsonNode value = node == null ? null : node.get(key);
        return value == null || value.isNull() ? null : value.asText();
    }

    private Long resolvePendingDetailId(Map<String, Object> request) {
        Long provided = longValue(request.get("detailId"));
        if (provided != null) {
            return provided;
        }

        Long currentUserId = currentUserId();
        String pageCode = requiredText(request, "pageCode");
        String tableCode = requiredText(request, "tableCode");
        Long billId = requiredLong(request, "billId");

        Map<String, Object> row = one(
            "SELECT * FROM (" +
                "SELECT D.DETAIL_ID as \"detailId\" " +
                "FROM WF_APPROVAL_MAIN M " +
                "JOIN WF_APPROVAL_DETAIL D ON D.APPROVAL_ID = M.APPROVAL_ID " +
                "WHERE M.PAGE_CODE=" + sqlString(pageCode) +
                " AND M.TABLE_CODE=" + sqlString(tableCode) +
                " AND M.BILL_ID=" + billId +
                " AND M.STATUS='APPROVING' " +
                " AND D.STATUS='PENDING' " +
                " AND (D.TARGET_TYPE='USER' AND D.TARGET_USER_ID=" + currentUserId +
                " OR D.TARGET_TYPE='ROLE' AND EXISTS (" +
                "   SELECT 1 FROM T_COST_USER_ROLE UR WHERE UR.USER_ID=" + currentUserId + " AND UR.ROLE_ID=D.TARGET_ROLE_ID" +
                " )) " +
                "ORDER BY M.APPROVAL_ID DESC, D.APPROVAL_LEVEL, D.DETAIL_ID" +
            ") WHERE ROWNUM=1"
        );

        Long detailId = longValue(row.get("detailId"));
        if (detailId == null) {
            throw new BusinessException(400, "当前用户没有这张单据的待审批任务");
        }
        return detailId;
    }

    private Long resolveApprovalId(Map<String, Object> request) {
        Long provided = longValue(request.get("approvalId"));
        if (provided != null) {
            return provided;
        }

        String pageCode = requiredText(request, "pageCode");
        String tableCode = requiredText(request, "tableCode");
        Long billId = requiredLong(request, "billId");

        Map<String, Object> row = one(
            "SELECT * FROM (" +
                "SELECT APPROVAL_ID as \"approvalId\" FROM WF_APPROVAL_MAIN " +
                "WHERE PAGE_CODE=" + sqlString(pageCode) +
                " AND TABLE_CODE=" + sqlString(tableCode) +
                " AND BILL_ID=" + billId +
                " ORDER BY APPROVAL_ID DESC" +
            ") WHERE ROWNUM=1"
        );

        Long approvalId = longValue(row.get("approvalId"));
        if (approvalId == null) {
            throw new BusinessException(400, "当前单据暂无审批记录");
        }
        return approvalId;
    }

    private void requireApplicantForConfiguredFlow(String pageCode, String tableCode, Long billId, Long currentUserId) {
        Long flowId = resolveApprovalFlowId(pageCode, tableCode, billId);
        if (flowId == null || !isApplicantRestrictionEnabled(flowId)) {
            return;
        }

        TableMetadataDTO metadata = metadataService.getTableMetadata(tableCode);
        String applicantColumn = resolveApplicantColumn(metadata.id());
        if (StrUtil.isBlank(applicantColumn)) {
            return;
        }

        String targetTable = validateIdentifier(metadata.targetTable(), "targetTable");
        String pkColumn = validateIdentifier(metadata.pkColumn(), "pkColumn");
        String column = validateIdentifier(applicantColumn, "applicantColumn");

        Map<String, Object> bill = one(
            "SELECT " + column + " as \"applicant\" FROM " + targetTable +
                " WHERE " + pkColumn + "=" + billId + " AND DELETED=0"
        );
        String applicant = text(bill.get("applicant"));
        if (StrUtil.isBlank(applicant)) {
            throw new BusinessException(400, "当前单据未填写申请人，无法执行该审批动作");
        }

        Map<String, Object> user = one(
            "SELECT ID as \"id\", USERNAME as \"username\", REAL_NAME as \"realName\" " +
                "FROM T_COST_USER WHERE ID=" + currentUserId + " AND DELETED=0"
        );
        String normalizedApplicant = applicant.trim();
        if (
            normalizedApplicant.equals(String.valueOf(currentUserId)) ||
            normalizedApplicant.equalsIgnoreCase(text(user.get("username"))) ||
            normalizedApplicant.equals(text(user.get("realName")))
        ) {
            return;
        }

            throw new BusinessException(400, "仅申请人可以执行该审批动作");
    }

    private Long resolveApprovalFlowId(String pageCode, String tableCode, Long billId) {
        Map<String, Object> existing = one(
            "SELECT * FROM (" +
                "SELECT FLOW_ID as \"flowId\" FROM WF_APPROVAL_MAIN WHERE PAGE_CODE=" + sqlString(pageCode) +
                " AND TABLE_CODE=" + sqlString(tableCode) +
                " AND BILL_ID=" + billId +
                " ORDER BY APPROVAL_ID DESC" +
            ") WHERE ROWNUM=1"
        );
        Long existingFlowId = longValue(existing.get("flowId"));
        if (existingFlowId != null) {
            return existingFlowId;
        }

        Map<String, Object> configured = one(
            "SELECT * FROM (" +
                "SELECT FLOW_ID as \"flowId\" FROM WF_FLOW_DEF WHERE PAGE_CODE=" + sqlString(pageCode) +
                " AND IS_ENABLED=1 ORDER BY FLOW_PRIORITY, FLOW_VERSION DESC, FLOW_ID DESC" +
            ") WHERE ROWNUM=1"
        );
        return longValue(configured.get("flowId"));
    }

    private boolean isApplicantRestrictionEnabled(Long flowId) {
        Map<String, Object> flow = one("SELECT REMARK as \"remark\" FROM WF_FLOW_DEF WHERE FLOW_ID=" + flowId);
        String remark = text(flow.get("remark"));
        return StrUtil.isNotBlank(remark) &&
            remark.contains("\"requireApplicantForSubmit\"") &&
            remark.contains("true");
    }

    private String resolveApplicantColumn(Long tableMetadataId) {
        if (tableMetadataId == null) {
            return null;
        }
        Map<String, Object> column = one(
            "SELECT COLUMN_NAME as \"columnName\", TARGET_COLUMN as \"targetColumn\" " +
                "FROM T_COST_COLUMN_METADATA WHERE TABLE_METADATA_ID=" + tableMetadataId +
                " AND UPPER(COLUMN_NAME)='APPLICANT' AND NVL(IS_VIRTUAL,0)=0 AND DELETED=0"
        );
        return firstNotBlank(text(column.get("targetColumn")), text(column.get("columnName")));
    }

    private Long currentUserId() {
        Long userId = SecurityUtils.getCurrentUserId();
        if (userId != null) {
            return userId;
        }
        String username = SecurityUtils.getCurrentUsername();
        if (StrUtil.isBlank(username)) {
            throw new BusinessException(401, "未登录或无法获取当前用户");
        }
        Map<String, Object> row = one(
            "SELECT ID as \"id\" FROM T_COST_USER WHERE USERNAME=" + sqlString(username) + " AND DELETED=0"
        );
        Long resolved = longValue(row.get("id"));
        if (resolved == null) {
            throw new BusinessException(401, "未找到当前登录用户：" + username);
        }
        return resolved;
    }

    private void requireButton(String pageCode, String buttonKey) {
        Long userId = currentUserId();
        PagePermission permission = permissionService.getPagePermission(userId, pageCode);
        if (permission == null || !permission.hasButton(buttonKey)) {
            throw new BusinessException(403, "无按钮权限：" + buttonKey);
        }
    }

    private Map<String, Object> one(String sql) {
        List<Map<String, Object>> rows = dynamicMapper.selectList(sql);
        return rows.isEmpty() ? Map.of() : rows.get(0);
    }

    private String requiredText(Map<String, Object> request, String key) {
        String value = text(request.get(key));
        if (StrUtil.isBlank(value)) {
            throw new BusinessException(400, key + "不能为空");
        }
        return value;
    }

    private Long requiredLong(Map<String, Object> request, String key) {
        Long value = longValue(request.get(key));
        if (value == null) {
            throw new BusinessException(400, key + "不能为空");
        }
        return value;
    }

    private String text(Object value) {
        if (value instanceof Clob clob) {
            try {
                return clob.getSubString(1, (int) clob.length());
            } catch (Exception ignored) {
                return null;
            }
        }
        return value == null ? null : String.valueOf(value);
    }

    private String firstNotBlank(String... values) {
        for (String value : values) {
            if (StrUtil.isNotBlank(value)) {
                return value;
            }
        }
        return "";
    }

    private Long longValue(Object value) {
        if (value instanceof Number number) {
            return number.longValue();
        }
        if (value instanceof String text && StrUtil.isNotBlank(text)) {
            return Long.parseLong(text);
        }
        return null;
    }

    private String sqlString(String value) {
        if (StrUtil.isBlank(value)) {
            return "NULL";
        }
        return "'" + value.replace("'", "''") + "'";
    }

    private String validateIdentifier(String value, String name) {
        if (StrUtil.isBlank(value) || !value.matches("[A-Za-z_][A-Za-z0-9_]*")) {
            throw new BusinessException(400, "非法数据库标识：" + name);
        }
        return value;
    }

    private record NodeAction(boolean enabled, String procedure, String mode, List<Map<String, Object>> params) {
        private static NodeAction disabled() {
            return new NodeAction(false, "", "AUTO", List.of());
        }
    }
}
