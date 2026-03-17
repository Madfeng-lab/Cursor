package com.newgym.fitness.user;

import jakarta.persistence.*;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDate;

@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true, nullable = false)
    @Email
    private String email;

    @Column(nullable = false)
    @NotBlank
    private String passwordHash;

    @Column(unique = true)
    private String phone;

    private String nickname;

    private String gender; // male / female / other

    private Double heightCm;

    private Double weightKg;

    private Double bodyFatPercent;

    private String trainingExperience; // beginner / intermediate / advanced

    private String trainingGoal; // lose_fat / gain_muscle / strength / maintain

    private Double targetWeightKg;

    private Double targetBodyFatPercent;

    private LocalDate targetDate;

    private boolean active = true;
}

