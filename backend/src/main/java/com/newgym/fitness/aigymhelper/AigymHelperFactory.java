package com.newgym.fitness.aigymhelper;

import dev.langchain4j.model.chat.ChatModel;
import dev.langchain4j.model.chat.StreamingChatModel; 
import dev.langchain4j.memory.chat.MessageWindowChatMemory;
import dev.langchain4j.rag.content.retriever.ContentRetriever;
import dev.langchain4j.service.AiServices;
import org.springframework.context.annotation.Bean; 
import org.springframework.context.annotation.Configuration;

@Configuration
public class AigymHelperFactory {

    private final ChatModel myQwenChatModel;    
    private final StreamingChatModel myQwenStreamingChatModel;
    private final ContentRetriever contentRetriever;
    private final SafeInputGuardrail safeInputGuardrail;
    private final SafeOutputGuardrail safeOutputGuardrail;
    public AigymHelperFactory(ChatModel myQwenChatModel,
                              StreamingChatModel myQwenStreamingChatModel,
                              ContentRetriever contentRetriever,
                              SafeInputGuardrail safeInputGuardrail,
                              SafeOutputGuardrail safeOutputGuardrail) {
        this.myQwenChatModel = myQwenChatModel;
        this.myQwenStreamingChatModel = myQwenStreamingChatModel;
        this.contentRetriever = contentRetriever;
        this.safeInputGuardrail = safeInputGuardrail;   
        this.safeOutputGuardrail = safeOutputGuardrail;
    }

    @Bean
    public AigymHelperService aigymHelperService() {
        return AiServices.builder(AigymHelperService.class)
                .chatModel(myQwenChatModel)
                .streamingChatModel(myQwenStreamingChatModel)
                .chatMemoryProvider(memoryId -> MessageWindowChatMemory.withMaxMessages(20))
                .contentRetriever(contentRetriever)
                .inputGuardrails(safeInputGuardrail)
                .outputGuardrails(safeOutputGuardrail)
                .build();
    }
}
