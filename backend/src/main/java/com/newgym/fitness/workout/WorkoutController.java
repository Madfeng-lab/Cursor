package com.newgym.fitness.workout;

import com.newgym.fitness.user.User;
import com.newgym.fitness.user.UserRepository;
import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import lombok.Setter;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;

@RestController
@RequestMapping("/api/workouts")
@RequiredArgsConstructor
@CrossOrigin
public class WorkoutController {

    private final WorkoutPlanRepository planRepository;
    private final WorkoutSessionRepository sessionRepository;
    private final UserRepository userRepository;

    // For MVP we pass userId explicitly; later can switch to auth principal.

    @PostMapping("/plans")
    public WorkoutPlan createPlan(@RequestParam Long userId, @RequestBody CreatePlanRequest request) {
        User user = userRepository.findById(userId).orElseThrow();
        WorkoutPlan plan = new WorkoutPlan();
        plan.setUser(user);
        plan.setName(request.getName());
        plan.setTrainingDaysPerWeek(request.getTrainingDaysPerWeek());
        return planRepository.save(plan);
    }

    @GetMapping("/plans")
    public List<WorkoutPlan> listPlans(@RequestParam Long userId) {
        User user = userRepository.findById(userId).orElseThrow();
        return planRepository.findByUserOrderByCreatedAtDesc(user);
    }

    @PostMapping("/sessions")
    public WorkoutSession startSession(@RequestParam Long userId,
                                       @RequestBody StartSessionRequest request) {
        User user = userRepository.findById(userId).orElseThrow();
        WorkoutSession session = new WorkoutSession();
        session.setUser(user);
        session.setTitle(request.getTitle());
        return sessionRepository.save(session);
    }

    @PostMapping("/sessions/{sessionId}/finish")
    public WorkoutSession finishSession(@PathVariable Long sessionId,
                                        @RequestBody FinishSessionRequest request) {
        WorkoutSession session = sessionRepository.findById(sessionId).orElseThrow();
        session.setEndedAt(LocalDateTime.now());
        session.setCompleted(request.isCompleted());
        if (request.getTitle() != null && !request.getTitle().isBlank()) {
            session.setTitle(request.getTitle());
        }
        session.setTotalVolumeKg(request.getTotalVolumeKg());
        session.setEstimatedCalories(request.getEstimatedCalories());
        if (request.getExercises() != null && !request.getExercises().isEmpty()) {
            // overwrite session exercises (cascade + orphanRemoval)
            session.getExercises().clear();
            for (ExerciseDetail e : request.getExercises()) {
                WorkoutSessionExercise ex = new WorkoutSessionExercise();
                ex.setSession(session);
                ex.setName(e.getName());
                ex.setPrimaryMuscleGroup(e.getPrimaryMuscleGroup());

                List<WorkoutSessionSet> sets = new ArrayList<>();
                if (e.getSets() != null) {
                    int idx = 0;
                    for (SetDetail s : e.getSets()) {
                        WorkoutSessionSet set = new WorkoutSessionSet();
                        set.setExercise(ex);
                        set.setSetIndex(s.getSetIndex() != null ? s.getSetIndex() : idx);
                        set.setWeightKg(s.getWeightKg());
                        set.setReps(s.getReps());
                        set.setCompleted(s.isCompleted());
                        set.setRestSeconds(s.getRestSeconds());
                        sets.add(set);
                        idx++;
                    }
                }
                ex.setSets(sets);
                session.getExercises().add(ex);
            }
        }
        return sessionRepository.save(session);
    }

    @GetMapping("/sessions")
    public List<WorkoutSession> listSessions(@RequestParam Long userId,
                                             @RequestParam LocalDate from,
                                             @RequestParam LocalDate to) {
        User user = userRepository.findById(userId).orElseThrow();
        LocalDateTime start = from.atStartOfDay();
        LocalDateTime end = to.atTime(LocalTime.MAX);
        return sessionRepository.findByUserAndStartedAtBetweenOrderByStartedAtDesc(user, start, end);
    }

    @GetMapping("/sessions/unfinished")
    public WorkoutSession getLatestUnfinishedSession(@RequestParam Long userId) {
        User user = userRepository.findById(userId).orElseThrow();
        return sessionRepository.findTopByUserAndCompletedFalseOrderByStartedAtDesc(user)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No unfinished session"));
    }

    @PostMapping("/sessions/{sessionId}/progress")
    public WorkoutSession saveProgress(@PathVariable Long sessionId,
                                        @RequestBody ProgressSessionRequest request) {
        WorkoutSession session = sessionRepository.findById(sessionId).orElseThrow();
        session.setCompleted(false);
        session.setEndedAt(null);

        if (request.getTitle() != null && !request.getTitle().isBlank()) {
            session.setTitle(request.getTitle());
        }

        if (request.getExercises() != null && !request.getExercises().isEmpty()) {
            // overwrite session exercises (cascade + orphanRemoval)
            session.getExercises().clear();
            for (ExerciseDetail e : request.getExercises()) {
                WorkoutSessionExercise ex = new WorkoutSessionExercise();
                ex.setSession(session);
                ex.setName(e.getName());
                ex.setPrimaryMuscleGroup(e.getPrimaryMuscleGroup());

                List<WorkoutSessionSet> sets = new ArrayList<>();
                if (e.getSets() != null) {
                    int idx = 0;
                    for (SetDetail s : e.getSets()) {
                        WorkoutSessionSet set = new WorkoutSessionSet();
                        set.setExercise(ex);
                        set.setSetIndex(s.getSetIndex() != null ? s.getSetIndex() : idx);
                        set.setWeightKg(s.getWeightKg());
                        set.setReps(s.getReps());
                        set.setCompleted(s.isCompleted());
                        set.setRestSeconds(s.getRestSeconds());
                        sets.add(set);
                        idx++;
                    }
                }
                ex.setSets(sets);
                session.getExercises().add(ex);
            }
        }

        return sessionRepository.save(session);
    }

    @Getter
    @Setter
    public static class CreatePlanRequest {
        @NotBlank
        private String name;
        private int trainingDaysPerWeek;
    }

    @Getter
    @Setter
    public static class StartSessionRequest {
        private String title;
    }

    @Getter
    @Setter
    public static class FinishSessionRequest {
        private boolean completed;
        private String title;
        private double totalVolumeKg;
        private double estimatedCalories;
        private List<ExerciseDetail> exercises;
    }

    @Getter
    @Setter
    public static class ProgressSessionRequest {
        private String title;
        private List<ExerciseDetail> exercises;
    }

    @Getter
    @Setter
    public static class ExerciseDetail {
        private String name;
        private String primaryMuscleGroup;
        private List<SetDetail> sets;
    }

    @Getter
    @Setter
    public static class SetDetail {
        private Integer setIndex;
        private Double weightKg;
        private Integer reps;
        private boolean completed;
        private Integer restSeconds;
    }
}

