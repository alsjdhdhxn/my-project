package com.cost.costserver.config;

import com.cost.costserver.common.JwtUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.http.server.ServletServerHttpRequest;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;
import org.springframework.web.socket.server.HandshakeInterceptor;

import java.util.Map;

@Slf4j
@Configuration
@EnableWebSocket
@RequiredArgsConstructor
public class WebSocketConfig implements WebSocketConfigurer {

    private final AppWebSocketHandler appWebSocketHandler;
    private final JwtUtil jwtUtil;

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(appWebSocketHandler, "/ws")
                .addInterceptors(jwtHandshakeInterceptor())
                .setAllowedOriginPatterns("*");
    }

    private HandshakeInterceptor jwtHandshakeInterceptor() {
        return new HandshakeInterceptor() {
            @Override
            public boolean beforeHandshake(ServerHttpRequest request, ServerHttpResponse response,
                                           WebSocketHandler wsHandler, Map<String, Object> attributes) {
                String token = null;
                if (request instanceof ServletServerHttpRequest servletRequest) {
                    token = servletRequest.getServletRequest().getParameter("token");
                }
                if (token == null || !jwtUtil.validateToken(token)) {
                    log.warn("[WS] 握手失败：token无效");
                    return false;
                }
                attributes.put("userId", jwtUtil.getUserId(token));
                attributes.put("username", jwtUtil.getUsername(token));
                return true;
            }

            @Override
            public void afterHandshake(ServerHttpRequest request, ServerHttpResponse response,
                                       WebSocketHandler wsHandler, Exception exception) {
            }
        };
    }
}
