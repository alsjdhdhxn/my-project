package com.cost.costserver.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 通用 WebSocket 处理器，支持广播和定向推送
 */
@Slf4j
@Component
public class AppWebSocketHandler extends TextWebSocketHandler {

    private final ConcurrentHashMap<String, WebSocketSession> sessions = new ConcurrentHashMap<>();
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        sessions.put(session.getId(), session);
        String username = (String) session.getAttributes().get("username");
        log.info("[WS] 连接建立: {} ({})", username, session.getId());
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        sessions.remove(session.getId());
        String username = (String) session.getAttributes().get("username");
        log.info("[WS] 连接关闭: {} ({})", username, status);
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) {
        // 心跳响应
        String payload = message.getPayload();
        if ("ping".equals(payload)) {
            sendSafe(session, new TextMessage("pong"));
        }
    }

    /**
     * 线程安全地发送消息（WebSocketSession.sendMessage 非线程安全）
     */
    private void sendSafe(WebSocketSession session, TextMessage message) {
        if (!session.isOpen()) return;
        synchronized (session) {
            try {
                session.sendMessage(message);
            } catch (IOException e) {
                log.warn("[WS] 发送失败: {}", session.getId());
            }
        }
    }

    /**
     * 广播消息给所有连接
     */
    public void broadcast(String type, Object payload) {
        Map<String, Object> msg = Map.of("type", type, "payload", payload);
        try {
            String json = objectMapper.writeValueAsString(msg);
            TextMessage textMessage = new TextMessage(json);
            for (WebSocketSession session : sessions.values()) {
                sendSafe(session, textMessage);
            }
        } catch (Exception e) {
            log.error("[WS] 广播消息序列化失败", e);
        }
    }
}
