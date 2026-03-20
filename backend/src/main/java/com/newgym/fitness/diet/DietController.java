package com.newgym.fitness.diet;

import com.newgym.fitness.user.User;
import com.newgym.fitness.user.UserRepository;
import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import lombok.Setter;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/diet")
@RequiredArgsConstructor
@CrossOrigin
public class DietController {

    private final UserRepository userRepository;
    private final FoodRepository foodRepository;
    private final MealRepository mealRepository;
    private final MealFoodRepository mealFoodRepository;

    @PostMapping("/foods")
    public Food createFood(@RequestBody CreateFoodRequest request) {
        Food food = new Food();
        food.setName(request.getName());
        food.setCalories(request.getCalories());
        food.setProtein(request.getProtein());
        food.setCarbs(request.getCarbs());
        food.setFat(request.getFat());
        food.setPhotoMimeType(request.getPhotoMimeType());
        food.setPhotoBase64(request.getPhotoBase64());
        return foodRepository.save(food);
    }

    @GetMapping("/foods")
    public List<Food> listFoods() {
        return foodRepository.findAll();
    }

    @PutMapping("/foods/{foodId}")
    public Food updateFood(@PathVariable Long foodId, @RequestBody CreateFoodRequest request) {
        Food food = foodRepository.findById(foodId).orElseThrow();
        food.setName(request.getName());
        food.setCalories(request.getCalories());
        food.setProtein(request.getProtein());
        food.setCarbs(request.getCarbs());
        food.setFat(request.getFat());
        if (request.getPhotoMimeType() != null) {
            food.setPhotoMimeType(request.getPhotoMimeType());
        }
        if (request.getPhotoBase64() != null) {
            food.setPhotoBase64(request.getPhotoBase64());
        }
        return foodRepository.save(food);
    }

    @DeleteMapping("/foods/{foodId}")
    public void deleteFood(@PathVariable Long foodId) {
        foodRepository.findById(foodId).orElseThrow();
        for (MealFood mf : mealFoodRepository.findByFood_Id(foodId)) {
            mealFoodRepository.delete(mf);
        }
        foodRepository.deleteById(foodId);
    }

    @PostMapping("/meals")
    public Meal createMeal(@RequestParam Long userId, @RequestBody CreateMealRequest request) {
        User user = userRepository.findById(userId).orElseThrow();
        Meal meal = new Meal();
        meal.setUser(user);
        meal.setDate(request.getDate());
        meal.setMealType(request.getMealType());
        meal = mealRepository.save(meal);

        for (CreateMealItem item : request.getItems()) {
            Food food = foodRepository.findById(item.getFoodId()).orElseThrow();
            MealFood mf = new MealFood();
            mf.setMeal(meal);
            mf.setFood(food);
            mf.setAmount(item.getAmount());
            meal.getItems().add(mf);
        }

        return mealRepository.save(meal);
    }

    @GetMapping("/meals")
    public List<Meal> listMeals(@RequestParam Long userId,
                                @RequestParam LocalDate from,
                                @RequestParam LocalDate to) {
        User user = userRepository.findById(userId).orElseThrow();
        return mealRepository.findByUserAndDateBetweenOrderByDateAsc(user, from, to);
    }

    /** 向已有餐次追加食物项（避免同一天同类型多餐） */
    @PostMapping("/meals/{mealId}/items")
    public Meal addMealItems(@PathVariable Long mealId, @RequestBody List<CreateMealItem> items) {
        Meal meal = mealRepository.findById(mealId).orElseThrow();
        for (CreateMealItem item : items) {
            Food food = foodRepository.findById(item.getFoodId()).orElseThrow();
            MealFood mf = new MealFood();
            mf.setMeal(meal);
            mf.setFood(food);
            mf.setAmount(item.getAmount());
            meal.getItems().add(mf);
        }
        return mealRepository.save(meal);
    }

    /** 删除餐次中的某一食物项 */
    @DeleteMapping("/meals/items/{mealFoodId}")
    public void deleteMealItem(@PathVariable Long mealFoodId) {
        mealFoodRepository.deleteById(mealFoodId);
    }

    /** 修改餐次中某一食物项（克数或替换食物） */
    @PatchMapping("/meals/items/{mealFoodId}")
    public MealFood updateMealItem(@PathVariable Long mealFoodId,
                                   @RequestBody UpdateMealItemRequest request) {
        MealFood mf = mealFoodRepository.findById(mealFoodId).orElseThrow();
        if (request.getAmount() != null) {
            mf.setAmount(request.getAmount());
        }
        if (request.getFoodId() != null) {
            mf.setFood(foodRepository.findById(request.getFoodId()).orElseThrow());
        }
        return mealFoodRepository.save(mf);
    }

    @Getter
    @Setter
    public static class CreateFoodRequest {
        @NotBlank
        private String name;
        private Integer calories;
        private Double protein;
        private Double carbs;
        private Double fat;
        /** 可选；前端宜传 JPEG 缩略图 Base64，避免单条过大 */
        private String photoMimeType;
        private String photoBase64;
    }

    @Getter
    @Setter
    public static class CreateMealItem {
        private Long foodId;
        private Double amount;
    }

    @Getter
    @Setter
    public static class CreateMealRequest {
        private LocalDate date;
        private String mealType;
        private List<CreateMealItem> items;
    }

    @Getter
    @Setter
    public static class UpdateMealItemRequest {
        private Double amount;
        private Long foodId;
    }
}

