package com.newgym.fitness.workout;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "workout_plan_days")
@Getter
@Setter
@NoArgsConstructor
public class WorkoutPlanDay {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    private WorkoutPlan plan;

    @Column(nullable = false)
    private int dayIndex; // 1..N

    @Column(nullable = false)
    private String title; // e.g. Chest + Triceps

    @OneToMany(mappedBy = "day", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<WorkoutPlanExercise> exercises = new ArrayList<>();
}

