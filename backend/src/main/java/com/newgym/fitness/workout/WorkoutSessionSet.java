package com.newgym.fitness.workout;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "workout_session_sets")
@Getter
@Setter
@NoArgsConstructor
public class WorkoutSessionSet {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JsonIgnore
    private WorkoutSessionExercise exercise;

    private int setIndex;

    private Double weightKg;

    private Integer reps;

    private Integer durationSeconds;

    private boolean completed;

    private Integer restSeconds;
}

