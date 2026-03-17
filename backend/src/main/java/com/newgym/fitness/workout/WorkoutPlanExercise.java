package com.newgym.fitness.workout;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "workout_plan_exercises")
@Getter
@Setter
@NoArgsConstructor
public class WorkoutPlanExercise {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    private WorkoutPlanDay day;

    @Column(nullable = false)
    private String name;

    private String primaryMuscleGroup;

    private int plannedSets;

    private Integer plannedReps;

    private Double plannedWeight;

    private Integer restSeconds;
}

