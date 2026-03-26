package com.newgym.fitness.aigymhelper;

import dev.langchain4j.data.message.UserMessage;
import dev.langchain4j.guardrail.InputGuardrail;
import dev.langchain4j.guardrail.InputGuardrailResult;
import org.springframework.stereotype.Component;

import java.util.Set;

@Component
public class SafeInputGuardrail implements InputGuardrail {

    private static final Set<String> SENSITIVE_WORDS = Set.of("kill", "evil");

    @Override
    public InputGuardrailResult validate(UserMessage userMessage) {
        String inputText = userMessage.singleText().toLowerCase();
        String[] words = inputText.split("\\W+");
        for (String word : words) {
            if (SENSITIVE_WORDS.contains(word)) {
                return fatal("Sensitive word detected: " + word);
            }
        }
        return success();
    }
}
