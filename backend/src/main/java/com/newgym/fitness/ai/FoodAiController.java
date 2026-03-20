package com.newgym.fitness.ai;

import com.newgym.fitness.ai.dto.AnalyzeFoodRequest;
import com.newgym.fitness.ai.dto.AnalyzeFoodResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/ai/food")
@RequiredArgsConstructor
@CrossOrigin
public class FoodAiController {

    private final FoodAiArkService foodAiArkService;

    @PostMapping("/analyze")
    public AnalyzeFoodResponse analyze(@RequestBody AnalyzeFoodRequest request) {
        return foodAiArkService.analyze(request);
    }
}

