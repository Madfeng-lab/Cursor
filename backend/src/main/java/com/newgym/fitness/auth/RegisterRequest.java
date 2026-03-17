package com.newgym.fitness.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDate;

@Getter
@Setter
public class RegisterRequest {

    @Email
    @NotBlank
    private String email;

    @NotBlank
    private String password;

    private String gender;
    private Double heightCm;
    private Double weightKg;
    private Double bodyFatPercent;
    private String trainingExperience;
    private String trainingGoal;
    private Double targetWeightKg;
    private Double targetBodyFatPercent;
    private LocalDate targetDate;
}

