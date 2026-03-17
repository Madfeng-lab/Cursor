package com.newgym.fitness.diet;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.newgym.fitness.user.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "meals")
@Getter
@Setter
@NoArgsConstructor
public class Meal {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JsonIgnore
    private User user;

    private LocalDate date;

    @Column(nullable = false)
    private String mealType; // breakfast / lunch / dinner / snack

    @OneToMany(mappedBy = "meal", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<MealFood> items = new ArrayList<>();
}

