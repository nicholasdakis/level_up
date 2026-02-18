graph TB
    %% -------------------------
    %% Home Screen Layer
    %% -------------------------
    subgraph HomeScreenLayer["Home Screen"]
        Home[Home Screen]
        Calorie[Calorie Calculator]
        Food[Food Logging]
        Explore[Explore]
        Reminders[Reminders]
        Badges[Badges]
        Leaderboard[Leaderboard]
        Footer[Footer]
        Settings[Settings]
        Preferences[Personal Preferences]
        About[About the Developer]
        Logout[Log Out]
    end

    %% -------------------------
    %% HomeScreen → Tabs
    %% -------------------------
    Home --> Calorie
    Home --> Food
    Home --> Explore
    Home --> Reminders
    Home --> Badges
    Home --> Leaderboard
    Home --> Footer
    Home --> Settings

    %% -------------------------
    %% Footer / Settings navigation
    %% -------------------------
    Footer -->|Click profile picture| Preferences
    Settings --> Preferences
    Settings --> About
    Settings --> Logout