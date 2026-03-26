package com.newgym.fitness.aigymhelper;

import dev.langchain4j.service.MemoryId;
import dev.langchain4j.service.SystemMessage;
import dev.langchain4j.service.UserMessage;
import dev.langchain4j.service.guardrail.InputGuardrails;
import reactor.core.publisher.Flux;

@InputGuardrails(SafeInputGuardrail.class)
public interface AigymHelperService {
    @SystemMessage(fromResource= "system-prompt.txt")
    String chat(String message);
    // 流式对话
    @SystemMessage(fromResource = "system-prompt.txt")
    Flux<String> chatStream(@MemoryId int memoryId, @UserMessage String userMessage);
}
