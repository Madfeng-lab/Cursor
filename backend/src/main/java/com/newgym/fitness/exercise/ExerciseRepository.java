package com.newgym.fitness.exercise;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ExerciseRepository extends JpaRepository<Exercise, Long> {

    List<Exercise> findByPrimaryMuscleOrderByNameAsc(String primaryMuscle);

    List<Exercise> findByPrimaryMuscleAndNameContainingIgnoreCaseOrderByNameAsc(
            String primaryMuscle,
            String keyword
    );
}

