package com.newgym.fitness.workout;

import com.newgym.fitness.user.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface WorkoutPlanRepository extends JpaRepository<WorkoutPlan, Long> {
    List<WorkoutPlan> findByUserOrderByCreatedAtDesc(User user);
}

