package com.newgym.fitness.diet;

import com.newgym.fitness.user.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDate;

@Entity
@Table(name = "daily_calorie_summary")
@Getter
@Setter
@NoArgsConstructor
public class DailyCalorieSummary {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    private User user;

    private LocalDate date;

    private Integer caloriesIn;

    private Integer caloriesOut;

    private Integer calorieDiff;
}

