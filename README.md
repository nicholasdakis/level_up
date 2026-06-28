# Level Up!

**Level Up!** is a health and fitness app that turns your daily habits into a game. Log food, drink water, track your weight, explore your city, and earn XP for every healthy choice you make.

## Availability

- Available at https://nicholasdakis.com/level_up/ on all devices
- Installable as a **Progressive Web App (PWA)** via the browser link for a native app experience
- Available on **Android** via the [Google Play Store](https://play.google.com/store/apps/details?id=com.nicholasdakis.levelup)

## Wiki

For a deeper dive into the architecture, caching system, backend design, and challenges faced during development, refer to the [Level Up! Wiki](https://github.com/nicholasdakis/level_up/wiki).

## Changelog

This project contains a comprehensive **CHANGELOG.md** file which is updated throughout development.

## Features

**Level Up!** has 4 main tabs navigated via a floating bottom nav bar:

### 1) Home

A personal dashboard that gives you a full picture of your progress:

- **XP bar and level badge** showing progress toward the next level with a live count of XP to go
- **Daily reward** card with a shimmer effect when claimable; earn XP every 23 hours and build a streak multiplier for bonus XP
- **Watch an ad** to earn additional XP on demand
- **Refer a friend** and both of you earn XP once they reach level 3
- **Logging cards** for calories, macros, water intake, and body weight, all in one place
- **Streak tracking** for food logging and daily reward streaks, with all-time best records
- **Quick access** to Reminders and the Calorie Calculator
- **Guest mode** for trying the app without an account

### 2) Food Logging

A full-featured nutrition tracker with macro-level detail:

- Track food intake across **breakfast**, **lunch**, **dinner**, and **snack** categories
- **Search** millions of foods via the **FatSecret API** with serving size adjustment and automatic macro scaling
- **Barcode scanning** via the **Open Food Facts API** for instant food lookup
- **Manual entry** for custom foods with name, calories, macros, serving size, and a custom unit option
- **Edit serving sizes** and **macro values** directly on already-logged foods
- **Full macro breakdown** (protein, carbs, fat) displayed per food and per meal
- **Food Analytics** with rich line charts, calorie and macro breakdowns by meal, and a most-logged foods card
- **Water analytics** showing hydration trends over time
- **Weight analytics** with a goal line, stat tiles, and full entry history
- **Recent foods** synced across devices for quick re-logging
- **Voice search** to find foods hands-free

### 3) Progress

A dedicated progression hub combining leveling, achievements, and leaderboard in one place:

- **Leaderboard** showing the top players sorted by level and XP, with your own rank highlighted
- **Rank system** with named tiers (Beginner, Rising, Committed, Dedicated, Unstoppable, Legendary)
- **Badges** earned by completing achievements across food logging, exploration, streaks, referrals, and more
- **Multi-tier badges** with progress bars and percentage labels showing advancement toward the next tier

### 4) Explore

Turn your surroundings into an XP source:

- Discover **nearby points of interest** (cafes, parks, gyms, landmarks, and more) on a live map
- **Check in** to locations within 50 meters to earn XP
- Each location has a **24-hour cooldown** between check-ins to encourage variety

## Additional Features

### Calorie Calculator

- Accessible from the Home screen
- Input in **imperial or metric**
- Calculates using **Harris-Benedict** or **Mifflin-St Jeor**
- Shows **BMR**, **TDEE**, and the effect of activity on daily needs
- Saves and restores all inputs across sessions

### Reminders

- Set reminders with a **custom message and date/time**
- **Speak your reminder** via voice input directly in the message field
- Receive **push notifications** via Firebase Cloud Messaging when the reminder fires
- Delete reminders you no longer need

### User Authentication

- **Email/password** and **Google Sign-In** support
- Full **cross-device sync** for all progress, food logs, water, weight, and settings

### Settings

- **Theme color picker** that adapts the entire app to your chosen color using perceptual color math
- **Profile picture** upload with cropping and compression
- **Username** with server-side uniqueness checking
- **Nutrition goals** for calories, protein, carbs, fat, water, and weight targets
- **Unit preferences** for using metric or imperial throughout the app
- **Notification toggle** and push notification management
- **Changelog** viewable in-app
