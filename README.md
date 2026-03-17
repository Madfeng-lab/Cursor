## Fitness App MVP

This repository contains the MVP implementation for an AI-assisted fitness training and nutrition tracking app, based on the PRD.

### Tech Stack

- Backend: Java, Spring Boot, MySQL, Redis
- Frontend: Flutter (iOS / Android)

### Structure

- `backend/` - Spring Boot REST API (users, workouts, meals, statistics)
- `frontend/` - Flutter mobile app with bottom navigation (Home, Training, Diet, Stats, Profile)

### Getting Started

1. Backend
   - Import `backend` as a Maven project.
   - Configure MySQL and Redis connection in `application.yml`.
   - Run the main application class.

2. Frontend
   - Open `frontend` with Flutter tooling.
   - Run `flutter pub get`.
   - Start the app with `flutter run`.

> Note: This is an MVP focusing on core flows: user system, workout plans and sessions, diet logging, and basic statistics. AI features are stubbed and planned for later versions.

