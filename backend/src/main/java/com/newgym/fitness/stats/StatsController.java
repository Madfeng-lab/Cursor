package com.newgym.fitness.stats;

import com.newgym.fitness.user.User;
import com.newgym.fitness.user.UserRepository;
import com.newgym.fitness.workout.WorkoutSession;
import com.newgym.fitness.workout.WorkoutSessionRepository;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import lombok.Setter;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.DoubleSummaryStatistics;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/stats")
@RequiredArgsConstructor
@CrossOrigin
public class StatsController {

    private final UserRepository userRepository;
    private final WorkoutSessionRepository sessionRepository;
    private final WeightLogRepository weightLogRepository;

    @PostMapping("/weights")
    public WeightLog addWeight(@RequestParam Long userId, @RequestBody AddWeightRequest request) {
        User user = userRepository.findById(userId).orElseThrow();
        WeightLog log = new WeightLog();
        log.setUser(user);
        log.setDate(request.getDate());
        log.setWeightKg(request.getWeightKg());
        return weightLogRepository.save(log);
    }

    @GetMapping("/weights")
    public List<WeightLog> listWeights(@RequestParam Long userId,
                                       @RequestParam LocalDate from,
                                       @RequestParam LocalDate to) {
        User user = userRepository.findById(userId).orElseThrow();
        return weightLogRepository.findByUserAndDateBetweenOrderByDateAsc(user, from, to);
    }

    @GetMapping("/overview")
    public OverviewResponse overview(@RequestParam Long userId,
                                     @RequestParam LocalDate from,
                                     @RequestParam LocalDate to) {
        User user = userRepository.findById(userId).orElseThrow();

        LocalDateTime start = from.atStartOfDay();
        LocalDateTime end = to.atTime(LocalTime.MAX);

        List<WorkoutSession> sessions =
                sessionRepository.findByUserAndStartedAtBetweenOrderByStartedAtDesc(user, start, end);

        int totalWorkouts = sessions.size();
        double totalVolumeKg = sessions.stream().mapToDouble(WorkoutSession::getTotalVolumeKg).sum();
        double totalCalories = sessions.stream().mapToDouble(WorkoutSession::getEstimatedCalories).sum();

        List<WeightLog> weights =
                weightLogRepository.findByUserAndDateBetweenOrderByDateAsc(user, from, to);

        Map<LocalDate, DoubleSummaryStatistics> weightStatsByDate = weights.stream()
                .collect(Collectors.groupingBy(
                        WeightLog::getDate,
                        Collectors.summarizingDouble(WeightLog::getWeightKg)
                ));

        return new OverviewResponse(totalWorkouts, totalVolumeKg, totalCalories, weightStatsByDate);
    }

    @Getter
    @Setter
    public static class AddWeightRequest {
        @NotNull
        private LocalDate date;
        @NotNull
        private Double weightKg;
    }

    @Getter
    @AllArgsConstructor
    public static class OverviewResponse {
        private int totalWorkouts;
        private double totalVolumeKg;
        private double totalCalories;
        private Map<LocalDate, DoubleSummaryStatistics> weightStatsByDate;
    }
}

