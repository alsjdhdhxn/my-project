package com.cost.costserver.common;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.validation.BindException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Pattern ORA_PATTERN = Pattern.compile("ORA-\\d+");
    private static final Pattern SQL_PATTERN_MYBATIS = Pattern.compile(
            "### SQL:\\s*(.+?)(?=\\s*###|$)", Pattern.DOTALL);
    private static final Pattern SQL_PATTERN_SPRING = Pattern.compile(
            "(?:SQL \\[|bad SQL grammar \\[)(.+?)\\]", Pattern.DOTALL);
    private static final Pattern SQL_PATTERN_DML = Pattern.compile(
            "((?:INSERT INTO|UPDATE|DELETE FROM)\\s+\\S+.*?)(?=\\s*###|;|$)", Pattern.DOTALL | Pattern.CASE_INSENSITIVE);

    /**
     * 业务异常
     */
    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<Result<?>> handleBusinessException(BusinessException e) {
        log.warn("业务异常: {}", e.getMessage());
        HttpStatus status = e.getCode() >= 400 && e.getCode() < 500 
                ? HttpStatus.valueOf(e.getCode()) 
                : HttpStatus.INTERNAL_SERVER_ERROR;
        return ResponseEntity.status(status).body(Result.fail(e.getCode(), e.getMessage()));
    }

    /**
     * 参数校验异常（@Valid 注解触发）
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Result<?>> handleValidationException(MethodArgumentNotValidException e) {
        String message = e.getBindingResult().getFieldErrors().stream()
                .map(FieldError::getDefaultMessage)
                .collect(Collectors.joining("; "));
        log.warn("参数校验失败: {}", message);
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Result.fail(400, message));
    }

    /**
     * 参数绑定异常
     */
    @ExceptionHandler(BindException.class)
    public ResponseEntity<Result<?>> handleBindException(BindException e) {
        String message = e.getFieldErrors().stream()
                .map(FieldError::getDefaultMessage)
                .collect(Collectors.joining("; "));
        log.warn("参数绑定失败: {}", message);
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Result.fail(400, message));
    }

    /**
     * 请求体解析异常
     */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<Result<?>> handleHttpMessageNotReadable(HttpMessageNotReadableException e) {
        log.warn("请求体解析失败: {}", e.getMessage());
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Result.fail(400, "请求参数格式错误"));
    }

    /**
     * 权限不足异常
     */
    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<Result<?>> handleAccessDenied(AccessDeniedException e) {
        log.warn("权限不足: {}", e.getMessage());
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Result.fail(403, "无权限访问"));
    }

    /**
     * 其他未知异常 — 提取数据库错误详情（ORA 码、SQL）返回给前端
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Result<?>> handleException(Exception e) {
        log.error("系统异常", e);

        Map<String, Object> detail = new LinkedHashMap<>();
        String oraCode = null;
        String sql = null;
        String dbMessage = null;

        // 遍历异常链提取 ORA 错误码和 SQL
        Throwable cursor = e;
        while (cursor != null) {
            String msg = cursor.getMessage();
            if (msg != null) {
                if (oraCode == null) {
                    Matcher m = ORA_PATTERN.matcher(msg);
                    if (m.find()) oraCode = m.group();
                }
                if (sql == null) {
                    // 尝试 MyBatis 格式: ### SQL: ...
                    Matcher m1 = SQL_PATTERN_MYBATIS.matcher(msg);
                    if (m1.find()) {
                        sql = m1.group(1).trim();
                    } else {
                        // 尝试 Spring 格式: SQL [...] 或 bad SQL grammar [...]
                        Matcher m2 = SQL_PATTERN_SPRING.matcher(msg);
                        if (m2.find()) {
                            sql = m2.group(1).trim();
                        } else {
                            // 尝试直接匹配 DML 语句
                            Matcher m3 = SQL_PATTERN_DML.matcher(msg);
                            if (m3.find()) {
                                sql = m3.group(1).trim();
                            }
                        }
                    }
                    if (sql != null && sql.length() > 2000) sql = sql.substring(0, 2000);
                }
                if (dbMessage == null && msg.contains("ORA-")) {
                    dbMessage = msg.length() > 500 ? msg.substring(0, 500) : msg;
                }
            }
            if (cursor instanceof java.sql.SQLException && sql == null) {
                dbMessage = cursor.getMessage();
            }
            cursor = cursor.getCause();
        }

        if (oraCode != null) detail.put("oraCode", oraCode);
        if (sql != null) detail.put("sql", sql);
        if (dbMessage != null) detail.put("message", dbMessage);

        // 根因
        Throwable root = e;
        while (root.getCause() != null) root = root.getCause();
        String rootMsg = root.getMessage();
        if (rootMsg != null && rootMsg.length() > 500) rootMsg = rootMsg.substring(0, 500);
        detail.put("rootCause", rootMsg);

        String summary = oraCode != null
                ? oraCode + ": " + (dbMessage != null && dbMessage.length() > 100 ? dbMessage.substring(0, 100) : dbMessage)
                : "系统异常，请联系管理员";

        return ResponseEntity.status(HttpStatus.OK)
                .body(Result.fail(500, summary, detail));
    }
}
