package com.newgym.fitness.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.util.ContentCachingRequestWrapper;
import org.springframework.web.util.ContentCachingResponseWrapper;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Locale;
import java.util.Enumeration;
import java.util.LinkedHashMap;
import java.util.Map;

@Component
public class ApiPayloadLoggingFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(ApiPayloadLoggingFilter.class);
    private static final int MAX_PAYLOAD_CHARS = 8000;

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !request.getRequestURI().startsWith("/api/") || isSseRequest(request);
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        ContentCachingRequestWrapper requestWrapper = new ContentCachingRequestWrapper(request);
        ContentCachingResponseWrapper responseWrapper = new ContentCachingResponseWrapper(response);

        long startedAt = System.currentTimeMillis();
        Exception error = null;
        try {
            filterChain.doFilter(requestWrapper, responseWrapper);
        } catch (ServletException | IOException | RuntimeException e) {
            error = e;
            throw e;
        } finally {
            long costMs = System.currentTimeMillis() - startedAt;
            int status = responseWrapper.getStatus();

            String requestPath = requestWrapper.getRequestURI();
            String query = requestWrapper.getQueryString();
            if (StringUtils.hasText(query)) {
                requestPath += "?" + query;
            }

            String reqBody = toPayloadString(
                    requestWrapper.getContentAsByteArray(),
                    requestWrapper.getCharacterEncoding(),
                    requestWrapper.getContentType()
            );
            // #region agent log
            Charset reqCharset = resolveCharset(requestWrapper.getCharacterEncoding(), requestWrapper.getContentType());
            // #endregion
            String respBody = toPayloadString(
                    responseWrapper.getContentAsByteArray(),
                    responseWrapper.getCharacterEncoding(),
                    responseWrapper.getContentType()
            );
            // #region agent log
            Charset respCharset = resolveCharset(responseWrapper.getCharacterEncoding(), responseWrapper.getContentType());
            // #endregion

            Map<String, String> headers = readAndMaskHeaders(requestWrapper);

            // #region agent log
            if (requestPath.startsWith("/api/workouts/sessions/unfinished")) {
                writeDebugLog(
                        "pre-fix",
                        "H2",
                        "ApiPayloadLoggingFilter.java:82",
                        "workout unfinished payload charset snapshot",
                        "{"
                                + "\"reqContentType\":\"" + esc(requestWrapper.getContentType()) + "\","
                                + "\"respContentType\":\"" + esc(responseWrapper.getContentType()) + "\","
                                + "\"reqCharset\":\"" + esc(reqCharset.name()) + "\","
                                + "\"respCharset\":\"" + esc(respCharset.name()) + "\","
                                + "\"respTitle\":\"" + esc(extractTitle(respBody)) + "\""
                                + "}"
                );
            }
            // #endregion

            if (error == null) {
                log.info(
                        "[API] {} {} status={} costMs={} headers={} reqBody={} respBody={}",
                        requestWrapper.getMethod(),
                        requestPath,
                        status,
                        costMs,
                        headers,
                        reqBody,
                        respBody
                );
            } else {
                log.error(
                        "[API] {} {} status={} costMs={} headers={} reqBody={} respBody={} error={}",
                        requestWrapper.getMethod(),
                        requestPath,
                        status,
                        costMs,
                        headers,
                        reqBody,
                        respBody,
                        error.toString()
                );
            }

            responseWrapper.copyBodyToResponse();
        }
    }

    private String toPayloadString(byte[] payload, String encoding, String contentType) {
        if (payload == null || payload.length == 0) {
            return "";
        }
        Charset charset = resolveCharset(encoding, contentType);
        String body = new String(payload, charset);
        if (body.length() <= MAX_PAYLOAD_CHARS) {
            return body;
        }
        return body.substring(0, MAX_PAYLOAD_CHARS) + "...(truncated)";
    }

    private Charset resolveCharset(String encoding, String contentType) {
        if (StringUtils.hasText(contentType)) {
            String lower = contentType.toLowerCase(Locale.ROOT);
            int charsetIndex = lower.indexOf("charset=");
            if (charsetIndex >= 0) {
                String value = lower.substring(charsetIndex + 8).trim();
                int semicolon = value.indexOf(';');
                if (semicolon >= 0) {
                    value = value.substring(0, semicolon).trim();
                }
                try {
                    return Charset.forName(value);
                } catch (Exception ignored) {
                }
            }
            // JSON spec defaults to UTF-8 when charset is not provided.
            // This avoids mojibake caused by servlet/container default ISO-8859-1.
            if (lower.contains("application/json") || lower.startsWith("text/")) {
                return StandardCharsets.UTF_8;
            }
        }

        if (StringUtils.hasText(encoding)) {
            try {
                return Charset.forName(encoding);
            } catch (Exception ignored) {
            }
        }

        return StandardCharsets.UTF_8;
    }

    private Map<String, String> readAndMaskHeaders(HttpServletRequest request) {
        Map<String, String> headers = new LinkedHashMap<>();
        Enumeration<String> names = request.getHeaderNames();
        while (names != null && names.hasMoreElements()) {
            String name = names.nextElement();
            String value = request.getHeader(name);
            headers.put(name, maskHeader(name, value));
        }
        return headers;
    }

    private String maskHeader(String name, String value) {
        if (value == null) return "";
        String lower = name.toLowerCase();
        if ("authorization".equals(lower) || "cookie".equals(lower) || "set-cookie".equals(lower)) {
            if (value.length() <= 12) return "******";
            return value.substring(0, 6) + "******";
        }
        if (value.length() <= 512) {
            return value;
        }
        return value.substring(0, 512) + "...(truncated)";
    }

    private boolean isSseRequest(HttpServletRequest request) {
        if (request.getRequestURI().startsWith("/api/aigymhelper/chat")) {
            return true;
        }
        String accept = request.getHeader("Accept");
        return StringUtils.hasText(accept) && accept.toLowerCase(Locale.ROOT).contains("text/event-stream");
    }

    private String extractTitle(String jsonLike) {
        if (!StringUtils.hasText(jsonLike)) return "";
        String marker = "\"title\":\"";
        int start = jsonLike.indexOf(marker);
        if (start < 0) return "";
        int valueStart = start + marker.length();
        int valueEnd = jsonLike.indexOf("\"", valueStart);
        if (valueEnd < 0 || valueEnd <= valueStart) return "";
        return jsonLike.substring(valueStart, valueEnd);
    }

    private String esc(String value) {
        if (value == null) return "";
        return value.replace("\\", "\\\\").replace("\"", "\\\"");
    }

    private void writeDebugLog(String runId, String hypothesisId, String location, String message, String dataJson) {
        String line = "{"
                + "\"sessionId\":\"1c4714\","
                + "\"runId\":\"" + runId + "\","
                + "\"hypothesisId\":\"" + hypothesisId + "\","
                + "\"location\":\"" + location + "\","
                + "\"message\":\"" + message + "\","
                + "\"data\":" + dataJson + ","
                + "\"timestamp\":" + Instant.now().toEpochMilli()
                + "}";
        try {
            Files.writeString(
                    Path.of("debug-1c4714.log"),
                    line + System.lineSeparator(),
                    StandardOpenOption.CREATE,
                    StandardOpenOption.APPEND
            );
        } catch (IOException ignored) {
        }
    }
}
