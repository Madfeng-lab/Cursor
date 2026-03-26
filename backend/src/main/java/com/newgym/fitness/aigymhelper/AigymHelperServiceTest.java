package com.newgym.fitness.aigymhelper;

import jakarta.annotation.Resource;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class AigymHelperServiceTest {
    @Resource
    private AigymHelperService aigymHelperService;

    @Test
    void chat() {
        String result = aigymHelperService.chat("你好，我是程序员stan");
        System.out.println(result);
    }
}