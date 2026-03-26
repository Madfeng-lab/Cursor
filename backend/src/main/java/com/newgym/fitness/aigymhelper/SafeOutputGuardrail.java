package com.newgym.fitness.aigymhelper;

import dev.langchain4j.data.message.AiMessage;
import dev.langchain4j.guardrail.OutputGuardrail;
import dev.langchain4j.guardrail.OutputGuardrailResult;
import org.springframework.stereotype.Component;

import java.util.Set;

@Component
public class SafeOutputGuardrail implements OutputGuardrail {

    private static final Set<String> SENSITIVE_WORDS = Set.of("kill", "evil");

    @Override
    public OutputGuardrailResult validate(AiMessage aiMessage) {
        String outputText = aiMessage.text().toLowerCase();
        String[] words = outputText.split("\\W+");
        for (String word : words) {
            if (SENSITIVE_WORDS.contains(word)) {
                return fatal("Sensitive word detected: " + word);
            }
        }
        return success();
    }
}
