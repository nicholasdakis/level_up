# Changelog

Developmental progress by date is stored in this file.

## 2025-08-01

- First day of development
- Created the header and footer section of the application
- Learned about different widgets and started adjusting to using Dart
- Created basic outlines of the app (app name in the Header; experience bar in the Footer)

## 2025-08-02

- Started working on the body of the app home screen
- Added the first button of several that will lead to separate screens
- Moved the main screen to a new class, HomeScreen
- Wrapped the app in ScreenUtilInit to keep font sizes consistent on different screen sizes (not yet implemented)

## 2025-08-03

- Used ScreenUtilInit instead of MediaQuery for screen resizing
- Added the remainder of the buttons in the main body

## 2025-08-04

- Renamed Food Tracking to Food Logging
- Added route functionalities to the buttons in order to switch to the appropriate files
- Added animations when changing screens using PageRouteBuilder

## 2025-08-05

- Started working on the Personal tab
- Added two buttons
- "Update Your Information" planned to be a dropdown menu

## 2025-08-07

- Added an AppBar to 'Personal' so the back arrow in the top left corner is visible and functional
- Applied the style from 'Personal' to all other tabs

## 2025-08-08

- Started working on the 'Calorie Calculator' tab
- Added a few options, and variables to hold those options
- The chosen options will be used to calculate caloric needs for the desired inputs

## 2025-08-09

- More options added to the Calorie Calculator tab
- Information about activity levels added
- Get Results button added, which leads to a new Results screen
- The button has a validity check (still W.I.P), which only changes screen if all fields are filled out
- Otherwise, the user is told that all fields must be filled
- A flag is used to prevent snackBars from stacking if the button is repeatedly pressed without all fields filled out

## 2025-08-10

- Added the option to select units and input height in the Calorie Calculator tab
- Shows cm when metric is chosen and foot and inch marks when imperial is chosen
- Height was dealt with by storing height in inches regardless of what the user chose, and converting it and rounding to centimeters. If the user has imperial selected, it visually shows both feet and inches based on the heightInches variable.
- Made metrics the default value to prevent errors if the user selected height before units
- Made the default metrics value have its own string name so the "Enter your units" text would not automatically show the "Metrics" value
- Added a dropdownValue variable to prevent an error caused by the "Enter your units" dropdown expecting an option called "MetricDefault". MetricDefault is simply set to null in this case.
- Planning to automatically convert if the user changes units after selecting height (not currently implemented)
- Results class was moved to its own file
- Added the option to select which calorie equation to use (Harris-Benedict or Mifflin-St Jeor)
- Added an option to enter weight via typing