# Level Up!

**Level Up!** is a health app that makes **fitness** enjoyable by encouraging activity through **experience gain** and **leveling up**. It includes helpful tools, all of which are listed below.

## Availability

- Available at https://nicholasdakis.com/level_up/ on all devices
- Installable as a **Progressive Web App (PWA)** via the browser link for a native app experience

## Wiki

For a deeper dive into the architecture, caching system, backend design, hallenges faced during development, etc. refer to the [Level Up! Wiki](https://github.com/nicholasdakis/level_up/wiki).

## Changelog

This project contains a comprehensive **CHANGELOG.md** file which is updated throughout development.

## Features

**Level Up!** has 6 main tabs:

### 1) Calorie Calculator

- Input information in either **imperial** or **metric**
- Calculate caloric needs using either **Harris-Benedict** or **Mifflin-St Jeor**
- Displays information about **Basal Metabolic Rate (BMR)**, **Total Daily Energy Expenditure (TDEE)**, and **the effects of physical activity on BMR**
- Saves and restores all calculator inputs across sessions using local storage

### 2) Food Logging

- Track food intake across **breakfast**, **lunch**, **dinner**, and **snack** categories
- **Search tab** for looking up foods via the **FatSecret API** with serving size adjustment and automatic macro scaling
- **Barcode tab** for scanning food barcodes via the **Open Food Facts API**
- **Manual tab** for logging custom foods with name, calories, macros, serving size, and a custom unit option
- Full **macro breakdown** (protein, carbs, fat) displayed on each logged food card
- **Recent foods** section that saves the last 30 logged foods locally for quick re-logging

### 3) Explore

- Discover **nearby points of interest** (cafes, parks, gyms, etc.) on an interactive **OpenStreetMap**
- **Check in** to nearby locations within 50 meters to earn **experience points**
- Each location has a **24-hour cooldown** between check-ins
- POIs are cached locally and refreshed when the user moves more than 250 meters
- Confetti celebration on successful check-in

### 4) Reminders

- **Set reminders** with a custom message and date/time
- Receive **push notifications** via Firebase Cloud Messaging when the reminder is due
- **Delete** reminders you no longer need
- Random placeholder messages generated using grammar rules for variety

### 5) Badges

- Be rewarded for **your progression**

### 6) Leaderboard

- Displays the top users sorted by level and experience points
- Shows each user's profile picture, username, level, and XP

## Additional Features

### User Authentication

- **Email/password** and **Google sign-in** support
- **Profile synchronization** across devices
- **Data persistence** for all user progress and settings

### Daily XP Reward

- Claim an **experience reward** once every 23 hours
- A reminder notification is automatically scheduled 23 hours after claiming

### Footer

- Displays the user's **level**, **experience points**, and **progress bar** towards the next level
- Shows the user's **profile picture**, which can be tapped to navigate to the Personal Preferences tab

### Settings Drawer

#### 1) Personal Preferences

- **Change app theme color** with a color picker
- **Change profile picture** with cropping and compression
- **Customize username** with server-side uniqueness checking (case-insensitive)
- **Toggle notifications** on or off

#### 2) About The Developer

- Information about the creator behind Level Up!
- Links to **GitHub** and **LinkedIn**
- **Send Feedback** button that opens the developer's email

#### 3) Install PWA App

- Install Level Up! as a **Progressive Web App** for a native app experience
- Includes a manual installation guide for non-Chromium browsers
