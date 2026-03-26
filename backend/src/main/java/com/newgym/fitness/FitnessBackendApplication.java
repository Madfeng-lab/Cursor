package com.newgym.fitness;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Instant;

@SpringBootApplication
public class FitnessBackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(FitnessBackendApplication.class, args);
    }

}

