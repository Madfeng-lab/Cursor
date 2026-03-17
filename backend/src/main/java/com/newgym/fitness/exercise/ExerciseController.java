package com.newgym.fitness.exercise;

import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/exercises")
@RequiredArgsConstructor
@CrossOrigin
public class ExerciseController {

    private final ExerciseRepository exerciseRepository;

    @GetMapping
    public List<Exercise> list(
            @RequestParam String muscleGroup,
            @RequestParam(required = false) String keyword
    ) {
        if (keyword != null && !keyword.isBlank()) {
            return exerciseRepository
                    .findByPrimaryMuscleAndNameContainingIgnoreCaseOrderByNameAsc(
                            muscleGroup, keyword.trim());
        }
        return exerciseRepository.findByPrimaryMuscleOrderByNameAsc(muscleGroup);
    }

    @PostMapping
    public Exercise create(@RequestBody Exercise exercise) {
        return exerciseRepository.save(exercise);
    }
}

