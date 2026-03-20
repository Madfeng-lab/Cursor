package com.newgym.fitness.ai.dto;

/**
 * 前端上传图片（base64）后，由后端代调用多模态模型并返回结构化结果。
 */
public record AnalyzeFoodRequest(
        String imageBase64,
        String mimeType
) {}

