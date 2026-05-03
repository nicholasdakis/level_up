# Level Up!

**Level Up!** is a health and fitness app that makes staying active enjoyable through **experience gain**, **leveling up**, and **gamified progression**.

## Availability

- Available at https://nicholasdakis.com/level_up/ on all devices
- Installable as a **Progressive Web App (PWA)** via the browser link for a native app experience

## Wiki

For a deeper dive into the architecture, caching system, backend design, challenges faced during development, etc. refer to the [Level Up! Wiki](https://github.com/nicholasdakis/level_up/wiki).

## Changelog

This project contains a comprehensive **CHANGELOG.md** file which is updated throughout development.

## Features

**Level Up!** has 6 main tabs:

### 1) Food Logging

- Track food intake across **breakfast**, **lunch**, **dinner**, and **snack** categories
- **Search tab** for looking up foods via the **FatSecret API** with serving size adjustment and automatic macro scaling
- **Barcode tab** for scanning food barcodes via the **Open Food Facts API**
- **Manual tab** for logging custom foods with name, calories, macros, serving size, and a custom unit option
- **Edit serving size** on already-logged foods
- Full **macro breakdown** (protein, carbs, fat) displayed on each logged food card
- **Food Analytics** screen with charts showing calorie and macro breakdowns by meal, with daily and date-range views
- **Recent foods** section that saves the last 30 logged foods locally for quick re-logging

### 2) Explore

- Discover **nearby points of interest** (cafes, parks, gyms, etc.) on an interactive **OpenStreetMap**
- **Check in** to nearby locations within 50 meters to earn **experience points**
- Each location has a **24-hour cooldown** between check-ins
- Confetti celebration on successful check-in

### 3) Leaderboard

- Displays the top users sorted by level and experience points
- Shows each user's profile picture, username, level, and XP

### 4) Badges

- Earn badges for completing achievements across food logging, exploration, streaks, and more
- Badges have **multiple tiers** with increasing thresholds
- Badge claiming for streak-based achievements is tied to **highest streak** so progress is never lost after a streak break
- Progress bars show current advancement towards the next tier

### 5) Reminders

- **Set reminders** with a custom message and date/time
- Receive **push notifications** via Firebase Cloud Messaging when the reminder is due
- **Delete** reminders you no longer need

### 6) Calorie Calculator

- Input information in either **imperial** or **metric**
- Calculate caloric needs using either **Harris-Benedict** or **Mifflin-St Jeor**
- Displays information about **Basal Metabolic Rate (BMR)**, **Total Daily Energy Expenditure (TDEE)**, and **the effects of physical activity on BMR**
- Saves and restores all calculator inputs across sessions using local storage

## Additional Features

### User Authentication

- **Email/password** and **Google sign-in** support
- **Profile synchronization** across devices
- **Data persistence** for all user progress and settings

### Daily XP Reward

- Claim an **experience reward** once every 23 hours
- A notification is automatically scheduled for the next available claim

### Footer

- Displays the user's **level**, **experience points**, and **progress bar** towards the next level
- Shows the user's **profile picture**, which can be tapped to navigate to the Personal Preferences tab

### Settings Drawer

#### 1) Personal Preferences

- **Change app theme color** with a color picker
- **Change profile picture** with cropping and compression
- **Customize username** with server-side uniqueness checking (case-insensitive)
- **Set nutrition goals** (calories, protein, carbs, fat, weight goal)
- **Toggle notifications** on or off

#### 2) About The Developer

- Information about the creator behind Level Up!

#### 3) Install PWA App

- Install Level Up! as a **Progressive Web App** for a native app experience
- Includes a manual installation guide for non-Chromium browsers
