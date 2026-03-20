package com.newgym.fitness.ai.dto;

/**
 * 给前端的结构化响应。
 */
public record AnalyzeFoodResponse(
        String foodName,
        double estimatedWeightG,
        int calories,
        double protein,
        double carbs,
        double fat
) {}

