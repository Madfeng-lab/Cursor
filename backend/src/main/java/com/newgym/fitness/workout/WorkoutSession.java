package com.newgym.fitness.workout;

import com.newgym.fitness.user.User;
import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "workout_sessions")
@Getter
@Setter
@NoArgsConstructor
public class WorkoutSession {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JsonIgnore
    private User user;

    @ManyToOne
    private WorkoutPlan plan;

    private String title;

    private LocalDateTime startedAt = LocalDateTime.now();

    private LocalDateTime endedAt;

    private boolean completed;

    private double totalVolumeKg;

    private double estimatedCalories;

    @OneToMany(mappedBy = "session", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<WorkoutSessionExercise> exercises = new ArrayList<>();

    public Duration getDuration() {
        if (startedAt == null || endedAt == null) return Duration.ZERO;
        return Duration.between(startedAt, endedAt);
    }
}

