package com.newgym.fitness.diet;

import com.newgym.fitness.user.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;

public interface MealRepository extends JpaRepository<Meal, Long> {

    List<Meal> findByUserAndDateBetweenOrderByDateAsc(User user, LocalDate from, LocalDate to);
}

