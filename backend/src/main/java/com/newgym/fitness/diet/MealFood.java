package com.newgym.fitness.diet;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "meal_foods")
@Getter
@Setter
@NoArgsConstructor
public class MealFood {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JsonIgnore
    private Meal meal;

    @ManyToOne(optional = false)
    private Food food;

    private Double amount; // g or ml
}

