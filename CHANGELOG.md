# Changelog

Developmental progress by date is stored in this file.

## 2025-08-01

- First day of development
- Created header and footer sections of the Home Screen
- Learned about different widgets and started adjusting to using Dart
- Created basic outlines of the app (e.g., "Level Up!" appears in the Header, and the Experience Bar appears in the footer)

## 2025-08-02

- Began development on the Home Screen's body section
- Added a button that will lead to a separate screen
- Wrapped the Home Screen in ScreenUtilInit to keep font sizes consistent on different screen sizes (not yet implemented)

## 2025-08-03

- Used ScreenUtilInit instead of MediaQuery for screen resizing
- Added remaining buttons to the body of the Home Screen

## 2025-08-04

- Renamed the Food Tracking button to Food Logging
- Added route functionalities so clicking a button changes the screen to the appropriate .dart file
- Added animations when changing screens (using PageRouteBuilder)

## 2025-08-05

- Started working on the Personal tab
- Added two buttons, "Update your Information" and "Calorie Calculator"
- "Update your Information" planned to be a dropdown menu

## 2025-08-07

- Added an AppBar to the Personal tab so the back arrow in the top left corner is visible and functional
- Applied the style from the Personal tab to all other tabs

## 2025-08-08

- Started working on the Calorie Calculator tab
- Added a few options, and variables to hold those options
- The chosen options will calculate how many calories the user should consume to reach their goals

## 2025-08-09

- More input options added to the Calorie Calculator tab
- Information about activity levels added, aiding the user in choosing the correct activity level
- "Get Results" button added, leading to the screen which shows the user their results
- Validity check added to the "Get Results" button (W.I.P), so the screen only changes when the user fills all fields out
- If the user does not fill all fields and clicks the "Get Results" button, a SnackBar notifies them to do so
- A flag variable is used to prevent SnackBars from stacking if the button is repeatedly pressed without all fields filled out

## 2025-08-10

- Added the option to select units and input height in the Calorie Calculator tab
- The height prompt Shows centimeter values when metric is chosen and foot and inch marks when imperial is chosen
- Height is stored in inches and converted and rounded to centimeters
- If the user has Imperial selected, it visually shows the option in feet and inches based on the heightInches variable
- Made metrics the default value to prevent errors if the user selected height before units
- Made the default metrics value have its own string name, "MetricDefault" so the "Enter your units" prompt would not automatically show the "Metrics" value
- Added a dropdownValue variable to prevent an error caused by the "Enter your units" dropdown expecting an option called "MetricDefault". MetricDefault is simply set to null in this case.
- Planning to automatically convert if the user changes units after selecting height (not currently implemented)
- Results class was moved to its own file
- Added the option to select which calorie equation to use (Harris-Benedict or Mifflin-St Jeor)
- Added the option to enter weight via typing

## 2025-08-13

- Made the Calculator tab "scrollable" to make Column expandable and prevent pixel overflow when the popup keyboard for inputting weight was opened
- Renamed the title for the Calorie Calculator tab from "Calories" to "Calculator"
- Underlined "Enter your weight" to appear consistent with the other options
- Added a regular expression to weight input so only valid doubles can be entered with 0 or 1 decimal points
- Reset height if units were changed after a height was input to avoid errors
- Passed the variables from Calorie Calculator to the Results tab to access them for calculations
- Stored the user's input weight into the weight variable
- Updated the validity checks to be functional, so the Results tab can only be entered when all fields are filled
- The Personal tab was deleted and replaced with the Calorie Calculator tab, and "Update your profile" will be available via a separate button
- Learned about using themes to replace the default purple color when interacting with the input weight text. Replaced it with a white color which is more consistent with the page layout

## 2025-08-14

- Passed the user's sex from the Calorie Calculator tab to the Results tab (missed last patch)
- Learned about ternary operators for the Input Weight prompt on the Results screen, showing kg or lbs based on units chosen
- Removed the outer Center widget in the Calorie Calculator tab and stretched the Column horizontally which fixed an issue with dropdown boxes not having equal length
- Improved the look of the prompts by centering their text and making language more specific (e.g., Enter -> Type in, Enter -> Choose)
- Results tab is now scrollable and has a scrollbar so the user knows to scroll
- Results tab provides information on Basal Metabolic Rate (currently only shows the Mifflin-St Jeor formula)
- Results tab shows the general formula for Males, the general formula for Females, and the specific formula for the user
- The calculation for BMR depends on the units chosen by the user
- Used nested ternary operators to show the formula for the Harris-Benedict or Mifflin-St Jeor equations in metric or imperial based on the user's input (8 possible cases)

## 2025-08-15

- Gave more information to the user about their chosen equation for BMR calculation
- Correctly display the Harris-Benedict formula to the user in the units of their choice
- Rewrote the comments within the ternary operators to be clearer (e.g., NOT Mifflin -> Harris)
- Rewrote the CHANGELOG file to make it clearer
- Changing units after entering a height now automatically converts the units instead of just resetting them to null

## 2025-08-16

- Displayed information about Total Daily Energy Expenditure (TDEE) and how it is calculated (Still W.I.P)
- Created a method that calculates the user's BMR
- Updated the README file to more accurately represent the current state of the project
- Added null-coalescing operators when passing variables to the Results tab to prevent crashing when switching units after having had run the calculateBMR() method
- Converted the weight value to a double instead of a string
- Weight now automatically converts to the corresponding unit if the user changes units after having had entered a weight value
- Added a variable called currentUnits which ensures that weight does not keep multiplying itself when the user selects the already chosen units
- Started correcting some miscalculations with the different calorie equations (Will fully fix next commit)

## 2025-08-17

- Fixed all calculation issues with the calorie formulas, making the BMR calculation results much more accurate
- Cleaned up some visuals in the Results tab by spacing out text more consistently
- Learned about the RichText widget to underline headings in the Results tab
- Started wrapping text in the Results tab with the Card widget for better visuals
- Planning to move the "Your TDEE" text to the very top of the screen

## 2025-08-18

- Created helper methods for text widget creation to apply Don't Repeat Yourself principles
    - Led to results.dart being much shorter and easier to read
- Learned about optional function parameters for choosing text decoration with the helper methods being used
- Altered the formatting of the Results tab to look much smoother, separated by underlined title text, and body information wrapped in Card widgets
- Added one more Activity Level option, "Active", and renamed "Very" to "Very Active"
- Created a method to calculate activity level using switch cases
    - Parsed the chosen activity level from a string to a double, used a switch case, and then returned the appropriate double value for the chosen activity level
- The user's TDEE is now displayed using the calculateBMR(), calculateActivityLevel(), and calculateTDEE() methods
- Used VSCode's code formatting keyboard shortcut to clean up the indentation of the code in all classes
- Refactored code in main.dart by replacing all manual button creations with helper methods
- Reimplemented the Header section of the Home Screen as an appBar widget
- Added a gear icon to the Home Screen app bar, leading to the "Settings" tab as a Drawer widget
- Added a visible scrollbar to the Home Screen
- Moved the textWithFont() method in the results.dart file to the top of the file (outside every class) to use that method globally
- Changed the font of the header text from all screens from russoOne to pacifico
- The gear icon is clickable and displays several new options, including "Personal Information", "About", "Contact" and "Donate"

## 2025-08-19

- Completed the Results tab
- Added information on how to lose, gain, or maintain weight in terms of pounds or kilograms, dependent on the user's inputs
- Only shows healthy rates for weight loss / weight gain
- Changed font of the Settings button to pacifico
- Refactored Settings Drawer items code by creating a drawerItem() method, and added a hover color for those items

## 2025-08-20

- Created a backend folder and a backend file, server.py, to handle API usage
- Hosted the project on Render so API calls can be made from outside of the local machine
- Moved buttonText() and customButton() methods outside all classes to be used globally
- Edited the customButton() method to make the destination parameter optional
- Started working on Food Logging UI
- Added a search button, a meal type button (Breakfast, Lunch, Dinner, Snack), and a Log Food button

## 2025-08-22

- Added debouncing logic with a Timer when a user searches up a food so the API is called only when the timer becomes 0
- Created a method that handles the api call by retrieving the URL with the user's search option and showing options to the user
- The method stores the URL of the backend server link (via Render) with the user's chosen input string
- The input string is used as the food to search for
- A foodList variable was created, which is updated every time a URL is successfully fetched.
- The content is displayed on the Food Logging tab under the buttons (under the Row widget) and allows the user to swipe through all the results
- Learned about the InkWell widget, which allows making things (in this case, the user's choice of food) clickable
- Created lists that hold the foods the user chooses for specific meal types (breakfast, lunch, dinner, snack)
- Added a variable called latestQuery that updates every time the API-calling method is called to prevent the possibility of race conditions
- Added a snackbar that appears if "Log Food" is pressed without all fields being filled (similar to Calorie Calculator)
- Added a package to setup API rate limiting (W.I.P)