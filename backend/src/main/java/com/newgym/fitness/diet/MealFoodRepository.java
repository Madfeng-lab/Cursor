package com.newgym.fitness.diet;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface MealFoodRepository extends JpaRepository<MealFood, Long> {

    List<MealFood> findByFood_Id(Long foodId);
}
