package com.newgym.fitness.auth;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.FileWriter;
import java.io.IOException;
import java.security.Key;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

@Service
public class JwtService {

    private final Key key;
    private final long expirationMillis;

    public JwtService(@Value("${jwt.secret}") String secret,
                      @Value("${jwt.expiration-seconds}") long expirationSeconds) {
        // #region agent log
        Map<String, Object> data = new HashMap<>();
        data.put("hypothesisId", "A");
        data.put("secretNull", secret == null);
        data.put("secretLength", secret != null ? secret.length() : 0);
        String payload = "{\"sessionId\":\"bed3a7\",\"runId\":\"pre-fix\",\"hypothesisId\":\"A\","
                + "\"location\":\"JwtService.java:28\","
                + "\"message\":\"JwtService constructor input\","
                + "\"data\":" + data.toString().replace("=", ":") + ","
                + "\"timestamp\":" + System.currentTimeMillis() + "}";
        try (FileWriter fw = new FileWriter("debug-bed3a7.log", true)) {
            fw.write(payload + System.lineSeparator());
        } catch (IOException ignored) {
        }
        // #endregion

        this.key = Keys.hmacShaKeyFor(secret.getBytes());
        this.expirationMillis = expirationSeconds * 1000;
    }

    public String generateToken(Long userId, String email) {
        Date now = new Date();
        Date expiry = new Date(now.getTime() + expirationMillis);
        return Jwts.builder()
                .setSubject(String.valueOf(userId))
                .claim("email", email)
                .setIssuedAt(now)
                .setExpiration(expiry)
                .signWith(key, SignatureAlgorithm.HS256)
                .compact();
    }
}

