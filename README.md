# Level Up!

**Level Up!** is a health and fitness app that makes staying active enjoyable through **experience gain**, **leveling up**, and **gamified progression**.

## Availability

- Available at https://nicholasdakis.com/level_up/ on all devices
- Installable as a **Progressive Web App (PWA)** via the browser link for a native app experience
- Available on **Android** via the [Google Play Store](https://play.google.com/store/apps/details?id=com.nicholasdakis.levelup)

## Wiki

For a deeper dive into the architecture, caching system, backend design, challenges faced during development, etc. refer to the [Level Up! Wiki](https://github.com/nicholasdakis/level_up/wiki).

## Changelog

This project contains a comprehensive **CHANGELOG.md** file which is updated throughout development.

## Features

**Level Up!** has 5 main tabs navigated via a floating bottom nav bar:

### 1) Home

A personal dashboard showing the user's progress at a glance:

- **XP progress bar** towards the next level
- **Daily reward** button to claim experience once every 23 hours
- **Stats cards** showing today's logged calories and total food items logged
- **Streak cards** showing current food logging streak and daily reward streak
- **Quick access** to Reminders and the Calorie Calculator
- **Guest mode** for trying the app without an account

### 2) Food Logging

- Track food intake across **breakfast**, **lunch**, **dinner**, and **snack** categories
- **Search tab** for looking up foods via the **FatSecret API** with serving size adjustment and automatic macro scaling
- **Barcode tab** for scanning food barcodes via the **Open Food Facts API**
- **Manual tab** for logging custom foods with name, calories, macros, serving size, and a custom unit option
- **Edit serving size** on already-logged foods
- Full **macro breakdown** (protein, carbs, fat) displayed on each logged food card
- **Food Analytics** screen with charts showing calorie and macro breakdowns by meal, with daily and date-range views
- **Recent foods** section that saves recently logged foods locally for quick re-logging

### 3) Explore

- Discover **nearby points of interest** (cafes, parks, gyms, etc.) near you
- **Check in** to nearby locations within 50 meters to earn **experience points**
- Each location has a **24-hour cooldown** between check-ins

### 4) Leaderboard

- Displays the top users sorted by level and experience points
- Shows each user's profile picture, username, level, and XP

### 5) Badges

- Earn badges for completing achievements across food logging, exploration, streaks, and more
- Badges have **multiple tiers** with increasing thresholds
- Badge claiming for streak-based achievements is tied to **highest streak** so progress is never lost after a streak break
- Progress bars and percentage labels show current advancement towards the next tier

## Additional Features

### Calorie Calculator

- Accessible from the Home screen
- Input information in either **imperial** or **metric**
- Calculate caloric needs using either **Harris-Benedict** or **Mifflin-St Jeor**
- Displays information about **Basal Metabolic Rate (BMR)**, **Total Daily Energy Expenditure (TDEE)**, and **the effects of physical activity on BMR**
- Saves and restores all calculator inputs across sessions using local storage

### Reminders

- **Set reminders** with a custom message and date/time
- Receive **push notifications** via Firebase Cloud Messaging when the reminder is due
- **Delete** reminders you no longer need

### User Authentication

- **Email/password** and **Google sign-in** support
- **Profile synchronization** across devices
- **Data persistence** for all user progress and settings
- **Guest mode** for trying the app without creating an account

### Settings Drawer

#### 1) Personal Preferences

- **Change app theme color** with a color picker
- **Change profile picture** with cropping and compression
- **Customize username** with server-side uniqueness checking (case-insensitive)
- **Set nutrition goals** (calories, protein, carbs, fat, weight goal)
- **Toggle notifications** on or off
- **Recent foods limit** to control how many foods are saved locally

#### 2) About The Developer

- Information about the creator behind Level Up!

#### 3) Install App as PWA

- Install Level Up! as a **Progressive Web App** for a native app experience
- Includes a manual installation guide for non-Chromium browsers
