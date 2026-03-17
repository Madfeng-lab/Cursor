package com.newgym.fitness.stats;

import com.newgym.fitness.user.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;

public interface WeightLogRepository extends JpaRepository<WeightLog, Long> {

    List<WeightLog> findByUserAndDateBetweenOrderByDateAsc(User user, LocalDate from, LocalDate to);
}

