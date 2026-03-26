package com.newgym.fitness.aigymhelper;

import jakarta.annotation.Resource;
import org.springframework.http.MediaType;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.CrossOrigin;
import reactor.core.publisher.Flux;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Instant;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;


@RestController
@RequestMapping("/api/aigymhelper")
@CrossOrigin
public class AigymHelperController {

    @Resource
    private AigymHelperService aigymHelperService;

    @GetMapping(value = "/chat", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<ServerSentEvent<String>> chat(@RequestParam int memoryId, @RequestParam String message) {

        Flux<String> stream = aigymHelperService.chatStream(memoryId, message);
        System.out.println(stream.map(chunk -> ServerSentEvent.<String>builder().data(chunk).build()));
        return stream.map(chunk -> ServerSentEvent.<String>builder().data(chunk).build());
    }

}
