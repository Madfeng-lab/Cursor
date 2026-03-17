package com.newgym.fitness.workout;

import com.newgym.fitness.user.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.List;

public interface WorkoutSessionRepository extends JpaRepository<WorkoutSession, Long> {

    List<WorkoutSession> findByUserAndStartedAtBetweenOrderByStartedAtDesc(
            User user,
            LocalDateTime from,
            LocalDateTime to
    );
}

