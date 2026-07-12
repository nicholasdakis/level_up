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

## 2025-08-23
- Used the limit package to limit API calls on a single device in a single session to 100 per day
- Added attribution to the FatSecret service while in the Food Logging tab, as per FatSecret's terms
- Clicking the "Powered by fatsecret" text directs the user to the FatSecret website

## 2025-08-24
- Created the file global.dart to hold global variables, rather than having them scattered in separate classes
- Created the method createTitle() in global.dart to create the appBar's title text of each screen rather than manually typing the code for each class
- Created a file settings.dart to store the code for the Settings Drawer originally written in main.dart
- Removed all imports that were no longer needed after the changes above
- Started working on consuming tokens via the backend (W.I.P)
- Added functionality to Settings Drawer options. They now lead to their appropriate screens
- Made the start transition of sliding into a new screen an optional parameter to changeToScreen() to customize slide direction
- Settings buttons now transition from left to right

## 2025-08-30
- Moved code of footer section of Home Screen to a new class, footer.dart
- Added the ability to choose an image from camera roll as a profile picture while in Personal Preferences (W.I.P)
- The chosen profile picture appears in the footer of the Home Screen
- The app now displays the name 'Level Up!' on the user's phone home screen instead of level_up
- Downgraded java version from 24 to 17 due to incompatibility errors in build.gradle.kts (did not fix the errors; ignoring for now)
- Updated the UI of the experience bar in the footer
- Planned to show a user icon if no profile picture is chosen, and the user's chosen profile picture otherwise

## 2025-09-01
- Changed the button style of "Enter your profile picture" to match with other app buttons
- Fixed app crashing when user clicked the button to edit profile picture but exited without selecting one
- When the user selects an image, it is stored in a private variable, \_selectedImage and in a public global variable, selectedProfileImage
- main.dart imports personal_preferences.dart to directly use that global variable
- insertProfilePicture() moved to main.dart
- HomeScreen was changed from a Stateless to Stateful Widget (for UI changes in the footer)
- insertProfilePicture() is called to return the appropriate Widget, and that Widget is used in buildFooter()'s parameter to build the appropriate Widget for the profile picture
- Added a voidCallback in personal_preferences.dart to notify the HomeScreen when the profile picture has been updated
- Updated buildSettingsDrawer() to optionally take a voidCallback parameter, which is used by the Personal Preferences Drawer
- When HomeScreen calls buildSettingsDrawer(), it rebuilds its UI if a callback has been received

## 2025-09-03
- Added food categories for meal types in Food Logging
- Added a card that updates under the appropriate category when the user tracks a food in that category
- Used foodList (the list returned from the API) as a flag (foodList.isNotEmpty) to display search results in place of the food category sections, preventing them from appearing above or below the category text

## 2025-09-06
- Integrated Firebase CLI into this project
- Created a Firebase project and linked it to this application
- Setup Firestore rules
- Added a snackBar popup to notify when the user updates their profile picture
- Added a "Log Out" button in the Settings drawer

## 2025-09-07
- Moved the HomeScreen class from main.dart to a new file, home_screen.dart
- Created register_or_login.dart to be used as the welcoming screen for user registration / logging in
- Created auth_gate.dart to determine if the user should be redirected to register_or_login.dart if not logged in, else home_screen.dart
- Created auth_services.dart for authentication

## 2025-09-13
- Added fields for entering email and password for Registration / Login on the Welcome screen
- Added functional Register / Login buttons on the Welcome screen
- Caught error messages from failed registrations / logins and displayed them to the user

## 2025-09-17
- Created user_data.dart to store user-specific data (experience, profile picture, etc.)
- Added a global currentUser variable in globals.dart for easy access across screens
- Updated PersonalPreferences.dart: imageFromGallery() now stores the profile picture URL directly in Firestore for persistent profile pictures
- Removed selectedProfileImage; profile pictures are now accessed directly from currentUser.pfpUrl
- Updated HomeScreen.dart: insertProfilePicture() now loads the profile picture from currentUser.pfpUrl and shows a default icon if null
- Enabled Firestore in the Firebase console to store user data
- A problem I faced: Removed Firebase Storage usage to avoid billing issues; all profile pictures are handled via Firestore
- The problem was resolved by converting the profile picture to a Base64 string and then retrieving that

## 2025-09-17 - 2025-09-22
- Troubleshooting issues with the project not running after attempting to move it out of OneDrive due to OneDrive interfering with the "flutter clean" command
- Tried many things, including copying over the project into a new Flutter project, updating Flutter SDK, rebuilding the project, moving the Flutter SDK, downgrading Java version, trying to rebuild the project via flutterbase, rewriting the .kts files dozens of times, etc...
- Simplest solution seemed to work: Copied the build.gradle.kts, app/build.gradle.kts and settings.kts files from the last pushed version of the app on GitHub

## 2025-09-22
- Updated firestore rules to allow users to write their own data (i.e. update their profile picture)
- Used 'dart:convert' import for decoding the Base64 profile picture
- Updated the insertProfilePicture method to use base64Decode() (part of dart:convert)
- Same changed were made in footer.dart, so the footer circle properly shows the new profile picture
- buildFooter takes selectedProfileImage Widget instead of currentUser
- Converted footer.dart to a StatefulWidget and added a ValueListenableBuilder to rebuild the footer when the profile picture is updated
- Footer() updated to take insertProfilePicture()'s result as an argument
- That result is stored in footer.dart as profilePicture
- profilePicture is set as the child of the footer's circle to show the up-to-date profile picture
- Updated currentUser appropriately in loadProfilePicture() as it was being reinitialized to empty every time the app restarted, causing persistent profile pictures not to work
- Added the InkWell Widget inside the ClipOval of the footer to make the profile picture clickable. Redirects the user to "Personal Preferences" tab when clicked

## 2025-10-04
- Created an "Explore" tab for a new way to gain experience points
- Imported google_maps_flutter to implement the Google Maps API into the project
- Imported geolocator to get the user's current location to set as the initial point of the map implementation

## 2025-10-05
- Added a card on the 'Explore' tab that appears in the upper-middle part of the map
- The card is for showing nearby experience spots
- The card can be clicked to expand / contract it
- The card will show the generated experience spots for the user to visit

## 2025-10-21
- Moved profile picture logic from home_screen.dart into user/user_data_manager.dart for refactoring purposes
- Added level and experience fields to the user's data. The default level is 1.
- Changed loadProfilePicture() to loadUserData() to load profile picture, level, and experience with the same call
- Moved logic for storing profile picture to Firestore from personal_preferences.dart into user_data_manager.dart for refactoring purposes
- Created a formula for calculating level experience needed: 100 * 1.25^(current_level-0.5) * 1.05 + (current_level * 10)
- Added text on the experience bar that shows experience progress to the next level

## 2025-10-22
- Added a snackbar for popup for caught errors to updateProfilePicture()
- Created an updateExpPoints() method
- Used a ValueNotifier for rebuilding the Footer UI when experience points are updated (Was having issues / confusing using VoidCallbacks)
- Added a blue visual indicator in the footer based on XP progress to the next level
- Added text that show's the user's level under the Profile Picture in the footer

## 2025-10-24
- Made the Explore tab map accessible when opening the app through the web
- Added a theme in main.dart to remove the automatic purple underlines / text in text boxes
- Added a username field for the user's data
- Added a button in Personal Preferences for updating username. All usernames must be unique, and the default username is the user's UID
- Usernames can be updated to modify capitalization. E.g. john to John
- Changed button and header fonts to dangrek
- Automatically store newly-created user data to Firestore upon account creation
- Added mounted checks before setState() methods in register_or_login.dart to prevent crashes due to the line above
- Experience formula updated to be rounded to a multiple of 10
- Edited Firestore rules to allow writing username changes
- Added a note under the "Profile Picture" button saying to wait for the confirmation snackbar before exiting the Personal Preferences tab
- Created an index on Firestore that sorts level and expPoints in descending order (for Leaderboards)
- Loaded users by level and expPoints to create the Leaderboard tab
- First place gets gold text, second place gets silver text, third place gets bronze text, all others receive white text
- The Leaderboard tab shows each user's position, profile picture, username, current level, current experience, and experience required to level up

## 2025-10-26
- Added an input box in the Reminders tab

## 2025-10-29
- Added an optional onPressed voidCallback and onPressed() logic code to customButton() to handle onPressed()
- Added a cupertino-style date and time picker for the Reminders tab
- Used the logic from the "Log Food" button to add a "Set Reminder" button in the Reminders tab
- Setup permissions for notifications in the AndroidManifest and AppDelegate files
- Added a package for retrieving the user's local timezone
- Initialized the notifications plugin during app startup in main.dart
- Added an import for requesting notification permissions cross-platform
- A notification should have been sent based on the time the user picks the reminder to appear at
- Major problem I faced: Notifications were not working on the Xiaomi phone I was testing on due to strict background killing
- Solution: Firebase Cloud Messaging to send the Notifications themselves
- Problem: Firebase Functions required paying, so had to revert these changes
- Troubleshooted and realized the notification testing was making all notifications send in 30 minutes, which is why nothing appeared (as opposed to believing it to be strict OS properties of Xiaomi phones)
- Fixed by scheduling the notification to the exact chosen time
- Instead of attempting to default to 30 minutes into the future if no time is chosen, a snackbar appears prompting the user to enter a time
- Added validity checks to prevent reminders in the past being set
- Updated the README file to make it much more informative and visually pleasing
- Updated the font of the Results tab to be consistent with the other titles

## 2025-10-30
- Added donation handling to the Donate page
- Used the flutter_svg package to show the PayPal button logo in high quality
- Deleted the Donate tab and instead added it as part of the "About The Developer" tab
- Added a description of the developer with a placeholder picture
- Added a "Send Feedback" button that redirects to the developer email for sending feedback
- Added the PayPal logo as a clickable redirect to the donation page
- Added a confirmation dialog popup after "Log Out" is pressed
- Changed the font of "Settings" to match the other titles

## 2025-10-31
- Replaced russoOne font with manrope font
- snackBar theme updated to match the gray theme of the app
- Added a black border around the profile picture in the footer
- Created claimDailyReward() method and canClaimDailyReward and lastDailyClaim variables for adding daily rewards
- claimDailyReward() updates the variables if a claim can be made, otherwise it sets canClaimDailyReward to
- There is a 23 hour period between each daily reward claim
- Updated loadUserDate() to properly handle new fields being added to existing users (adding that field to the user's database)
- Popup dialog appears when the user opens the Home Screen and an XP reward can be claimed
- Daily XP given is somewhat random and based on the user's level

## 2025-11-01
- Updated loadUserData() to correctly handle the canClaimDailyReward variable (the variable was never being set to true before)
- Updated the check in daily_rewards.dart to check the stored canClaimDailyReward variable instead of the local one
- Removed the check from daily_rewards.dart as it was redundant. Applied the changes above to the check in home_screen.dart
- Reordered logic in loadUserData() to stop additional Daily Reward dialog boxes. The problem was that lastClaim = currentUserData?.lastDailyClaim was being assigned before lastDailyClaim's correct value was loaded into currentUserData
- Refactored code by moving notification and timezone setup into its own file, utility/notification_setup.dart
- Scheduled a 23-hour notification upon claiming a Daily Reward
- The reminder contains some random possible messages for the claim messages
- Removed redundant code that stored new user data to Firebase, as it is all handled in loadUserData()
- Fixed a bug where the Leaderboard showed the UID of unnamed users on the leaderboard instead of the username "Unnamed". The problem was that uid is not stored as part of each user's account data, but the code treated it as such => Added a field for each user that extracts their doc.id as a field called uid.

## 2025-11-02
- Updated exact alarm / notification permissions for Android 12+ and Android 13+ (Reminders were not being scheduled on Android 13+ before)
- Updated the logic for updating profile picture to make sure the file is under 1 MB when converted and stored as a Base64 string
- Made the confirmation snackBar for Profile Picture updating only appear when the update is explicitly valid (using a flag variable)
- Added a yellow tint in the Leaderboard tab if the user is looking at their own profile
- Created a ReminderData class to persist the reminders the user sets. Each user now has a reminders field which is a list of ReminderData objects
- This is used to show a table of upcoming reminders using the DataTable widget
- Allows deleting reminders (using their notification ID)
- loadRemindersFromFirestore() method added which gets the "reminders" collection for each specific user. Loaded into the currentUser variable's data when loadUserData() is called on initialization
- The reminders for the table are sorted chronologically, then the table is built with the sorted list
- Updated Firebase rules to let users write their own reminders subcollection
- Each reminder is removed from the list after the time for it passes

## 2025-11-19
- Installed firebase-admin so Python backend code can interact with Firebase
- Created a collection in Firebase called rate_limits and a document called food_logging (goal is to reimplement rate limiting to work persistently across different users)
- Rewrote token_manager.py to store token changes to and from firebase for keeping track of rate limiting
- Removed the local limiting RateLimit import from food_logging.dart
- Fixed firebase timestamp handling to handle DatetimeWithNanosecond objects
- Added token refunds to server.py if an API call fails
- Push commit to test how it works when Render has the updated backend code (Worked after a couple of changes for Render deployment)

## 2025-11-21
- Created an apiTokensCheck() method to update a boolean to true if there are no API tokens left
- If true, red text is displayed informing the user
- Created a get_next_reset_time() in server.py to use to calculate how much time is left until tokens reset (time left = next reset time - current time)
- Updated the json for Token limit to also include the next reset time and the time until next reset time
- Pushed commit to update Render with latest backend code
- Integrated Google Firestore client with explicit service account credentials loaded from environment variable GOOGLE_APPLICATION_CREDENTIALS_JSON
- Replaced default Firestore authentication with service account JSON parsing to avoid deployment errors on Render
- Token limit status code changed from 500 to 429 (too many requests)
- Added snackbar flag logic to the token limit snackbar
- Pushed commit to update Render with latest backend code
- Snackbar was not showing up during conversion. Solution: Simply use time_left from the json as a string and format that string in a method (based on # of colons for differentiating time/hours/mins)
- Then realized colon count is always 2 (00:00:10 is just seconds but still 2 colons => Converted the segments to integers, then only showed the segment if it was >0)
- Removed the apiTokensCheck() method and corresponding flag as the snackBar is sufficient
- Removed dotenv imports from server.py and token_manager.py
- All references to the environmental variables are now through Render.com
- Slightly increased timer before api calls (now 750ms)

## 2025-11-25
- Changed the UI of the customButton widget to appear more modern
- Used the colorpicker import to allow the user to choose an app theme color
- Changed firebase-related code to store the app theme color to Firebase
- Added a simpleCustomButton widget to make the customButton code more reusable (without requiring all its constructor needs)
- Changed code of manually-created buttons to use the simpleCustomButton widget
- Modified user_data_manager and user_data to handle an appColor variable and store it to Firestore
- Added a callback so the HomeScreen gets rebuilt when a new app color is chosen
- Got confused with this approach (wasn't working) so used a ValueNotifier instead
- Changed hardcoded gray colors from each class to the new dynamic ones (still WIP for some hardcoded values and Dialog boxes)

## 2025-11-26
- Continued changing hard-coded gray-colored components, like cards, dialog boxes, buttons, to the dynamic app theme colors
- Changed the app theme colors in main.dart from gray to the dynamic app theme colors
- Added a "Reset Theme" button in App Theme Color chooser to revert to the default theme color
- Changed default theme color from Blue to Gray
- Reformatted the App Theme Color dialog box (equal spacing between action buttons, custom font for "Pick theme color" text)
- Made updateAppColor() calls async to fix bug where confirmation snackbar didn't appear
- Added backgroundColor attribute to confirmation snackbar so it would show the correct snackbar color
- Added a flag isDefaultColor to conditionally make the snackbar mention whether the snackbar was reset to the default value or not
- Removed the alpha slider from theme color picker as it is unneeded
- This caused the visual circle showing the alpha level to remain and appear awkward. This was handled by setting the alpha value of the base color to 255
- Now, the circle serves as an indicator of the color the user is choosing
- Added a custom ScrollBehavior (NoGlowScrollBehavior) to remove awkward darkening of buttons when scrolling to the very top / very bottom of the home screen

## 2026-01-19
- Removed the weightNeverChanged flag in CalorieCalculator, replacing it with a previousUnits variable
- Used the previousUnits variable to fix issues (double-counting weight, not converting weight) with changing units while already having a number entered for weight
- Added a keepValueInRange method to prevent a crash with height conversions giving values outside of the dropdown button values (e.g, wanting to convert to 99 when the minimum is 100)
- Added text to specify weight units (kg / lbs) in the weight input tab of Calorie Calculator

## 2026-02-01
- Edited food lists to also store nutritional data instead of only food names
- Added foodDataByDate as a user variable to store / load logged foods across different days
- Edited loadUserData() to handle foodDataByDate and added an update variable for storing this variable to Firestore
- Added FutureBuilder in Food Logging so the screen loads until the food data is available
- Added currentDate variable with complementary arrows for easily changing the displayed date
- Updated logging method to handle more data about the food instead of just the name
- Added a method to extract calories from the API using a regex
- Added a getTotalCaloriesForDay() method
- Added temporary text in Food Logging for showcasing the total calories for the day

## 2026-02-17
- Stored calculateBMR() result into a variable rather than recalculating it several times in results.dart
- Removed unused screenHeight and screenWidth parameters from sendFeedbackButton()
- Added a dispose() call for username controller in personal_preferences.dart to prevent memory leaks
- Placed repeated code in personal_preferences.dart into applyAppColor() method
- Added a buildDropdown() helper method in calorie_calculator.dart which removed ~250 lines of code in the class
- Replaced SingleChildScrollView and Column with ListView.builder to improve performance for large leaderboards
- Added StreamBuilder to leaderboard.dart for real-time updates to the screen rather than manually calling loadLeaderboard()
- Decoded profile pictures in leaderboard.dart are now cached to avoid decoding them on every rebuild
- Added expCache and memoized experienceNeededForLevel() to prevent the same recalculations for equal levels in leaderboard.dart

## 2026-02-18
- Made mermaid diagrams that show the flow / architecture of some classes
- Added the corresponding code and diagrams in the assets folder

## 2026-02-19
- Removed token resetting route from backend code to prevent possibility of exploiting token resets
- Added more comments to token_manager for clarity and removed the reset_tokens method as it is unneeded
- Upgraded Food Logging table UI
- Used ExpansionTiles instead of static cards for displaying different food categories, allowing collapsing and expanding specific food categories
- Added calorie count under logged foods
- Used the Dismissible widget to make logged foods removeable by swiping the food to the left
- Each logged food creates a key that uses the index, food name, and food type, and this key is used for deletion via the Dismissible widget

## 2026-02-22
- Created responsive.dart utility class for scaling differently when the user is not on mobile
- Changed methods in globals.dart to utilize responsive.dart and raw screen size for calculating the size of widgets
- Changed lines of code in all classes to take the correct new arguments of their globals.dart methods
- Changed lines of code in all classes to use the Responsive class for text scaling
- Adjusted code in classes to make buttons and the footer section look more natural on desktop

## 2026-02-23
- Continued changing values of widgets to create a more natural look responsively
- Continued replacing mobile-friendly screen adjustments with their responsive replacements, essentially fixing all screens for desktop use
- Updated simpleCustomButton to work more similarly to customButton after responsive updates
- Spent a long time trying to find workarounds for food API table not appearing on desktop only to realize it was CORS related
- Created deploy.yml to automatically update GitHub pages version of the project on pushes

## 2026-02-24
- Continued making the UI responsive
- Created a darkenColor method because before: Used higher alpha on body bg and lower alpha on header bg. After: no alpha on body bg and darken header bg.
- Leaderboard tint made less prominent
- Add text to show current version of app

## 2026-02-25
- Updated README
- Made updateUsername return a bool instead of void to conditionally pop the update username dialog box
- Made the update username dialog box use a different BuildContext as to not pop the BuildContext parameter of updateUsername()
- Turned the update username dialog box into a free method to be reused in initializeUser for users with no username

## 2026-02-26
- Created confetti.dart as a utility file to store different confetti decorations for various occasions
- Wrapped HomeScreen in Stack widget so the confetti widget is always ready for use
- Added a ScrollController to the Scrollbar in HomeScreen to fix an exception ("Scrollbar's ScrollController has no ScrollPosition attached") caused by the Scrollbar and SingleChildScrollView not sharing a ScrollController
- Edited the daily reward dialog logic to take a ConfettiController and play the confetti when a daily reward is claimed
- Added dispose() to HomeScreen to prevent memory leaks

## 2026-02-27
- pickProfileImage updated to handle if the user is on desktop by reading bytes directly from XFile (mobile uses File)
- canUpdateProfilePicture updated to also handle desktop
- Changed the weight inputting Regex to use TextInputFormatter.withFunction so invalid characters would not register as opposed to clearing the text
- Updated the weight input Regex so users cannot enter extremely high values

## 2026-02-28
- Removed unnecessary comments
- Continued replacing fixed-size widgets with their responsive versions

## 2026-03-02
- Created settings_icon_button.dart and redesigned the settings icon as it looked strange before
- Made a lightenColor method to use with darkenColor for gradient handling
- Made a buildThemeGradient method to make header and body colors more interesting
- Did this by wrapping the Home Screen's entire contents in a Container with a gradient background, setting the body’s original backgroundColor to transparent, and applying a slightly transparent overlay to the header to maintain visual distinction

## 2026-03-03
- Fixed error snackbar for profile picture showing bytes instead of MB
- Added compression methods for web and mobile to allow profile pictures with larger base file sizes
- Web compression method directly takes the bytes, whereas mobile takes the File. This was done to not have to edit canUpdateProfilePicture() parameters
- Added image_cropper package for profile picture cropping on web, Android, and iOS
- Created image_crop_handler.dart as a utility class to isolate all cropping logic from UserDataManager
- Used a blob URL on web to pass image bytes to cropperjs, as sourcePath cannot accept raw bytes directly
- Wrapped the web cropper UI in a StatefulWidget (_CropperDialog) so initCropper() is called in initState(), which is required by the package for cropperjs to initialize correctly
- Added a cancel button and snackbar messages upon crop cancelling to prevent profile picture updating in this case
- Added a check to see if the user is both on web AND mobile for the image crop handler class to fix UI issues that made cropping not work (now skips customDialogBuilder if on mobile web)
- Added resizing on mobile web because cropping would only work on specific images that were small enough. Did this in an attempt to prevent cropper js from not working with larger images
- Moved confirmation snackbar for profile picture updating into updateProfilePicture to prevent it from appearing upon cancelling cropping on web mobile
- Removed the boolean check in pickProfileImage because that check is already done in updateProfilePicture()

## 2026-03-07 - 2026-03-08
- Attempted using FlutterKronos and NTP packages for server-side time -> did not work on Web
- Switched to Firestore timestamps to handle reading and writing time so users cannot manipulate device time for daily rewards
- Created serverTime collection to store Firestore timestamps
- Edited Firestore Rules to allow writing to the serverTime collection
- Fetched lastDailyClaim directly from Firestore instead of using local instance to prevent tampering
- Added nextAllowedClaim variable that compares against the Firestore timestamp instead of using 23 hours after DateTime.now()
- Each time loadUserData() or claimDailyReward() is ran, the serverTime collection's currentServerTime field gets overwritten with a fresh Firestore server timestamp, which is then compared against lastDailyClaim to determine if 23 hours have passed
- Refactored HomeScreen by moving initializeUser() components into sub-methods
- Used a try finally block in the showUsernameDialog to ensure the controller is cleared to prevent memory leaks
- Stored appColorNotifier's listener into a variable to dispose of it after use to prevent memory leaks

## 2026-03-09
- Added dispose() methods for controllers that did not already have them to prevent memory leaks
- Created a signInWithGoogle() method
- Added a Continue With Google button in Register or Login tab
- Enabled Google sign-in on Firebase console
- Fixed the request not going through by disabling Application Restrictions on Google Cloud

## 2026-03-12
- Edited the signInWithGoogle method to force the Google account picker to appear (using setCustomParameters()) even when the user is already logged in to ensure the user logs in with the correct Google account
- Added a "Reset Password" button to Register or Login screen
- Removed unused imports
- Realized that creating an account with email and password -> logging with via Google with that same email -> logging in with email and password caused a login error. This is fixed when the user resets their password, as Firestore links both their email / password and Google login as valid login methods. Added a specific notifyingMessage to explain this
- Added shading to the "Log Out" button and made its hoverColor consistent with drawerItem() items
- Removed backgroundColor attribute from App Theme Color snackbar so it shows the correct snackbar theme color
- Wrapped main.dart in ValueListenableBuilder so the entire theme rebuilds whenever the user changes their color instead of only rebuilding individual widgets
- Softened gradient colors
- Added gradient colors to all other screens
- Overhauled Calorie Calculator UI by wrapping buttons in a Container with a matching bottom border and replacing hardcoded pixels with responsive variants
- Overhauled Results tab by adding the user's content first, using fonts consistent with the rest of the app and reducing text amount.

## 2026-03-21
- Added an app logo that handles Android / iOS using the flutter_launcher_icons package, and Web by manually changing the favicon image
- Added the hidePassword variable to allow showing and hiding input password text

## 2026-03-23
- Replaced Google Maps implementation with OpenStreetMap (latter is fully free)
- Added a marker to the show the user's current location
- Added a back button in the Explore tab
- Used the Pointer Interceptor package to make widgets on top of the map clickable
- Changed the Nearby Spots widget to not have the Card be edited by AnimatedSize, as this made the Card lose its rounded borders
- Fixed by replacing Card with AnimatedContainer that has rounded borders
- Made sizes in explore.dart use Responsive class instead of hard-coded values
- Made a spotText method to easily give the nearby spots on the Widget have the right font / size
- Aligned the Nearby Experience Spots in the top center instead of padding it from left and right into the center, as this caused pixel overflow on mobile
- Wrapped the Nearby Experience Spots widget in a ConstrainedBox to limit its max width
- Edited width method in Responsive class so that on smaller screens the width cannot take the entire screen
- Made the Back button in Explore tab appear lower on mobile so the Nearby Spots widget does not appear on top of it

## 2026-03-24 - 2026-03-25
- Refactored footer.dart by creating helper functions for building the footer's contents
- Replaced calculated vertical centering on the profile picture with explicit top: 0 positioning
- Wrapped the inner exp bar Stack in a SizedBox to explicitly constrain the hit-test area as the profile picture hitbox was not fully accurate before

## 2026-03-27
- Added normalizing to food logging queries both client-side and server-side to prevent unnecessary API requests (e.g, "chicken", "Chicken", " chicken" all become "chicken")
- Changed hard-coded gray background to responsive app color for dropdown items in Calorie Calculator
- Created a fcmTokens user variable as an array so tokens across multiple devices can be stored for the same user
- Made methods for adding, removing, and initializing FCM tokens

## 2026-03-30
- Replaced flutter_local_notifications with FCM for cross-platform notification support
- Added notificationsEnabled user variable and fcmTokens array to store tokens across devices
- Created firebase-messaging-sw.js and registered it in index.html to handle background notifications
- Added APScheduler and firebase_admin to server.py, runs send_due_reminders() every minute, querying the reminders collectionGroup for due reminders, sending FCM notifications via firebase_admin's messaging module, then deleting them
- Reminder dateTime now always stored in UTC for consistency with the backend
- Added a dialog on the Reminders screen prompting the user to enable notifications if they haven't
- Added a shared showBrowserBlockedDialog() that warns users their browser is blocking notifications, shown on startup and when enabling notifications from the Reminders screen
- Fixed requestPermission() hanging on web when the browser silently blocks the dialog, skipped on web as getToken() handles permissions natively
- Fixed race condition where initializeFcmToken() wrote a partial Firestore cache entry before loadUserData() read the document, wiping user stats
- Fixed duplicate notifications by switching to a data-only FCM payload so the browser doesn't auto-show a notification on top of the service worker's
- Backend now auto-removes stale FCM tokens when FCM reports them as unregistered or invalid
- Deleted notification_setup.dart as it is now obsolete (was used for flutter_local_notifications)
- Moved FCM-setup code to its own utility class to clean up Home Screen
- Made Reminders appear as individual cards instead of one list
- Changed the UI of the Reminders tab to appear more modern with the frosted glass effect
- Added a formatDateTime method to show the date and time of each reminder clearly to the user
- Used grammar-based generation for Reminder ideas to give some random ideas to the user. Also added some "before (user's next hour)" options to make the text feel personalized.
- Fixed a visual bug of the Reminder time showing UTC time instead of converting to the user's timezone (had no impact on backend)
- Made FCM token initialization wait for user's data to be loaded first to prevent potential race conditions
- Tried using JS interop to get FCM token on web to fix missing tokens on deployed subdirectory builds
- Added VAPID key and JS interop getWebFcmToken to properly fetch FCM tokens on web
- used JS_Interop package to use the JS methods from Dart
- Added Firebase SDK scripts and JS Firebase initialization to index.html
- Edited the Browser Notification dialog to now ask the user for notification permissions via the js interop
- Changed the Browser Notification dialog to let the user enable Browser Notifications via a Confirm button rather than telling the user to manually enable notifications
- Changed Reminder ID calculation to prevent potential conflicts
- Moved showBrowserBlockedDialog to Reminders tab

## 2026-03-31
- Made onMessage (which handles foreground notifications) functional instead of just debug printing
- Reminders fire up to a minute late with a cleanupThreshold, so edited loadReminders() to only delete reminders when they've actually been fired
- Made messages with notification payloads return to prevent duplicate notification messages
- Fixed web foreground notifications by handling onMessage directly in JS (Flutter SDK's onMessage doesn't fire when the token is obtained via JS interop)
- Update getWebFcmToken to only call the notification request if user explicitly allowed so
- Replaced APScheduler w/ a route as gunicorn does not handle apschedulers well
- Made a cron job to keep the send_reminders route up and running every minute
- Added better error messages for iterating through the user's fcm tokens
- Removed the early return for payload.notification in case this was silencing the notification
- Fixed the app using the wrong service worker by specifically making it find the custom one. There are now two service workers (default flutter one and custom firebase-messaging-sw)
- Imported the default SW into the custom one so that there is only one single SW
- Edited flutter_bootstrap to not automatically call load(), so that load() is called by the firebase-messaging-sw SW instead of the default one
- Added notification toggle in personal preferences
- Overhauled personal preferences UI
- Added common frosted glass card code into globals.dart instead of remaking it every time
- Made it so a Reminder can't be set if in-app notifications are disabled
- Made it so if the user clicks Reminders while in-app notifications are disabled the disabled in-app notifications popup opens
- Added a notes section for Web users in the Reminders tab

## 2026-04-01
- Added a button in the Settings drawer that allows installing the app as a PWA (using the pwa_install package)
- Fixed uncaught error when Firestore tried to read an empty server time
- Updated the manifest file to show more specific info instead of generic "new flutter project" description
- Make some recent comments more descriptive
- pwa_install only supports Chromium browsers, so added a fallback that leads to a different screen that will show users how to manually install as a PWA (pwa_install_guide.dart is the tutorial screen)
- Made the PWA install button invisible when the app is already installed
- Added Back button tooltip to Explore tab to be consistent with other pages
- Added tooltip explaining what a PWA is in the Install PWA App button
- Edited applyAppColor() to automatically darken a color that would be so light (e.g., pure white) it would make text / cards unreadable
- Added isPwaInstalled and supportsNativePrompt methods in index.html and linked them to dart with JS interops to reliably detect platform to show the correct "Install PWA App" button
- Renamed isdPwaInstalled to isPwa and changed variables dependent on it to be more accurate (it detects if Pwa is opened, not installed)
- Readded hasInstallPrompt because it is now only used if nativeSupported is true, ie only the browsers that have beforeInstallPrompt property will call it
- This did not fix the case where the app was already installed but the browser was not native (e.g Safari), so added a wasEverInstalledAsPwa() function that is stored in localStorage and can be checked
- Added cookies as a fallback to PWA installation detection on non-Chromium browsers becauses cookies share the same context as the PWA and browser tab
- Reverted previous approach as Cookies clear often and it only works if the PWA was downloaded via the same Browser. Could not find a reliable way to genuinely detect if PWA was installed on the device of a non-Chromium user in general (or to detect if the PWA is ever uninstalled). Used a simpler approach instead.
- Removed the "App already installed" replacement text for consistency across platforms. Chromium browsers show a snackbar if PWA is installed, non-Chromium browsers route to the tutorial installation screen regardless
- Moved the notification setup code into a new file, notification_service.dart
- Replaced the flutter_local_notifications setup for daily reward notifications using FCM
- Removed all flutter_local_notifications-related code and initializations as this package isn't being used anymore

## 2026-04-02
- Edited Food Logging to have 3 tabs: Search, Barcode, Manual using TabControllers
- Made barcode scanning format foods in the same way Fatsecret API does
- Using OpenFoodFacts API to handle barcode scanning, so added attribution text as per their terms
- Replaced launchFatSecret() with launchWebsite() and added buildAttribution() to make method reusable for other attributions
- Added methods for building each tab (Search, Barcode, Manual)
- Used consts to link tab index to the name of the tab for readability
- Made a lookupBarcode method that uses the Open Food Facts API to retrieve a food, then formats it like FatSecret foods to preserve existing methods for handling returned foods
- Made a popup appear in the Manual tab if a user tries to log a food without having selected macros (as they are optional, but recommended)
- Added hasActiveInput() to know whether the meal tiles should show or not
- Made a submitManualEntry() method that builds the user's custom meal in the same format as FatSecret so existing regex parsing is preserved
- Extracted repeated ExpansionTile/Dismissible meal display code into a reusable _buildMealSection method
- Extracted food logging logic from the Log Food button's onPressed into its own logFood method
- Fixed a bug where calories stored as the wrong type caused a TypeError in getTotalCaloriesForDay and the meal tile subtitle by using num.tryParse(...toString())
- Added 'calories' directly to the foodObject in _submitManualEntry to avoid re-parsing manually entered calories through the regex
- Updated logFood to skip extractCalories if calories is already set on the foodObject (which is the case for manually logged foods)
- Made DropdownButton2 widgets have appColorNotifier values instead of using dark gray
- Added the frosted glass card widget into Food Logging for a more modern look
- Made a frosted glass button method in globals.dart
- Made the food bars use similar cards to the Reminders tab for a more modern look
- Realized Snacks was being stored as "Snack", so fixed that but kept "Snack" to be backwards compatible
- Added regex checks so users can't type words into the manual entry fields (was not too big of an issue as the fallback made it 0 calories)
- Made the Barcode Scanner button bigger
- Added an additional way to delete logged foods, which is to click a trash can icon
- Used the regex for weight input for the manual entry logging to prevent entering invalid numbers while not clearing incorrect inputs
- Replaced the Log Food and Search buttons in the Search tab, but this broke other tabs that use "Log Food", so conditionally replaced the Search button with the Log button when on non-Search tab bars
- Removed backwards compatibility for "Snack" instead of "Snacks" handling
- Handled the Explore tab card covering the Back button while opened on mobile by using a backButtonOffset variable added to the existing offset mobile code
- Changed the overly complicated color handling for customButton() and simpleCustomButton()
- Fixed the formatting of the home screen buttons to use the responsive sizes for separation and wrapped in padding to feel less
- Made the title text use gradient colors using ShaderMask widget to stand out more
- Liked this approach so made all title screens and button texts use gradient colors using a subtleTextGradient() method to add a slight gradient to prominent text
- Made more visual tweaks to Food Logging to look more natural
- Added the Manual tab of Food Logging all scrollable to prevent the logged foods from barely being visible and to prevent potential pixel overflow errors from the frosted glass card itself

## 2026-04-03
- Replaced the "users" collection with "users-private" and "users-public" collections so that the operation that sorts users in the leaderboard only exposes the user's necessary fields (pfp, name, level...) rather than all their fields.
- Changed the backend code to reflect these changes in relation to fcm token handling
- Made a Python script to migrate the user data to the new collections
- Updated firestore rules so users can read users-public but not users-private
- Replaced the stored food logging implementation because it was all stored in one document that may get too big and exceed Firestore's free limit. Foods are now stored in a new collection, foodLog, that has one document per date
- Updated Firestore indexes to use the users-public collection for sorting the leaderboard (as composite indexes don't work without this, and ordering by level and exp are both needed)
- Made getters for getting public and private user data instead of having to type await FirebaseFirestore.instance.collection('users-public/private') every time
- Made the user's leaderboard tint use their app color instead of white
- Updated leaderboard to use responsive sizes instead of fixed pixel values
- Updated Firestore writes such that they don't trust the client at all, except for trivial operations like updating app theme color or setting reminders etc
- Made auth.py which validates the user's token and returns their UID to ensure the user is who they say they are
- Made schemas.py to prevent badly formatted JSONs from being passed through, so the business logic knows what to expect every time
- Made repository.py as the only class that directly reads and writes to Firestore. When another class needs Firestore data, it gets it from this class
- Made services.py to handle the important calculations, using repository.py to read the user's data instead of Firestore directly
- Added the necessary routes to server.py for claiming daily rewards, updating xp, and getting the user's progress
- Made the routes use POST as they're not for retrieving data, they are for modifying data
- Before, the client directly wrote to Firestore. This meant Firestore trusted the client, and that the client could send any values it wanted
- Now, all requests are directly handled by the backend. The backend decided if a request is allowed to go through or not
- The auth.py file is used to ensure the user themselves is sending the request, if not it returns immediately
- Then, the request is validated using schemas.py to enforce the shape of all requests and responses, protecting the backend from malformed data and making the service layer simpler and safer
- Next, repository.py is used to actually read / write from Firestore. If other classes in the backend need Firestore data, it is done via this class. This is to keep all database-related logic in one file for clarity
- The services.py file contains pure calculations, and includes a ProgressionService class to combine the math calculations with the database operations
- Finally, server.py contains the routes that wires all the layers together when the user makes a request, where the routes are called in the Flutter code when the user tries to update sensitive information that the client shouldn't trust
- The updateExp() route is currently WIP since nothing in the app needs it yet, but it will use events and check Firestore to make sure it can't be exploited
- Updated daily_rewards.dart to no longer call updateExpPoints() because this is now handled by the POST request server-side
- Updated the user_data_manager file to make critical requests use the server instead of the client
- Edited canClaimDailyReward to directly read from currentUserData instead of Firestore, because currentUserData loads the data updated by the backend, which is the most up-to-date version
- The serverTime document was deleted because the daily reward checks are entirely handled server-side now
- Updated firestore rules to reflect the backend changes and why they were made in the first place. A user writing their own xp and level is now impossible, as it is entirely done by the backend
- The locally calculated assigned XP for claiming a daily reward could be different to the actual calculated result in the backend, leading to an inaccurate amount of xp gain being shown to the user. Fixed by making claimDailyReward return an int instead of bool, where that int is the actual amount of xp they gained according to the backend's calculation
- Then updated showDailyRewardDialog to use the actual calculated amount instead of the randomly calculated amount
- Made reminder handling atomic so that the same reminder isn't handled twice before the cleanup happens. Uses a "processing" flag to determine if it is already being handled or not
- Edited firestore rules again as non-critical variables were being blocked from writes
- Made daily reward notifications only send if the user's in-app notifications are enabled

## 2026-04-04
- Realized most requests in the app hang if the user has no connection. This can be fixed for non-critical user data by storing locally and updating later (and giving specific snackbar messages to inform), but for critical data requests that use the data it should reject the request entirely (and show a snackbar to inform the user)
- Used the connectivity_plus package to detect if a user is online / offline to show appropriate snackbars
- Initialized Connectivity as a stream so that it reflects the user's connection in real-time
- Added timeout timers to updates so that requests don't hang and the catch block determines whether that timeout is due to slow connection (timer hitting 0 but connected), or due to no connection, which shows its own snackbar
- Added this logic for all personal preferences-related buttons (app theme color, profile picture, notificationsEnabled) except username, which will be moved to the backend
- Added snackbars for notification prefence updates as they were not added
- Moved the username uniqueness check and update logic to the backend to prevent the client from bypassing it. username_exists was added to repository.py as a read operation, and update_username was added to ProgressionService in services.py, which calls username_exists and only writes if the username is free. Added a /update_username POST route in server.py and added request/response schemas in schemas.py for update username requests and responses
- updateUsername in user_data_manager now calls the backend, and usernameExists was deleted entirely because it is now handled in the backend logic with the username_exists method
- Updated Firestore rules to prevent client-side writes to the username field
- Made unsuccessful username updates return 409 to show the appropriate snackbar, rather than always showing the "Success" one
- Stopped "update username" from hanging if the user had no connection with the same logic as earlier for non-critical fields
- Added timeout fallbacks to get_progress and IdToken to not hang indefinitely
- Made the user data documents load in parallel instead of sequentually in loadUserData() to be a bit faster
- Edited loadUserAndInit in Food Logging to not recalculate loadUserData every single time the tab is opened, instead getting it from currentUserData
- Extracted loadFoodData() from loadUserData so that loadFoodData() can be called upon opening the Food Logging screen without having to rebuild the entire user's data
- Now Food Logging does not load indefinitely when the user has no connection thanks to adding timeouts to get_progress and using currentUserData for all fields except for the food data itself, as that should not be stale
- Added an informational snackbar upon logging a food to let the user know the food has been logged locally and will be added to Firestore when they reconnect
- Added an informational snackbar for when the user tries to search for a food with no connection
- Added a script in index.html that acts as a service worker update check after each deployment. When the user switches back to the app tab, the browser re-fetches the service worker file from the server and compares it to the cached version. Since Flutter embeds a unique hash of all app files into flutter_service_worker.js on every build, the file will always differ after a new deployment. When a difference is detected, the new service worker installs, takes over immediately via skipWaiting(), and triggers a page reload via the controllerchange event, ensuring users always see the latest version without having to manually refresh
- Tried avoiding infinite reloads by using a sessionStorage flag to ensure the page only reloads once per service worker update, and resets the flag on page load for future updates
- This did not work, so just made a banner show up for the user to tap instead of relying on auto-refreshing
- Added a unique identifier to the custom SW to force it to detect a change upon new pushes
- Removed the banner entirely as could not find a way to make it work consistently and without issues

## 2026-04-05
- Made a LeaderboardEntry class to easily handle leaderboard data by converting Firestore documents into Dart objects
- Made a fromFirestore factory constructor in LeaderboardEntry that parses a Firestore document and extracts its fields into a LeaderboardEntry object so that the default constructor is compatible with the data. The factory constructor also handles decoding the profile picture from base64 once on initialization
- Made a LeaderboardService class with two methods:
  - prefetchLeaderboard() does a one-time fetch on app startup to populate Firestore's local cache, so the leaderboard is available offline even if the user has never opened the tab
  - getLeaderboardStream() returns a real-time stream of leaderboard data, automatically serving from Firestore's local cache if the user is offline
- The StreamBuilder in leaderboard.dart calls getLeaderboardStream() and maps results using LeaderboardEntry objects
- If the user loses connection, the leaderboard still loads from Firestore's local cache. prefetchLeaderboard() is called on app startup to ensure this cache is populated even if the user has never opened the leaderboard tab. If they did open it while online, the stream will have updated the cache with fresher data than the prefetch, so that will be shown instead
- itemCount is capped at 100 to only show the top 100 users

## 2026-04-06
- Realized that since the initialize method only runs on app startup, an fcmToken is only initialized during initial app opening. This explained an issue I was facing with reminders not working when I'd set one after returning to the app after having it minimized for a while
- Since reminders are sent to fcmTokens stored at the time of the send and not at the time the reminder is made, the fix is to refresh the user's fcmTokens if they ever come back to the app and delete the old one
- The backend already deleted invalid fcm tokens in the send_due_reminders method, so no changes were needed for this
- Created a refreshToken method that gets a new fcmToken and adds it to the user's fcmTokens array, ensuring the user always has a valid fcmToken stored when they come back to the app after some time after not having fully closed it
- Made an observer class _FcmLifecycleObserver that calls refreshToken() whenever the user comes back to the app
- The observer is setup in the initialize() method of the fcm helper class
- Made the date in the Food Logging tab clickable, opening a calendar for choosing the date instead of only relying on changing dates one at a time
- Reformatted the date in Food Logging (eg 2026-04-06 is now April 6, 2026)
- Made the date in Food Logging hoverable to emphasize it can be clicked
- Made a CRON-SECRET environmental variable
- The send_reminders CRON job was accessible by anyone, but the CRON-SECRET ensures only the backend can call it
- Updated the get_food route so only authenticated users can call it to prevent anybody, including non-users, from doing so
- Did this by using the same validation used for critical game data (auth.py, schema.py, repository.py, services.py...)
- Moved food search API call into UserDataManager.searchFood() to centralize backend requests
- Moved the "Send Feedback' button to the Settings drawer
- Added serving size tracking to food logging so all three tabs now store and display the serving amount and unit alongside macros
- Added a serving size row to the search and barcode tabs that lets users adjust the amount, with macros scaling automatically to match
- Added a serving amount field to Manual tab and a unit dropdown including a custom unit option via a dialog
- Barcode tab now calls _initServing() on a successful scan so the serving row is pre-populated with the product's per-100g data
- Food cards in all meal sections now show the serving size and full macro breakdown (Protein, Carbs, Fat) instead of just calories
- Moves snackbar logic into a reusable _showSnackbar() method instead of repeating the ScaffoldMessenger block everywhere
- Added _previousTabIndex tracking so tab state only resets when actually switching tabs, not on every tap
- Serving amount is now a required field on the manual tab before Log Food will proceed
- Refactored logFood() to rebuild the food description with scaled macro values at log time for search and barcode entries
- Moved around methods in Food Logging to organize
- Replaced addMenuItem() method with inline .map() conversions
- _decimalFormatter() was added as a shared input formatter instead of repeating the inline TextInputFormatter.withFunction on every manual field
- _castFoodList() helper added to avoid repeating the same cast pattern in loadFoodForDate
Tab switching changed from onTap: (_) => setState(() {}) which rebuilt on every tap to only resetting state when actually changing tabs
- Added an isBeingDeleted parameter to updateFoodDataByDate to handle the "food logged" snackbar appearing when deleting a food

## 2026-04-07
- Made claimDailyReward directly return xp_gained from the backend instead of new-old xp, which would be negative if the user leveled up from the experience gained
- Replaced the Leaderboard stream with a get() to avoid unnecessary Firestore reads
- Added a refresh button for the leaderboard tab to replace the automatic updating
- Fixed the Leaderboard tab header appearing shorter than the other screens
- Fixed cursor showing a pointer when hovering the meal tab entries and in the Search and Barcode tab and not showing a pointer when hovering "Log Food" in the Barcode tab. This was done by using the MouseRegion widget to explicitly show the finger pointer / click pointer when appropriate
- Made the Meal Type entries have the same size and font as the "Meal Type" text
- Used the shared_preferences package to store recently logged foods by the user on their current device as this is convenient and does not require any Firestore reads / writes at all
- Added a buildRecentFoodsSection method that creates an expandable dropdown where recent foods can be clicked to log them again
- If no foods are logged, the dropdown doesn't show, and if there are foods logged, clicking displays each recent food as a clickable frosted card that acts as the "Log Food" button
- Created a helper class for recent foods that initializes the shared_preferences object, has getter and setter methods, removes duplicates, and keeps only the most recent 30 entries
- Implemented JSON serialization/deserialization so the list can be saved and loaded easily from shared preferences
- Added an isLogging variable and timer that prevent accidentally using logFood twice in a row by accident (there is now a 5 second timer)
- Extracted the code that builds the macro text into buildMacroText() so that it can be reused in the recent foods cards
- Edited the buildMacroText() text to also show a macro if it is 0 (e.g. show that a dressing has 0 protein)
- Removed the calories variable because buildMacroText can already extract them
- Replaced Expanded with Flexible for the Recent Foods cards so the name can take 1/3 of the card and the information can take 2/3
- Added a /get_nearby_pois backend route that takes the user's coordinates and queries the Overpass API (via a private.coffee mirror) for nearby amenities, leisure spots, shops, and tourism nodes within 500 meters
- Created an Overpass QL query template that searches for nodes with amenity, leisure, shop, or tourism tags near the user's location
- Added a parse_overpass_response method that filters out unnamed nodes and extracts the name, lat/lng, and category (amenity/leisure/shop/tourism) from each Overpass element into POIItem objects
- If more than 20 named POIs are found, a random sample of 20 is returned to keep the list manageable
- Added a /check_in_poi backend route that lets users check in to a POI for XP, with server-side proximity verification using the haversine formula (the user must be within 50 meters)
- The check-in route enforces a 24-hour cooldown per POI using a poi-visits subcollection under each user's private document in Firestore
- Added a record_poi_visit_transaction method in the repository that atomically records the visit timestamp, checks the 24-hour cooldown, and updates the user's XP and level inside a single Firestore transaction to prevent race conditions
- Created Pydantic schemas for NearbyPOIRequest, NearbyPOIResponse, POIItem, CheckInPOIRequest, and CheckInPOIResponse to validate all POI-related request and response data
- Added a _haversine method to the service layer for the necessary haversine formula (checks spherical distance between 2 points)
- Created a POI model class on the Flutter side with fromJson/toJson for parsing backend responses and caching to SharedPreferences
- Created a POIService class that handles fetching POIs from the backend, caching them locally with SharedPreferences, and only re-fetching when the user moves more than 500 meters from the last cached location
- POIService also handles check-in requests, tracking visited POIs locally with timestamps, cleaning up visit records older than 24 hours, and finding the closest unvisited POI within check-in range
- Nearby Experience Spots now shows actual nearby spots instead of placeholder text
- Each POI in the list shows a visited/unvisited indicator, and visited POIs are dimmed
- Added a confetti celebration that plays on successful check-in, and the check-in button briefly shows the XP gained before resetting
- Fixed a bug where calling mapController.moveTo() before the OSM map controller was initialized caused a LateInitializationError that silently prevented POIs from loading
- Moved the moveTo call into the mapIsReady callback so it only runs after the map controller is fully initialized, and also called _addPOIMarkers there to handle any markers that loaded before the map was ready
- Added an iconForCategory method to make markers match what the POI actually is rather than using a generic marker
- Tried to use Future.wait to load POI markers in parallel instead of using a for loop to do so sequentially, but reverted because it caused iconForCategory to always fallback to default markers
- Added an add_cors_method that runs after every request so CORS headers are also added to unsuccessful requests
- Sanitized poi-visits document names because Firestore doesn't allow all characters (eg "/") in a document's name

## 2026-04-08
- Added a limit of 100 results from the overpass query so the random subset of 20 still feels random without having to obtain a huge amount of POIs
- Added gunicorn.conf.py to stop Render from timing out gunicorn workers after 30 seconds by increasing the timeout to 60 seconds
- Added a fallback URL for the API request so if the first one times out, it tries the other URL instead of retrying with the same one
- Instead of retrying once, it retries as long as there are more fallback URLs to use for the search
- Made the retry consider HTTP errors too instead of only RequestException so that it tries the next URL regardless of the error
- Added onGeoPointClicked to track when a user clicks a marker on the map which displays a card providing the POI's name and info
- Extracted the display category logic for the card as a displayCategory() method to reuse for when the user taps a marker
- Used AnimatedOpacity to make the card fade out instead of just disappearing
- Tested the Explore tab with low Wifi and realized that if it only loads 2 POIs, it will never try to reach the maximum later because it will see the 2 as a valid cache
- Added a _fillCache method that runs in the background after returning cached POIs to check if more POIs are available from the backend and fills the cache if so
- Added an onSupplement callback so the UI updates when the background fill finds more POIs, including re-adding markers and re-checking the nearest POI
- Added a "Finding more spots..." loading indicator at the bottom of the Nearby Experience Spots card that shows while the cache is being filled
- Added an onFillStart callback so the "Finding more spots..." indicator only shows when a background fill is actually happening
- Fixed duplicate POIs appearing in the list after a cache fill by deduplicating using name and rounded coordinates
- Fixed the "Finding more spots..." indicator staying visible forever when the Overpass API timed out by calling onSupplement in the catchError handler
- Tracked which POIs already have markers on the map using a Set to prevent duplicate markers from stacking when _addPOIMarkers is called multiple times
- Reverted the separate time and date choosing format on desktop because using the showDatePicker to select a time felt too precise and annoying
- Moved the placeholder reminder message to init instead of build so that it does not generate a new message on every input change / screen size change
- Made the date picker show up in the middle of the screen
- Removed the three separate exp bar builder methods (buildFooterOuterExpBar, buildFooterLightGrayExpBar, buildFooterFillableExpBar) and replaced them with a single buildExpBar method
- Used padding on a black Container instead of Border.all to create the border, so the inner content area lines up cleanly
- Added a ClipRRect inside the black container to clip both the gray background and blue fill to the same rounded shape, preventing the blue from peeking under the gray

## 2026-04-09
- Updated the UI of the About The Developer tab with widgets like frostedGlassCard that other updated UIs of classes now use
- Added clickable links to GitHub and LinkedIn to the Developer tab
- Moved buildSectionHeader into globals.dart as many classes were using the same code without calling the method itself
- Extracted the repeated code from customButton and simpleCustomButton into frostedButtonShell
- Extracted the shadowing of text into a global helper method textDropShadow
- Created a shared_preferences folder with a SharedPrefsService wrapper class and SharedPreferencesKey constants to centralize all SharedPreferences logic and keys in one file
- Updated RecentFoodsService and POIService to use the new wrapper instead of accessing SharedPreferences directly
- Added shared_preferences implementation to Calorie Calculator so when the user presses "Get Results" with all fields filled, the data is stored in their device's storage
- Added an initState to Calorie Calculator to load the stored data if it exists
- Initially converted all the parameters to strings in setCalorieCalculatorData and then to Map<String, dynamic> but reverted after realizing this wasn't needed due to the dynamic type
- Stopped the map from auto-centering on the user when they move
- Added a button to recenter the camera to the user's location
- Wrapped the Browser Notifications dialog in PointerInterceptor to make it clickable while on the Explore tab
- Moved markedPOIs.add before the await to prevent race conditions where 2 markers were trying to be placed before being added to the set
- Realized the API was sometimes treating the same place as two different locations, so added a seen_locations set to the backend to skip duplicate locations
- Added more POI-specific icons
- Extracted the poi icons switch case into its own poi_icons class to freely make it as long as needed without clogging up explore.dart
- Moved poi-related code into a new poi folder
- Replaced the O(n) switch statement in POIIcons with a const Map for O(1) lookup instead of walking through cases so that adding more markers stays efficient
- Made a mapReady variable so that markers are only added when the map is ready
- Decoupled _addPOIMarkers from the userLocation check in mapIsReady so it fires even if GPS hasn't returned yet. Defensive fix for edge cases where GPS returns before the map initializes
- Instead of doing nothing in the catch block of addPOIMarkers, it now removes the key from markedPOIs so it can be retried. Before, if addMarker failed (e.g. the map was still settling), the key stayed in the set permanently, so that marker was skipped on every future call and never appeared on the map. Now a failed marker gets a second chance when _addPOIMarkers runs again from the onSupplement callback
- Adding padding to the buttons and widgets in the Explore tab so they line up on mobile
- Added a Send Feedback heading and button back to the About The Developer tab for convenience
- Added splashColor with alpha to all instances of InkWell to make ripple effect more subtle
- Extracted arbitrary scaling values into constants in responsive.dart (base screen width/height, tablet/desktop scale factors, breakpoints, font clamps)
- Replaced hardcoded desktop detection logic with a ScreenType enum (mobile, tablet, desktop) for clearer and more scalable device classification
- Added screenType() as a single source of truth for determining device type instead of repeating ratio-based checks across methods
- Added helper boolean methods (isMobile, isTablet, isDesktop) for cleaner and more readable UI condition checks
- Centralized screen size handling into _safeSize() to avoid repeated MediaQuery calls and prevent invalid/zero-size edge cases
- Added unified scaling using _scaleValue() so all scaling logic flows through one method instead of being duplicated per method
- Clamped screen height to 90% like was already the case for width
- Added min/max font size clamps to prevent text from becoming too small or too large
- Reverted font() and buttonHeight() to return the base value on mobile instead of proportionally scaling, which was making them too large
- Edited the Explore tab offset for mobile to not apply to tablet screens
- Moved the padding in the Explore screen to wrap the nearby experience spots card with the back and recenter buttons on mobile without applying padding to the map itself, now containing the buttons neatly
- Renamed backButtonMobileOffset for clarity

## 2026-04-10
- Deleted get_poi_last_visit because record_poi_visit_transaction already handles reading last_visit and is also more secure because it is transactional
- Extracted timestamp, datetime -> utc datetime conversion into a to_utc_datetime method as many classes in the backend folder used that same repeated code
- Added logger to auth.py to record the real error internally to the server while returning a generic message to the client, preventing sensitive info leakage
- Edited the to_utc_datetime method to handle fallback cases
- Used Upstash Redis to host Redis database of foods to serve as a global food cache for all users
- Made a redis_cache.py file that links the Redis DB with the URL and TOKEN in Render
- Added a TTL constant for cached foods of 30 days so that data stays fresh
- Wired the caching to the /get_food route so that it first checks the cache, and if not in the cache it uses the API and adds to the cache
- Added cache_hits and cache_misses as keys in the cache to measure the long-term implications of the cache
- Wrapped the cache search in get_food in a try except block so that if the read fails it falls back to the API instead of crashing
- Added "food:" next to cache keys to clearly separate the cache_hits and cache_misses keys
- Replaced upstash-redis with redis import as upstash-redis does not support lock()
- Added a lock to /get_food before calling the API to prevent the possible race condition where two users search for the same food at the same time
- Now if 2+ workers try to get the food at the same time they must wait for the lock to be free, and the cache is re-checked after the lock is acquired in case the food was added to the cache by a previous worker
- Added a timeout to the API request slightly shorter than the lock's timeout to prevent the case where the API could be very slow and free the lock before the operation had finished
- Added a blocking_timeout that automatically stops the worker from trying if they have been waiting for the lock for too long (to prevent a pileup of workers)
- Extracted the Fatsecret API calling portion into its own method to make the get_food method less dense
- Replaced if redis.exists redis.get with just doing redis.get and using it if it is not None to prevent 2 reads instead of 1
- Made the brand name visible for searching foods with search / barcode

## 2026-04-11
- Made the await calls in loadUserData(), load reminders, fetch progress, and load food data, run in parallel instead of sequentially, saving about 200ms on app startups
- Realized the bigger issue was loading the user documents
- Fixed by setting persistenceEnabled to true, which is false by default on Web
- This allows Firestore to cache the user's data and also allows for offline usage of data which automatically synchronizes when the user goes back online
- Now Firestore serves the data from its cache and only updates if there was a change, speeding up load times
- Added content to the InstallGuide screen with instructions for installing Level Up! as a PWA
- Covers Chromium-based browsers (recommended), iPhone (Safari), and other browsers (e.g. Firefox)
- Added _buildStep() to render numbered instruction steps
- Added _buildSection() to render a frosted glass card with an icon, title, subtitle, steps, and optional extras
- Moved socialLink() to globals and used it in the InstallGuide to add an example of a PWA extension
- Made restoreCalculatorDataFromPrefs() catch possible errors
- Fixed frostedGlassCard using hard-coded values for blurring
- Made the reminder time input show "Enter a time" if no time is picked instead of defaulting to the user's current time

## 2026-04-12
- Migrated the Explore screen's map from flutter_osm_plugin to flutter_map and flutter_map_location_marker because flutter_osm_plugin required async marker placement and a map-ready callback, making the code more complex than needed. flutter_map renders markers as standard Flutter widgets so they rebuild automatically with setState()
- Replaced GeoPoint with LatLng from latlong2 for coordinates throughout the class
- Replaced MapController.withUserPosition() with a plain MapController, since flutter_map handles location tracking via CurrentLocationLayer instead
- Removed OSMMixinObserver from the state class and its associated mapIsReady() override as flutter_map doesn't require a ready callback since markers are just Flutter widgets rendered directly in the build tree
- Removed the _mapReady and _markedPOIs state variables, which were only needed to guard against placing markers before OSM was initialized. flutter_map renders markers as Flutter widgets in the build tree so they're always in sync with state
- Added _buildMarkers() to build the POI marker list as a standard Flutter widget tree, replacing the async _addPOIMarkers() method that imperatively called mapController.addMarker() for each POI
- Removed the _addPOIMarkers() calls from _loadPOIs() and onSupplement since markers now rebuild automatically with setState()
- Markers are now Flutter widgets that rebuild with setState() so they are always in sync with the POI list which should remove race conditions when trying to set the accurate marker icon on the map
- Moved map camera to user's location immediately after getting position with _mapController.move() instead of doing it in mapIsReady()
- Switched tile layer to OSM explicitly via tile.openstreetmap.org with userAgentPackageName set
- Changed user location marker look
- Extended the POI tooltip auto-dismiss delay from 1 second to 3 seconds
- Added a _positionStream that listens to the user's position while the Explore screen is open, firing _loadPOIs() every 250m to match POIService's _refreshDistance. Before, only the initial position was fetched so the POI list and check-in button never updated as the user moved during a session
- Added _positionStream?.cancel() to dispose() so the stream stops when leaving the screen
- Wrapped check-in button text in Flexible to fix pixel overflow on long POI names
- Removed PointerInterceptor because flutter_osm_plugin rendered the map in a native platform view, which caused Flutter widgets drawn on top of it to not receive touch events properly. flutter_map is pure Flutter so touch events work normally without it
- Added attribution to OSM (flutter_osm automatically adds it on the map but flutter_map doesn't)
- Added a currentZoom variable so that the recenter button doesn't change the user's zoom as .move explicitly requires zoom level to be passed
- Added supabase imports and initialization for migrating from Firestore to Postgres
- Added a schema.sql file for documentation purposes
- Migrated user data from Firestore to Supabase
- Deleted sanitize_poi_id because Postgres allows the raw name to be stored

## 2026-04-13
- Added the UNIQUE constraint to the username field so duplicates are handled on the DB-level
- Used the CITEXT extension so that the uniqueness of usernames is handled on a case-insensitive basis (eg so Nick and nick are not treated as separate usernames)
- Migrated the repository.py methods that use Firestore to query from Supabase Postgres instead
- Made a functions.sql file to document RPCs made
- Supabase postgres doesn't support transactions like Firestore does, so making functions with "FOR UPDATE" (the row level lock) is the solution for migrating the atomic operations
- All atomic methods in repository.py now call their corresponding RPC methods to ensure the methods remain atomic
- Updated the service.py code to properly refer to the updated methods because some were merged into one (users_public and users_private into users) and names now use snake case
- Migrated send_due_reminders and get_next_reset_time in server.py to use Postgres instead of Firestore
- Migrated token_manager.py to use Postgres instead of Firestore
- Made a RPC method for update_tokens and refund_tokens in token_manager.py to ensure it stays atomic
- Noticed server.py talked to the database directly for some operations (e.g getting fcm_tokens), so extracted the logic into methods and moved it into repository.py for consistency (as all direct reads / writes to the db happen via repository.py)
- UserRepository was handling all db operations, so added RemindersRepository and RateLimitRepository to separate the responsibilities
- Added reminder_repo and rate_limit_repo objects to server.py and updated everything calling user_repo's methods to use the corresponding reminder_repo / rate_limit_repo class methods instead
- loadUserData() still directly read user settings and app data from Firestore. Since Firestore is being replaced with Postgres which requires a backend intermediary, added routes, schemas, and service methods so the client reads and writes this data through the backend instead
- Added /get_user_data route to return all user data in a single call, replacing the parallel Firestore reads in loadUserData()
- Added /update_pfp, /update_app_color, /update_notifications, /add_fcm_token, /remove_fcm_token, and /upsert_food_log routes to replace the remaining direct Firestore writes in user_data_manager.dart
- Added corresponding request and response schemas in schemas.py for each new route, and added a reusable SimpleSuccessResponse schema for routes that only need to confirm success
- Replaced loadUserData() in user_data_manager.dart with a single /get_user_data backend call via _fetchUserDataSafely(), removing the parallel Firestore reads entirely
- Removed loadFoodData(), loadRemindersFromFirestore(), _loadFoodDataSafely(), and _loadRemindersSafely() from user_data_manager.dart since food logs and reminders are now returned by /get_user_data
- Replaced all remaining direct Firestore writes in user_data_manager.dart (profile picture, app color, notifications, FCM tokens, food logs) with calls to their corresponding backend routes
- Removed all Firestore collection references and cloud_firestore imports from user_data_manager.dart since nothing uses Firestore directly anymore
- Added refreshUserData() as a public wrapper around _fetchUserDataSafely() so the Food Logging tab can refresh all user data on tab switch without exposing the internal method
- Replaced the loadFoodData() call in food_logging.dart with refreshUserData() to keep food data fresh across devices on tab switch
- Changed app_color column type from TEXT to BIGINT since ARGB color values from Flutter's toARGB32() can exceed INTEGER's 32-bit limit, and TEXT has no type safety
- Updated offline snackbars to be accurate as they no longer automatically sync when the user goes online (that was Firestore-specific)
- Migrated leaderboard from Firestore to Postgres by adding a /get_leaderboard backend route, repository method, service method, and request/response schemas
- Replaced LeaderboardEntry.fromFirestore() with LeaderboardEntry.fromJson() since the leaderboard data now comes from the backend instead of Firestore directly
- Updated field names in LeaderboardEntry from camelCase (expPoints, pfpBase64) to snake_case (exp_points, pfp_base64) to match the Postgres column names returned by the backend
- Removed prefetchLeaderboard() from LeaderboardService since it only existed to warm Firestore's local cache, which no longer applies
- Replaced the Firestore query in LeaderboardService.fetchLeaderboard() with an HTTP POST to /get_leaderboard
- Migrated Reminders getting, setting, and deleting from Firestore to Postgres
- Made schemas for the get/set/delete requests, the get response, and a schema for ReminderItem to define the shape of a single reminder consistently everywhere
- Added /set_reminder, /get_reminders, and /delete_reminder routes
- Made set_reminder and delete_reminder methods in service.py and repository.py (get_reminders methods were already made, just unused)
- delete_reminder in services.py verifies the reminder belongs to the requesting user before deleting, preventing users from deleting each other's reminders
- Moved get_reminders from UserRepository to ReminderRepository so all reminder DB operations live in the same class
- Fixed get_due_reminders to query the correct column name (scheduled_at instead of time)
- ProgressionService now takes reminder_repo as a second constructor argument so it can delegate reminder operations to ReminderRepository instead of going through UserRepository
- Updated reminder_data.dart to match the schema.py shape of a ReminderItem (id, message, scheduled_at, notification_id, claimed), replaced fromMap with fromJson, and removed toMap() since it was only used for Firestore writes
- Replaced all direct Firestore calls in reminders.dart with HTTP requests to /set_reminder, /get_reminders, and /delete_reminder
- Replaced the cloud_firestore import in reminders.dart with http, dart:convert, and user_data_manager imports
- Updated reminders.dart to use reminder.scheduledAt instead of reminder.dateTime to match the renamed field
- Removed the client-side stale reminder cleanup logic from reminders.dart since expired reminder cleanup is now handled by the backend's scheduled task
- Updated user_data_manager.dart to use ReminderData.fromJson instead of fromMap
- Typed the food_logs and reminders fields in GetUserDataResponse with FoodItem and ReminderItem models instead of bare lists
- Typed the meal fields in UpsertFoodLogRequest with list[FoodItem] instead of bare lists
- Added a FoodItem schema to define the shape of a food entry consistently
- Reorganized schemas.py so shared models (FoodItem, POIItem, LeaderboardUserEntry, ReminderItem) are defined before the response schemas that reference them, and grouped sections with clear headers
- Updated daily_rewards to use the /set_reminders route instead of directly writing Firestore
- Reverted the FoodItem schema because food searches don't always return every field
- Fixed an ambiguity in consume_tokens and refund_tokens that prevented the methods from running correctly
- Made saveFoodData only send the current day's food instead of the entire foodDataByDate object to only send 1 http request instead of 1 for each day of foods logged
- Updated the README to add a link to the GitHub Wiki and to mention the newer app features
- saveFoodData crashing due to a bug showed that isLogging doesn't have any sort of timeout, which makes it permanently true => permanently shows the "please wait" snackbar
- Fixed food logging not saving: meal keys were inconsistent between Flutter (capitalized) and the backend (lowercase), so reads/writes mapped to the wrong keys and resulted in empty lists
- Standardized all meal keys to lowercase ("breakfast", "lunch", "dinner", "snacks") across food_logging.dart and user_data_manager.dart so they match the backend's column names
- Changed the meal dropdown to store lowercase values internally while still displaying capitalized labels to the user

## 2026-04-14
- Fixed /set_reminder route returning error code 500 due to mismatches with the actual table in Postgres
- Fixed by renaming the "time" column to "scheduled_at", adding the missing "claimed" column, and also added a default value for the id to make sure it is never null (safety fallback) by using Postgres gen_random_uuid()
- Updated the schema.sql reference to reflect the changes
- Fixed the reminder itself showing it was set in UTC in the reminder card even though the backend sends the reminder at the correct chosen user time
- Deleted the claimed column from reminders because it unnecessarily adds complexity and was not wired up with anything yet anyway
- Fixed daily reward never showing for users migrated from Firestore. Their last_daily_claim was stored as a string, but to_utc_datetime() had no string handler, so it fell back to returning the current time, making the cooldown always appear unmet
- Removed the firestore-specific code in to_utc_datetime()
- Added achievement_progress and achievement_claims tables to schema.sql for the badges system
- achievement_progress tracks how far a user is in each achievement category (e.g. progress = 12 for "level"). For simple one-time badges, progress is just treated 0 or 1 for unclaimed or claimed
- achievement_claims records which specific tiers a user already collected rewards for (e.g. tier 5 and tier 10 of "level"). This prevents double claiming and lets tiered achievements unlock independently
- Two tables instead of one because a single claimed/unclaimed boolean can't represent multiple tiers within one achievement
- Added inline comments to all tables and columns in schema.sql
- Built out the Badges screen UI with frosted glass cards, replacing the placeholder
- Made an AchievementDef class used for each achievement
- Achievements are grouped into tabbed sections (Progression, Explore, Tabs, Food, Reminders, Personalization, Meta) using DefaultTabController so users can swipe between categories instead of scrolling
- Each achievement card shows an icon, name, description, progress bar, and tier chips with locked/claimable/claimed states
- Achievement definitions (names, icons, tiers, descriptions) live in Flutter code, not the database
- Added a cooldown guard on tier claiming to prevent double taps
- Added AchievementRepository with get_achievement_progress and get_achievement_claims methods to read from the achievement tables
- Added get_achievements to ProgressionService which fetches both progress and claims in one call through the repository layer: get_achievents() in services.py calls repository.py's get_achivement_claims and get_achievement_progress and stores it in progress and claim variables
- Added GetAchievementsRequest, GetAchievementsResponse, AchievementProgressEntry, and AchievementClaimEntry schemas
- Added /get_achievements route that validates the JWT then returns all achievement progress and claims for the user
- ProgressionService now takes achievement_repo as a third constructor argument alongside user_repo and reminder_repo
- Made an upsert_achievement_progress RPC method to atomically update the user's achievement progress. The method returns the new progress amount
- Added the corresponding schemas for requesting / responding to UpsertAchievementProgress
- Added the /upsert_achievement_progress route and the corresponding method in services.py which calls the same-named method in repository.py which directly calls the RPC method to get the result atomically
- Made a claim_achievement RPC method to atomically check if the user can claim an achievement and then actually claims it. It gets the user's progress from the achievement_progress table and if its >= tier it means the user is eligible for an unclaimed achievement. In this case, the row for that achievement and tier is written into the achievement_claims table. If the row already exists, it does nothing by using ON CONFLICT. This ensures idempotency because no matter how many times the method is run with the exact parameters, there will only be 1 occurrence of the row actually being written. Atomic operations are all or nothing, so one operation will be successful and the rest will return without doing anything
- Made a ClaimAchievementRequest schema. SimpleSchemaResponse is used for the claim achievement response since nothing needs to be returned
- Made a /claim_achievement route which calls claim_achievement() in the service layer which called claim_achievement() in the repository layer which called claim_achievement, the RPC method which atomically carries out the operation
- Made a fetchAchievements method that calls the /get_achievements route and populates progress[] and claimedTiers[]
- Made claimTier call /claim_achievement
- Made valid_achievements.py which contains a list of all valid achievement ids to prevent the client from sending junk achievement ids to be stored in the DB
- Added the check to upsert_achievement_progress to reject an achievement_id not in the list
- Removed the public /upsert_achievement_progress route to prevent clients from directly calling it, achievement progress will now only be incremented server-side as a side effect of real validated actions (e.g., logging food, checking in at a POI)
- Hardcoded increment amount to 1 in the service layer so the client can't send fake progress amounts
- Removed UpsertAchievementProgressRequest and UpsertAchievementProgressResponse schemas since they are no longer needed
- Removed increment_amount parameter from ProgressionService.upsert_achievement_progress, it now always increments by 1
- Added _track_achievement helper in ProgressionService that silently increments progress by 1, wrapped in try/except so it never breaks the caller
- Wired up server-side achievement tracking as side effects of real actions: daily_claims and level in claim_daily_reward, poi_visits in check_in_poi, food_logs in upsert_food_log, set_reminder in set_reminder, delete_reminder in delete_reminder, set_username in update_username, set_pfp in update_pfp, change_app_color and color_indecisive in update_app_color, change_username in update_username (only when user already had a username), total_achievements in claim_achievement
- Split valid_achievements.py into three sets: SERVER_ACHIEVEMENT_IDS (server-protected achievements tracked as side effects), TRIVIAL_ACHIEVEMENT_IDS (low-stakes achievements the client can trigger directly), and VALID_ACHIEVEMENT_IDS (union of both)
- _track_achievement in ProgressionService validates against SERVER_ACHIEVEMENT_IDS before calling the repo
- Added VALID_ACHIEVEMENT_IDS check in AchievementRepository.upsert_achievement_progress as a last line of defense so nothing hits the DB without validation
- Added ClaimTrivialAchievementRequest schema and /claim_trivial_achievement route that only accepts trivial achievement IDs, returns 403 for server-protected ones
- Added trackTrivialAchievement fire-and-forget helper in user_data_manager.dart
- Wired up trivial achievement tracking on the client side: open_food_logging, open_explore, open_reminders, open_badges, open_leaderboard and calorie_calculator in home_screen.dart; food_search, food_barcode, food_manual, food_recent in food_logging.dart; future_reminder and active_reminders in reminders.dart; send_feedback in settings.dart and about_the_developer.dart; switch_imperial in calorie_calculator.dart
- Added confetti upon claiming an achievement the same way daily rewards handles it (wrapping the class in a Stack and adding the already created badges confetti on top)
- Changed the allComplete method to allClaimed so that the UI doesn't show text that is only meant to show after the achievement is claimed

## 2026-04-15
- Moved the verify JWT token logic in each route into its own helper method to reduce repeated code
- The method returns the uid and error message (if there is an error). If uid is not needed, python's _ was used as the return statement to show it is not needed
- Added daily_streak and highest_daily_streak columns to the users table
- Moved daily_claim_streak from trivial to server-side achievement IDs
- Updated claim_daily_reward SQL function to compute and update the streak atomically (continues if claimed within 48 hours, resets to 1 otherwise)
- highest_daily_streak updates itself via GREATEST so it never goes down
- Added a set_achievement_progress SQL function for setting progress to an exact value instead of incrementing (needed because streaks can reset)
- Added set_achievement_progress repository method
- After a successful daily claim, the service now sets the daily_claim_streak achievement progress to the streak value from the DB
- Made a streak table that uses streak_type so that there isn't a need to make 2 new columns every time a new streak type is added
- Deleted the streak columns from the users table
- Updated claim_daily_reward SQL function to read/write streaks from the streaks table instead of users columns
- Added last_date column to the streaks table so each streak tracks which date last advanced it (defaults to 1970-01-01 so it is never NULL)
- Moved food_streak from trivial to server-side achievement IDs
- Added update_food_streak SQL function that uses CURRENT_DATE and last_date to track real-world consecutive logging days (continue, reset, or skip if already logged today)
- Added update_food_streak repository method
- After a food log upsert, the service now computes the food streak and sets the food_streak achievement progress
- Updated claim_daily_reward to also write last_date when upserting the daily_claim_streak streak
- Added row locking to claim_achievement and update_food_streak RPC functions to make them truly atomic. Now it is impossible for two concurrent calls to read the same row at once before one of them writes
- The recent foods section now opens and closes using SizeTransition with an AnimationController
- The controller uses .forward() to expand the section and .reverse() to collapse it. Instead of items appearing or disappearing instantly, the widget smoothly changes its height over time, so the list gradually reveals or hides from top to bottom instead of instantly disappaering when the tab is collapsed
- Switched from SingleTickerProviderStateMixin to TickerProviderStateMixin because the new AnimationController needs its own ticker alongside the TabController's
- Wrapped the recent foods list in a ConstrainedBox with a max height and SingleChildScrollView to make the tab scrollable and prevent pixel overflow errors
- Moved the attribution text out of the buildSearchTab and buildBarcodeTab methods and moving them to the body's main column (above the recent foods section) so that expanding the recent foods tab did not push it down
- Edited textDropShadow to make the shadows of text more subtle
- Added a NotificationListener to listen to user scrolls, and a GestureDetector to detect user clicks, to automatically collapse the recent logs tab if the user scrolls / clicks on their logged foods under it, improving UX
- Moved the attribution text higher up to prevent misclicking when trying to press "Recent logs"
- Moved the "Log Food" button in the Search tab above the recent logs on this device to be consistent with the other tabs and prevent expanding the widget pushing the "Log Food" button
- Made the recent food entries also show the brand name if it exists
- Added a confirmation snackbar when trying to delete a logged food. For the swipe-to-delete, this was done by changing the onDismissed() to the built-in confirmDelete() method

## 2026-04-16
- Added the skeletonizer package to modernize the UI for loading. The plan is to use this package instead of showing a circular loading indicator
- Added a list of skeletonEntries with fake user data to Leaderboard tab that is used as the placeholder while the real data is loading
- Added an isLoading method to Leaderboard tab to determine whether to show the fake data or real data
- Added skeletonizer to the Food Logging tab. No fake data was needed because the Widget tree already renders before the food is obtained
- Added skeletonizer to Home Screen (same logic as above)
- Made fake POIs as placeholders to replace the circular loading icon with the skeletonizer package when loading nearby spots in Explore tab
- Moved the fcm token initialization to happen after isLoading = false so that Home Screen isn't still "loading" when the user's data is ready
- Each leaderboard entry is now wrapped in a frostedGlassCard to match the updated UI of other screens
- Made _rankColor helper method which stores the rank colors
- Added a _rankMedal helper method to now store a trophy next to the top 3 users
- Made a _profilePicture helper method to make the profile picture circular
- Made _buildUserCard which builds each entry with its rank, medal, pfp, username, level, xp amount, and progress bar
- used LinearProgressIndicator for showing the XP progress toward the next level
- Made the user's level appaer below their name
- Added pyproject.toml to make the backend folder installable as a python import to be able to run tests consistently from the root

## 2026-04-17
- Fixed rank number overflowing to the next line for double-digit ranks
- Made the spacing between rank number, rank medal, and pfp equal for Top 3
- Fixed spacing between the recent foods expanded widget and the "Scan barcode" button
- Made scan barcode's button have the same padding as the other widgets for consistency
- Used ShaderMask to fade out the expanded recent foods tab instead of it cutting off abruptly
- Added a visibilitychange listener in index.html that reloads the PWA if it was hidden for more than 30 minutes to fix the iOS PWA getting stuck on a white screen when the app was backgrounded for a while
- Made the padding in all Food Logging tabs consistent
- Added an isDark variable to frostedButtonShell to conditionally assign the level of darkening / shading etc to the buttons. Now lighter color themes make the buttons look much less washed out, as before they looked grayish
- Used the speech_to_text package to allow speech to text usage for searching foods
- Replaced the magnifying glass icon in the Search bar with a microphone icon that is clickable to start listening to the microphone
- Added the appropriate microphone permissions to the Info.plist and AndroidManifest files
- Fixed a bug in handleApiCall which never searched if the user searched a capitalized word. The race condition guard latestQuery was stored as the raw input, so the check between latestQuery and the normalized version of the query would always return before the api was called due to if (latestQuery != query) return. Fixed by moving latestQuery asisgnment after query was normalized
- Extracted the debouncer logic into a helper method _scheduleSearch
- Added "powered by (username)" to the manual tab for consistency with the other tabs
- Moved the pure calculation methods in food logging to a helper file to make food_logging.dart shorter
- Realized a bug in initializing new users: initialize_user_if_new did not contain all user variables and the DB itself did not default values to non-null values, causing bugs for new users as the Pydantic schema rejected before hitting the DB
- Edited initialize_user_if_new to only send the uid and username == uid. The DB automatically defaults to the remaining fields
- Users with no username AND a daily reward to be claimed now see the set-username dialog, and then the daily reward dialog after the username dialog is dismissed. Previously both fired simultaneously, and a frame-scheduling bug meant the daily reward dialog wouldn't appear at all until the user interacted with the screen

## 2026-04-18
- Modernized the Register/Login screen with a new layout, animations, and design
- Replaced the two equal-weight Register and Login buttons with a single segmented button toggle at the top of the form
- Added an ambient animated background made of two soft RadialGradient glow orbs that drift along sine curves using an AnimationController on an 18 second loop, giving the screen motion even when the user is idle
- Added staggered entrance animations. The logo and title, the form, and the social auth section each fade and slide into place at different intervals over a 900ms AnimationController
- Replaced the default Material underline text fields with filled rounded fields that have leading mail and lock icons, a subtle enabled border, and a thicker brighter border when focused
- Added a Privacy Policy and Terms of Service agreement checkbox that appears only in Sign Up mode
- Sign Up is blocked with an error message until the box is checked
- Forgot Password only shows in the Sign Up tab
- Made the screen fill the full vertical height of the device using LayoutBuilder, ConstrainedBox with minHeight equal to the available space, IntrinsicHeight, and Spacers between the top, middle, and bottom sections
- Replaced the red error paragraph under the buttons with a conditional message that only renders when there is something to show
- Removed the old AppBar from the Register/Login screen
- Used the same staggered logic in the Home Screen to make the buttons fade in smoothly. Made a buildStaggered helper method and wrapped the buttons in the method, showing one button after the other
- Made a buildPlaceholder method that is used when loading the home screen so that the skeletonizer can still show the buttons loading like before
- Added AnimationController to footer.dart so that the XP bar gradually fills to the user's current XP instead of instantly showing it
- Added initState() to footer.dart that sets up the animation with a begin of 0 so the bar fills from empty on first load
- Added dispose() to footer.dart to clean up the AnimationController and avoid memory leaks
- Wrapped the XP bar in an AnimatedBuilder so it rebuilds every frame of the animation
- Used a ValueListenableBuilder to trigger a new tween animation whenever the XP value changes
- Made progressWidth animate based on _animatedExp.value with how much xp has been filled in at that point

## 2026-04-19
- Removed serviceWorkerSettings from the _flutter.loader.load call in web/index.html so Flutter no longer attaches its controllerchange listener that reloaded the page when firebase-messaging-sw.js claimed it on iOS PWA launch
- Added iOS-specific swipe-back gesture for exiting specific tabs because currently it causes the PWA to completely refresh
- Made all methods that used MediaQuery.of(context).size use MediaQuery.sizeOf(context) instead to avoid rebuilding due to non-size-related screen changes (eg opening a keyboard on mobile)
- Removed the IntrinsicHeight wrapping to see if it would fix the Registration page bug on mobile
- Did not fix (but kept anyway due to IntrinsicHeight performance issues)
- Changed the auth_gate to be Stateful to cache the stream in initState to prevent Firebase focus events from remounting the register screen on mobile
- Moved appColorNotifer to home screen so that it sets right before the shimmer turns off to prevent the skeletonizer from appearing twice on app initialization
- Added an in-memory dictionary _last_poi_fetch for storing time and location of the latest POI fetch to compare it on subsequent POI fetches to make sure the user is not moving impossibly fast
- Made an is_moving_too_fast_for_poi method that ends the request early if the user is moving too fast
- Added a specific error code for this condition which is caught by the frontend to show said message to the user
- Added a client-side check that shows the same error as the moving too fast backend check if the user has moved too far from where they were during the request to fetch the POIs. This is purely for UX as otherwise no POIs would load with no explanation

## 2026-04-20
- Removed the self.claim from the custom SW as the custom SW already takes over with getWebFcmToken's serviceWorkerRegistration field
- Added --pwa-strategy=none to the web build to prevent Flutter's generated service worker from causing a double page load on every visit. According to the Flutter Docs the Flutter SW is deprecated, and this avoids creating it at all
- Fixed FCM token removal on sign out, which now uses JS interop on web (to avoid a 404 from Firebase trying to register the SW at the wrong scope) and getToken() on mobile, removing only the current device's token
- Unregistered old Flutter-generated service workers to prevent them from serving stale cached assets alongside the current bootstrap
- Made it so installing as a PWA on an Android device shows the app's logo instead of the default Flutter one. Did this by adding maskable versions of the app logo
- Added dividers under all app bars and on top of the footer bar to separate from the body more cleanly
- Made the appBar's height on the Home Screen smaller
- Added icons near the text in each button on the home screen
- Changed the style of the current app version text
- Added the flutter_animate package to remove the boilerplate code from adding animations without the package and to make animations easier to add in the future
- Made the same changes to the Register or Login page
- Added the staggered animation into the Leaderboard tab. Made a set to hold the cards that have already shown the animation so that the animation only happens once per card
- Only the first 10 spots get the animation to prevent it from occurring as the user scrolls down
- Simplified the animation code for the footer exp with TweenAnimationBuilder
- Made the progress bar's XP go up after the daily reward dialog is dismissed instead of happening automatically with the expNotifier
- Replaced the "Settings" text in the settings drawer with the user's pfp and username
- Changed some icons in the Settings drawer
- Added a divider to separate the Log Out button in the Settings drawer
- Made a buildActionTile helper method for drawer items that don't navigate to different screens
- Made the username == null on a slow backend request to prevent prompting the user for their username when the backend is taking a while to load
- Fixed reminders not appearing initially in the Reminders tab by initially showing the cached version and then updating in the background
- Added a flag to show a loading indicator before opening the cropper so that the user knows their profile picture update did not fail

## 2026-04-21
- Edited addFcmToken to now take an oldToken parameter and remove it to prevent dead tokens from accumulating
- Before this, tokens were only being cleared when a reminder was sent with send_due_reminders, so old tokens could accumulate for a while in the mean time
- Moderenized the Calorie Calculator UI to look like the other tabs
- Replaced the dropdown buttons with sliders and buttons to feel more polished and convenient
- Changed the xp formula in the backend to match dart exactly
- Made the achievement progress for level set the user's level as the progress instead of using track_achievement because level might go up by more than 1 and the current logic didn't work for existing users
- Added level achievement logic to check_in_poi in case the user levels up from checking in
- Wired the Full Course Meal achievement so it is now functional
- Edited the requirements for the Full Course Meal achievement to also require a snack food
- Added a _parse_and_auth method to server.py to reduce repeated code of schema parsing in every route
- Extracted repeated logic for checking if the user can claim a daily reward into a helper method in services.py
- Added FoodService and POIService classes to services.py to move the code from server.py into them
- server.py now uses the code through the new classes instead of directly in server.py

## 2026-04-22
- Made a daily_snapshots table that stores each user's data
- Made a take_daily_snapshots methods that stores each user's snapshot into the daily_snapshots table
- Made a /daily_snapshot route only accessibly by a CRON job which writes /daily_snapshot once per day at UTC+14
- Writes at UTC+14 because the method writes yesterday's data to ensure it stores the most up-to-date data. UTC+14 ensures yesterday applies to everyone
- Realized the logic above isn't foolproof, so added reverted the changes and added a timezone value to each user table and had the snapshot taken at their timezone's midnight
- Added /update_utc_offset route and methods in server.py, services.py, and repository.py
- Added UpdateUtcOffsetRequest schema
- Added updateUtcOffset which is called on user initialization which calls the route which uses the service and repo layer to write the db with the user's timezone
- Changed utc_offset to utc_offset_minutes and renamed all utc_offset references to utc_offset_minutes to store the offset in minutes so that timezones whose offsets are not perfect hours (eg also have 30 minutes) don't get truncated to the hour
- Made utc_minute_of_day which calculates the time in UTC in terms of minutes
- Made find_utc_midnight_offset_mins which uses the above method to calculate the offset in minutes of UTC timezones that are currently experiencing timezone. It works by using the formula local time = utc time + offset, where local time = 0 at midnight => offset = -utc time. This value was % by the total minutes in a day to make sure it stays in the valid range
- Example: NY is UTC-4 => The offset = -240. If it was midnight in NY, utc_mins would be: -offset = 240. 240 % 1440 = 240. So it is midnight in NY at 4 UTC
- Made a /daily_snapshot route that gets the users who are at midnight by getting the users' stored utc_offset_minutes that match with the calculated find_utc_midnight_offset
- Added the methods for getting and writing the user's data for creating the snapshot in repository.py
- Added a SnapshotService class to services.py which has a run method that compiles and then upserts the data into the user's snapshot table

## 2026-04-23
- Realized the logic for the snapshot is slightly off because it tries to compare the midnight method's value, which is in the [0, 1439] range, to the user's stored value, which is not wrapped and is the actual offset from UTC (eg UTC-4 is stored as -240)
- Fixed this by building a map before the wrapping is done, since wrapping with modulo is a one-way operation. map[midnight_value] = stored UTC offset, so the stored offset can be retrieved for the DB query
- find_utc_midnight_offset_mins returns said map
- Added the 1 minute buffer logic directly to find_utc_midnight_offset_mins
- Created food_logging_charts.dart as a new screen for viewing daily food analytics
- The screen is opened by tapping the "Total Calories" display in Food Logging, which was changed from plain text to a styled tappable row with a bar chart icon, the calorie count, and a chevron arrow to signal it leads somewhere
- The screen slides in from the top using a custom PageRouteBuilder with a SlideTransition (Offset(0, -1) to Offset.zero) to feel like a contextual panel rather than a full navigation push
- The AppBar uses a keyboard_arrow_down icon as the leading button to reinforce the screen came from above
- Added fl_chart as a dependency and built two PieChart widgets inside frostedGlassCards
- CALORIE BREAKDOWN splits total daily calories across Breakfast (amber), Lunch (green), Dinner (indigo), and Snacks (rose), with each slice labeled by percentage and a color-coded legend showing the kcal count per meal
- MACRO BREAKDOWN splits calories by macronutrient using calorie-equivalent weighting (protein and carbs at 4 kcal/g, fat at 9 kcal/g), with slices for Protein (blue), Carbs (amber), and Fat (rose), and a legend showing grams per macro
- Both charts show an empty-state message if no data is logged for the selected day
- The charts screen is stateful and loads its own food data directly from currentUserData.foodDataByDate for any selected date, so it does not depend on what is currently loaded in Food Logging
- Extracted the date navigation row (left arrow, tappable date label that opens a date picker, right arrow) into a reusable DateNavigationRow widget in globals.dart, replacing the previously duplicated row in both Food Logging and Food Analytics
- DateNavigationRow takes a currentDate and onDateChanged callback, handling the date picker internally via showDatePicker
- Food Analytics passes an onDateChanged callback back to Food Logging so that navigating dates on the charts screen also updates the selected date in Food Logging, keeping both screens in sync
- Replaced the read-modify-write pattern in add_fcm_token and remove_fcm_token with atomic Postgres RPC calls using array_append and array_remove. Previously both methods fetched the user's full token list, modified it in Python, then overwrote the entire array, meaning two concurrent calls could race and one write would silently clobber the other's change. The new RPCs are single UPDATE statements so no read is needed and no race condition is possible
- Added add_fcm_token and remove_fcm_token SQL functions to functions.sql to support the above
- Replaced the invalid token cleanup in send_due_reminders, which also did a read-modify-write by filtering the fetched list in Python and overwriting the full array, with individual remove_fcm_token RPC calls per invalid token. This prevents any valid token added between the original fetch and the overwrite from being accidentally wiped
- Deleted update_fcm_tokens from repository.py as nothing uses it anymore
- Split services.py into a services/ package with one file per class: food_service.py, poi_service.py, progression_service.py, and snapshot_service.py. Added a services/__init__.py that re-exports everything so no imports in server.py or tests needed to change
- Added tap interactions to both pie charts in Food Analytics. Tapping a slice expands its radius outward, increases its label size, and dims the other slices so the selected one stands out. Uses fl_chart's pieTouchData with a touchCallback that updates a touched index in setState, and the sections list is pre-built with explicit indices so the touch index maps correctly to only the non-zero slices. Touch state is reset when the date changes so a highlighted slice never carries over to a different day
- Added animation upon entering the food analytics screen
- Converted the pie charts to have a donut hole and overlaid it with a Stack to have a label in the middle
Converted both pie charts in Food Analytics to donuts by adding a centerSpaceRadius, then overlaid a Stack-centered label in the hole. When nothing is tapped the center shows the day total with a gray unit label beneath it; tapping a slice updates the center to that slice's name and value, tinted to the slice's color. Two separate widget classes handle the calorie and macro variants since the macro center shows grams while the calorie center shows kcal
Added icon badges to each pie chart slice using fl_chart's badgeWidget and badgePositionPercentageOffset, placing a contextual icon near the outer rim of every slice. The icon brightens and grows when its slice is tapped
Added a row of four stat tiles above the charts showing total calories, protein, carbs, and fat for the selected day at a glance. Each tile has a colored icon, a large value, a small gray unit label, and a tinted pill label. The calories tile is slightly wider via a higher flex factor. Wrapped in IntrinsicHeight so all four tiles are always the same height regardless of content, and the pill label uses FittedBox so the text never wraps
Removed kcal from the macro donut chart entirely since macro-derived calories (protein × 4, carbs × 4, fat × 9) do not match the stored calorie values due to rounding in description strings and calories from sources not tracked as macros. The macro chart center now shows grams only

## 2026-04-24
- Made a models folder to store user_data.dart, reminder_data.dart, leaderboard_entry.dart, and poi.dart
- Made a services folder for service-related files like user_data_manager, leaderboard, recent_foods, voice_search, poi_service, fcm
- Renamed settings_buttons folder to settings
- Renamed calorie_calculator_buttons folder to calorie_calculator
- Deleted the user folder (files were moved to models and services)
- Deleted web_fcm_token.dart as it was unused
- Redesigned the Results tab with three tabs (Results, Overview, Formulas) matching the style of other screens
- Results tab now shows BMR and TDEE as large stat cards with the gradient number, unit label, and equation as secondary text
- Formulas tab shows male and female formulas in separate cards with blue and pink color coding
- All section headers now have a small icon on the left
- Replaced sectionTitle and resultCard helpers with sectionHeader and frostedGlassCard to match the rest of the app
- Made the truncated app titles have the full title text
- Made the food analytics pie charts animation play each time the user changes date instead of only on initialization
- Did this by adding an animationKey based on the date changing (increments by 1 each time) so that the animation rebuilds when the date changes, then added the key to each .animate()
- Made each key a tuple with a unique label as duplicate keys are not allowed
- Added the go_router package to simplify navigating to different pages and so that the URL bar updates based on the current page being shown, so that if the user refreshes it does not always go back to the first screen
- Used usePathUrlStrategy() so URLs appear as clean paths (e.g. /food-logging) instead of hash-based paths (e.g. /#/food-logging)
- All navigation uses context.go so the browser address bar stays in sync
- Sub-screens (Results, Food Analytics) are also assigned their own routes (/calorie-calculator/results, /food-logging/analytics)
- Added explicit back buttons to every screen since context.go does not add to Flutter's Navigator stack
- Each back button navigates to the correct parent screen
- Replaced the Navigator.push call in the footer profile picture tap with context.go
- Removed /update_exp and its related schemas and methods because it was dead code and exp handling will happen in the specific routes that deal with updating exp (eg daily reward or claiming a poi visit)
- Replaced custom slide transitions with CupertinoPage so iOS swipe-back gestures reveal the parent screen natively instead of re-triggering the entrance animation
- Added web/404.html and a restoration script in index.html to fix 404s on page refresh as GitHub Pages has no server-side rewrite rules, so a direct request to any sub-route returns 404
- 404.html encodes the intended path as a query param and redirects to index.html, which restores the URL with history.replaceState before Flutter boots so go_router loads the correct screen
- Removed ShellRoute and replaced AppShell with a dedicated /loading route (AppInitScreen) that runs app init then navigates to the intended destination
- ShellRoute owned the viewport as a persistent parent which caused swipe-back to flash the home screen and re-play the entrance animation
- Added addPostFrameCallback to the initial context.go to prevent it from running before the app is ready
- Added FittedBox to customButton and createTitle to prevent overflow on smaller screens
- Readded _slidePage as the custom transition for transitions to different screens because the Cupertino one would show a double initialization bug when swiping back to the home screen

## 2026-04-25
- Added a Range tab to the Food Analytics screen alongside the existing Daily tab using a TabController and TabBar in the AppBar
- Added table_calendar as a dependency for the range date picker
- Range tab contains a TableCalendar styled to match the app theme (Manrope font, white text, app color for selected range endpoints)
- Set availableGestures: AvailableGestures.none on the calendar so mouse clicks register correctly instead of being swallowed by the gesture recognizer
- Before a range is selected, a touch icon and instruction text tell the user to tap a start date then an end date, with a second line clarifying both are required
- Selecting a start and end date aggregates all food data across every logged day in the range, skipping days with no entries
- Added _RangeAggregate data class to hold all aggregated totals from a range in a single return value instead of returning 9 separate values
- Added _aggregateRange method that adds every day in the range and accumulates calories per meal and macros, tracking daysWithData separately so averages exclude empty days
- Range tab shows the same two donut charts as the daily tab (calorie breakdown by meal, macro breakdown) but with totals across the selected range
- Added _rangeStatTilesRow and _rangeTile widgets that mirror the daily stat tiles but add an avg/logged day line beneath each value
- Extracted the daily tab body into a _DailyTab StatelessWidget to keep the main build method readable after the tab structure was added
- Extracted the range tab body into a _buildRangeTab method for the same reason
- Deleted changeToScreen as it is no longer used
- Deleted drawerItem as it was unused
- Deleted the destination parameter from customButton since all callers use onPressed and the fallback called changeToScreen
- Removed the cupertino import from globals.dart as it was only needed by changeToScreen
- Switched _slidePage to return CupertinoPage for standard right-to-left transitions so the iOS swipe-back gesture is tied directly to the animation, preventing the secondary re-entrance animation bug
- Falls back to CustomTransitionPage with reverseTransitionDuration: Duration.zero only for non-standard directions like settings sliding in from the left
- Switched all home screen button navigation from context.go to context.push so a proper back stack exists
- Switched all back buttons from context.go('/') to context.pop() so they pop the current page off the stack instead of re-pushing the home screen and triggering a forward transition
- Switched sub-screen navigation (food logging to analytics, calorie calculator to results) from context.go to context.push
- Switched settings drawer navigation from context.go to context.push
- Removed the begin: Offset(-1, 0) override from settings routes so they use CupertinoPage like all other routes, fixing the instant pop when going back from settings screens
- Simplified _slidePage to just return CupertinoPage directly since all routes now use the default direction, removing the fallback CustomTransitionPage branch
- Replaced CupertinoPage with a custom _SlidePage and _SlideRoute (a CupertinoPageRoute subclass) to fix the iOS swipe-back double-transition bug
- _SlideRoute overrides buildTransitions to check popGestureInProgress which is true when an iOS device uses the swipe back gesture
- Overriden so that when true, it plays no animation to fix the double animation bug
- All other transitions still animate normally
- Added + / - buttons to the Age and Height sliders in Calorie Calculator that use new increment() and decrement() callbacks to improve UX on smaller screens where sliding accurately is more difficult
- Realized a daily snapshot bug that occurred when a user hits midnight in a timezone whose midnight is a different day to UTC. E.g. Cyprus midnight is 21:00 UTC the previous day, so food logs were being fetched for the wrong date and the snapshot was being written with the wrong snapshot_date
- Fixed by splitting users into two groups based on whether their UTC offset is positive or negative, then doing two bulk food log fetches, one with utc_today for behind-UTC users and one with utc_tomorrow for ahead-UTC users

## 2026-04-26
- Fixed a bug where the app gets stuck on the loading screen after login
- Fixed by moving appInitialized to globals.dart to avoid a circular import (router.dart imports register_or_login.dart which imports auth_services.dart), resetting it in signOut(), and replacing context.go with appRouter.refresh() after init completes so the redirect rule drives navigation out of /loading
- Added a redirect rule: when isLoggedIn and onLoading and appInitialized is true, redirect to the intended destination (restores sub-route on web page refresh, falls back to /)
- Made the settings drawer reopen after exiting one of its tabs to feel more natural
- Used GlobalKey<ScaffoldState> passed into buildSettingsDrawer to open the settings drawer outside of its build method
- Extracted food_logging_charts colors into consts to reduce repeated code
- Made the Food Logging mic hide some opacity when the user chooses a food to show it is inactive
- Added a card around the food description when editing nutrition info to make it easier to read
- Added a clear button when selecting a food to prevent the user having to change date / re enter the screen to clear the food from the search bar
- The clear text replaces the microphone icon when a food is selected, and clicking it clears the selection
- Changed the search TextField from enabled: false to readOnly: true when a food is selected so the suffix widget stays interactive and the clear button is tappable. This also fixed the search box disappearing when a food was selected as the TextField no longer gets rebuilt
- Replaced the snack bar on food logging errors with an inline error for better UX
- Made an _inlineError widget that is used instead of showSnackbar when necessary
- Replaced the Log Food cooldown snackbar with a visual fill animation that drains across the button over 3 seconds, giving clear feedback that the button is temporarily inactive
- Wrapped the Log Food button in IgnorePointer during the cooldown to prevent tap-spamming while the animation plays
- Made the mobile keyboard automatically dismiss after a food search so that the keyboard doesn't block the table of returned foods
- Fixed an uncaught error on page refresh caused by firebase.messaging() throwing when called unconditionally in index.html by wrapping it in a try/catch so a stale service worker state on refresh no longer crashes the app
- Fixed home screen skeleton showing briefly on every login even though user data was already loaded before the router navigated to /
- isLoading now initializes to false when appReadyNotifier is already true at mount time
- Added frontend code to set canClaimDailyReward to true in case the backend ever has stale data. Can't be exploited as the backend independently makes the time check
- Fixed a crash on first load for users with an unclaimed daily reward caused by confettiControllerinit() running after _onAppReady() in initState, making dailyRewardConfettiController uninitialized when buildDailyRewardDialog() accessed it synchronously
- Removed the meal type dropdown from the food logging toolbar and replaced it with a centered dialog that appears after pressing Log Food, showing a 2x2 grid of meal tiles with a cancel button
- Each meal tile is colored using lightenColor(appColorNotifier, 0.30) so the picker stays on theme
- Recent foods now go through the same meal picker instead of logging immediately on tap
- Fixed an Incorrect use of ParentDataWidget error caused by buildSearchButton() returning an Expanded widget after the surrounding Row was removed when the meal type dropdown was deleted
- Added a failed to load state on the home screen when the backend fetch fails
- The skeletonizer stays visible in the background and a frosted card with a retry button is shown on top
- The home screen is non-interactable while the load failed state is active so the user cannot tap buttons with stale or missing data
- Added lastLoadFailed flag to UserDataManager so the home screen can detect and react to a failed fetch
- Made the default load color on PWA show a dark gray color instead of white which is too bright and jarring
- Saved the user's app color to localStorage so that subsequent load colors will use the user's actual stored app color
- Made a js interop method setAppColor for saving the app color
- Reordered home screen buttons

## 2026-04-27
- Changed the backend to fire all Overpass API URLs in parallel and use the first successful response instead of trying them sequentially
- Fixed the parallel executor using a with block which caused shutdown(wait=True) to be called on early return, making it wait for all threads to finish instead of returning as soon as the first URL succeeded, replaced with shutdown(wait=False)
- Added two additional Overpass mirror URLs (kumi.systems, openstreetmap.ru) so 4 servers race in parallel instead of 2
- Reduced per-URL HTTP timeout from 25s to 15s and the Overpass query timeout from 20s to 14s to fail faster when servers are unresponsive
- Fixed the explore tab showing "Failed to load locations" alongside visible POI markers by only showing the error when nearbyPOIs is empty
- Changed the Overpass failure error message to clarify that Overpass is slow rather than implying the app itself failed
- Fixed a browser violation where geolocation was requested automatically on page load instead of in response to a user gesture, causing the browser to silently deny location access and prevent POIs from ever loading
- On first visit to the explore tab a button is shown to trigger location access; on subsequent visits permission is already granted so location is retrieved automatically
- Made Nearby Spots card automatically expand on an error for better UX
- Added per-request logging to the backend so every route logs the uid and response status, allowing Render logs to be grepped by uid to diagnose user-specific issues
- Reverted to sequential Overpass API calls as per their rules
- Fixed the Nearby Experience Spots card briefly flickering closed and open when POIs were already loaded by only showing the skeleton placeholder when no POIs exist yet, preventing the list from being replaced by the skeleton on a fast cache hit
- Fixed the "Finding more spots..." spinner never appearing because fillingCache was being reset to false immediately after getNearbyPOIs returned, overriding the onFillStart callback that set it to true
- Fixed the "Finding more spots..." spinner incorrectly appearing when the cache was already at max POIs
- The service now stores how many POIs the backend returned (cached_pois_backend_count) after each fetch and skips the background fill entirely when the cache already holds that many, so the indicator only shows during actual partial-cache fills
- Fixed the check-in button twitching in and out of visibility by adding a version counter to _refreshClosestCheckinPOI so that only the result from the latest call is applied, discarding any stale concurrent calls that would otherwise overwrite it
- Made Nearby Experience Spots card not appear until the map loads
- Made the Back button initially appear in the top left, moving down only when the map loads
- Fixed the loading background color not matching the user's app color on iOS PWA
- The CSS was hardcoding #2d2d2d which overwrote the color the inline script set from localStorage
- Switched to a CSS variable so the stored color is applied before Flutter paints and can't be overwritten by the stylesheet
- The loading color is now blended at the same opacity Flutter uses (200/255) so it matches the scaffold background color exactly instead of showing the raw unblended color
- Changed the loading background to use the full app gradient instead of a flat color so it matches buildThemeGradient exactly
- Flutter sends the dark and mid gradient stop colors as a pipe-separated string, and the JS reconstructs the same linear-gradient before Flutter paints

## 2026-04-28
- Tweaked Calorie Calculator colors for better UI
- Made age slider cap at 120 instead of 100
- Made the circle on the thumb sliders smaller
- Rebuilt the food logging screen with a new structure where each meal section (Breakfast, Lunch, Dinner, Snacks) lives on the main screen with its own collapsible food list and a dedicated Log Food button per meal
- Each meal section is collapsible using AnimatedSize before animating so it feels intentional
- Logging a food now opens a dedicated LogFoodScreen instead of showing a meal picker dialog after the fact, so the meal context is set before the user even starts searching
- LogFoodScreen contains search, barcode scanning, and manual entry all on one screen with the search bar always at the top, recent foods always visible below it with an empty state, and manual entry as a collapsible labeled section at the bottom
- The log food button pops the screen immediately on success instead of waiting 3 seconds for a cooldown bar since the user is leaving the screen anyway
- LogFoodScreen and the analytics screen both slide up from the bottom instead of from the side so they feel like extensions of the food logging screen rather than separate screens
- Made the total calories for the day text more prominent which also allowed making the button that leads to Food Analytics much more prominent
- Added side donuts for macros that appear on the daily view as well that will be capped based on the user's goals (currently just use placeholder values)
- Added calories text near each meal type
- Made a _slideUpPage method for food logging screens to feel like extensions of the Food Logging tab instead of feeling like entirely new screens
- Added a goals table for letting the user set nutritional goals
- Made an /update_goals route
- Made an UpdateGoalsRequest schema used in the update_goals route
- Made a update_goals method in services that sends the non-empty goal changes as a dict to the repository
- Made an upsert_goals method in repository that unpacks the dict and upserts the changes
- Changed this.fcmTokens = const [] and this.reminders = const [] to the initializer list style with ?? [] so each instance gets its own fresh list and .add doesn't throw on a shared const
- Added the nutrition goals to UserData as variables
- Added an updateGoals method that called the /update_goals route
- Added a button to Personal Preferences for updating goals
- Added a get_goals method in the repository that is called in the /get_user_data route so that goals are also loaded
- Updated getUserDataResponse schema to handle the goals field by calling a new GoalsResponse schema
- Added goal loading to fetchUserDataSafely so the frontend updates the goals
- Replaced the placeholder goals in food_logging with the real values
- If no goals are set, a button appears where the user can enter their goals (same button as in Personal Preferences)
- If the user has no specific goal set, the gauge shows a button prompting them to enter the goal and leads them to personal preferences (_buildMacroPlaceholder)

## 2026-04-29
- Edited the text gradient values
- Changed createTitle() font from dangrek to spaceGrotesk
- Edited the text shadows to be more subtle
- Changed button text from dangrek to manrope
- Changed Level Up! title text to use spaceGrotesk
- Removed the icons from the home screen buttons
- Edited frostedButtonShell's border so the home screen button borders stand out
- Added subtle shadows to buttonText
- Updated the settings drawer to fit Home Screen better by matching the style of the buttons
- Made the current version text in a pill

## 2026-04-30
- Added ON DELETE CASCADE to sql tables
- Fixed a naming inconsistency where last_date in the daily_consecutive field of the streaks table was never updating
- Renamed all occurrences of the name to daily_consecutive_streak
- Fixed daily snapshot timezone targeting for users east of UTC where the computed offset was never matching the stored value
- Normalized the midnight offset formula to the -720 to +720 range so computed offsets match what Flutter stores via DateTime.now().timeZoneOffset.inMinutes
- Added UTC+12 edge case where both 720 and -720 are queried since devices can store either
- Moved the daily snapshot-related code from server.py to utils.py
- Wrote unit tests for utils.py
- Added a test job to deploy.yml that sets up Python and runs pytest before deploying
- Made build-and-deploy depend on the test job so deploys are blocked if any test fails

## 2026-05-01
- Integrated Google Analytics (GA4) to index.html to track page views and user engagement on the web version of the app
- Fixed food logging screen not refreshing after logging food and then changing date by making _syncFoodData async and awaiting refreshUserData before reloading the current date
- Removed stale local copy of foodDataByDate as it added complexity for no reason
- Now data reads directly from currentUserData instead
- Increased the timeout duration in userDataManager methods to prevent "Connection is slow" messages happening on successful requests that took longer than 2 seconds
- Made the page reload when a stale service worker is found instead of still serving the cached, stale one
- Added the skeletonizer package to the Badges tab
- Made isLoading reset to true when the user re-enters the Badges tab so the skeletonizer works on subsequent visits
- Realized that the streak badge claiming depends on the current streak. So for example, if a user had a highest streak of 10 and then lost that streak, they would not be able to claim the achievement for a streak of 10 because their current streak would be <10
- Fixed this by making the claiming depend on highest_streaks in the streaks table instead of progress in the achievement_progress table
- Made a get_streaks route, schema, methods etc for getting the user's streak table info
- Made a fetchStreaks flutter method that calls the backend
- Moved fetchAchievements from Badges to userdatamanager for consistency
- Called fetchStreaks and fetchAchievements in parallel in Badges in _fetchBadgeData method
- Populated highestStreaks using the fetchStreaks highest_streak data in the _fetchBadgeData method
- Edited badgeTierChip to use highestStreaks for its claiming boundaries
- The progress bar still shows the current streak, which is intended so the user who has not completed all tiers is aware of their current streak number

## 2026-05-02
- Added a theme for Dialogs in main.dart so dialogs in the app appear more modern
- Edited the date picker method in Reminders to follow the same theme as the other dialogs
- Added padding to the notch to fix iOS PWA button hitboxes being slightly misaligned (did not fully fix the issue)
- Delayed Flutter launch until viewport settles on PWA to fix iOS safe area hitbox race condition (appeared to work but broke again on a full cold open)
- Fixed going back from About The Developer and Install PWA screens reopening the settings drawer
- Properly fixed the iOS PWA hitbox issue by removing the CSS body safe area padding entirely and instead reading MediaQuery.viewPaddingOf in Flutter, which is reliable at render time
- Extended the Footer height and bottom padding by the home indicator inset so content does not sit under the home bar (visual fix only, unrelated to the hitbox issue)
- Added an edit icon button next to the delete button on logged food cards to edit serving sizes after logging
- Tapping it opens a dialog pre-filled with the current serving amount and unit
- On save, all macros and calories are scaled proportionally using the existing scaleFood and buildDescription helpers and stored
- Added an "edited" case to saveFoodData to show a specific snackbar for a successful edit instead of showing "Food logged successfully"
- Made it so if the user submits the same serving size it just returns
- Made all dialogs have the same opacity for consistency
- Added the textStyle dialog code to main.dart instead of having to explicitly write it out every time
- Made app border dividers thicker
- Added rounded corners and a subtle border to the settings drawer to match the dialog style
- Made Recent Meals collapsable like the meal categories in the Food Logging tab
- Made the Manual Entry card expand and collapse smoothly like Recent Meals and meal categories instead of happening instantly
- Edited the serving size picker so its color and font matches the rest of the manual serving card
- Replaced the manual serving size dropdownbutton with a showModalBottomSheet for more modern UI and more control over how it looks
- Wrapped the sheet with BackdropFilter to give it a glass-like look

## 2026-05-03
- Fixed attribution text not being centered when the camera is being used for barcode scanning
- Added current daily streak to the daily reward dialog
- The claim_daily_reward SQL function already calculates the current streak, so that value is used
- Made the fire emoji in the daily reward dialog use the user's app color
- Added streak-based XP multiplier to daily rewards (1.1x at 3 days, 1.25x at 10 days, 1.4x at 30 days, 1.5x at 50 days)
- Multiplier is computed server-side in Python by fetching the current streak from the streaks table before the claim transaction
- The multiplier is computed in Python from the streak value fetched before the claim and included in the API response so the dialog can display it
- Added the current daily reward xp multiplier and extra xp gained (boosted xp - base xp) to the daily reward dialog
- The daily dialog also shows how many days away the user is from the next streak
- Realized that a new user signing up with no direction on what to do and immediately being shown two dialogs (username dialog and daily reward dialog) should be tweaked
- Created onboarding.dart with new-user onboarding flow that shows up when username == uid (which can now only happen when the user is new as the username setting is unskippable)
- New users now see a welcome dialog, a two-step interactive tour, and a username setup dialog before accessing the app
- showWelcomeTourDialog shows a frosted glass card explaining the tour before it starts
- showUsernameSetupDialog forces new users to set a username before they can proceed, blocking dismissal until one is saved
- generateRandomUsername builds a random AdjectiveNounNumber username (e.g. SwiftFalcon1234) as a suggestion
- buildShowcaseTooltip renders a frosted glass tooltip card used during the tour
- Added a two-step tour overlay directly in HomeScreen using a full-screen GestureDetector with a semi-transparent backdrop
- Step 0 shows a tooltip pinned to the top of the screen describing the main tabs
- Step 1 shows a tooltip describing the footer bar
- Tapping anywhere advances the tour, and tapping on the final step dismisses the overlay and launches the username dialog
- Tour disables all button interactions via IgnorePointer while active so users cannot navigate away mid-tour or quickly tap a button and access the app before the tour is done
- Made helper methods for wrapping dialogs and alertdialogs as main.dart cannot directly give them the frosted-glass look. The dialogs now have a true glass look instead of just being slightly transparent
- Replaced all basic showDialog with the helper method versions

## 2026-05-04
- Fixed updateFoodUserByDate replacing foodDataByDate with just today's and wiping all other food dates in-memory. Now it uses addAll(). This fixed the bug where deleting a food and then changing date would not show the other date's foods
- Fixed the bonus multiplier for bonus XP still awarding a bonus on the day a streak is lost by making it set after claim_daily_reward SQL method updates the streak instead of before
- Fixed missing data in the DailyRewardResponse schema that caused the daily reward to not show the streak data and multiplied values. The correct data was written to the db, but the wrong data was shown on the frontend to the user
- Made the daily dialog show the total xp gained instead of just the bonus xp
- Realized that achievements are only validated in terms of their name, but not in terms of tiers, which meant that someone could send fake achievement requests to the server for tiers higher than possible
- Fixed this by storing the max possible tier of achievements server-side in ACHIEVEMENT_VALID_TIERS so they cannot be bypassed, and then using the data as validation before trying to claim an achievement
- After this change, realized that the achievement definitions could just live on the backend entirely. This would prevent sending fake values, and would also allow achievements to be updated server-side instead of having to update the whole app to make new tiers / achievements
- Replaced the hardcoded achievementDefs list in badges.dart and the separate set literals in valid_achievements.py with a single ACHIEVEMENT_DEFINITIONS list in valid_achievements.py as the source of truth
- SERVER_ACHIEVEMENT_IDS, TRIVIAL_ACHIEVEMENT_IDS, VALID_ACHIEVEMENT_IDS, and ACHIEVEMENT_VALID_TIERS are all derived from ACHIEVEMENT_DEFINITIONS so there is only one place to update when adding achievements
- Added a /get_achievement_defs route that returns the definitions without server_tracked, since that is an internal field
- Added AchievementDefItem schema for the response
- Added fetchAchievementDefs to user_data_manager.dart which calls the new endpoint without auth since definitions are public
- Badges tab now fetches definitions at runtime alongside progress and streaks in _fetchBadgesData, building AchievementDef objects by merging the fetched data with a local icon map
- Icons stay client-side since IconData is Flutter-specific
- Added more tiers to existing achievements
- Made it so the daily reward dialog is awaited for new users so that it does not appear before the onboarding flow
- Made isNewUser a getter so it is computed on demand and used to gate the initializeUser() daily dialog from new users
- New users get a separate block that runs the daily dialog after the tour finishes
- Updated the onboarding tour to also mention the settings drawer
- Fixed a bug where clicking browser notification dialog buttons did nothing. showBrowserBlockedDialog was called from FcmService.initialize, which receives its BuildContext from AppShell in router.dart. The buttons were pre-built TextButton widgets whose onPressed closures captured that outer context. By the time a user tapped a button, the outer context's element could be unmounted, causing Navigator.of(context) to return null and throw. The fix rewrites the dialog to use showFrostedDialog with a Builder child so the buttons capture ctx, a fresh BuildContext that is alive for the entire lifetime of the dialog
- Fixed the theme color picker dialog laying out the hue slider to the right of the spectrum instead of below it. The ColorPicker widget from flutter_colorpicker switches to a side-by-side layout when its parent gives it more width than its colorPickerWidth. Even after adding Responsive.dialogWidth, the content area after card padding was still wide enough to trigger the side-by-side layout. The fix bypasses showFrostedDialog for this dialog and uses showDialog directly with IntrinsicWidth wrapping the frosted card. Since ColorPicker has a fixed colorPickerWidth of 280, IntrinsicWidth snaps the dialog to exactly that width on every screen size, leaving no slack for the side-by-side layout to trigger
- Added Responsive.dialogWidth to responsive.dart which returns a screen-fraction-based width per device type (88% mobile, 65% tablet, 40% desktop) capped at a configurable maxWidth
- Fixed a visual jitter when returning from Personal Preferences after setting nutrition goals. Both goal entry points in Food Logging were calling refreshUserData() and _syncFoodData() on return, causing an unnecessary backend round-trip. Since updateGoals() already updates currentUserData in place on success, a setState() is sufficient to reflect the new values immediately
- Added privacy policy and terms of service files
- Made the privacy policy and tos text in the registration screen clickable, now leading to the files above
- Moved the version pill into the settings drawer
- Removed the can_claim_daily_reward column from the users table and all backend references to it. The value was never written to the DB, it was always computed from last_daily_claim on the fly. Flutter now computes canClaimDailyReward directly from last_daily_claim using the same 23-hour threshold instead of reading it from the backend response
- Added unit testing for progression_service and snapshot_service
- Added favicons to the privacy policy and terms of service pages

## 2026-05-05
- Created a custom skeletonizer for Badges since the old one no longer works due to all the data coming from the backend
- Removed didChangeDependencies because it is no longer needed. The skeletonizer reloads normally because the data comes from the backend
- Added a confirmation dialog for deleting Reminders
- Added a snackbar on Reminder deletion
- Renamed syncFoodData to refreshAndLoadFood to be more accurate
- Removed refreshAndLoadFood from _loadUserDataAndInit because refreshUserData already gets the food data, so it was doing two reads for the same data
- Stored whether meal cards were expanded or not using SharedPreferences so they don't force-open when a user revisits the tab
- Added a refresh button to the Food Logging tab
- Made a _logRecentWithServingPicker method so that a dialog appears when a user logs a food from recent foods so they can directly edit the serving size before serving instead of having to do so after
- Configured the app for Google Play Store release: updated application ID, Firebase Android options, release signing config, ProGuard rules, FCM messaging dependency, and AndroidManifest permissions
- Moved web-only JS interop in the notification service, settings drawer, and image crop handler behind conditional imports so the app compiles on Android
- Fixed various Android build configuration issues until the app successfully compiled and installed as an APK

## 2026-05-06
- Replaced print statements in backend code with logger messages to differentiate warnings vs errors etc
- Wrapped debugPrint messages in Flutter code with if (kDebugMode) so they don't appear in production
- Added UCropActivity to AndroidManifest to fix a bug where the image cropper would cause the Android version of the app to crash
- Moved Android notification permission request from app startup to when the user opens the reminders tab, so the prompt appears in context rather than on the loading screen
- When OS notifications are denied, the reminders form is disabled and the Set Reminder button immediately shows a blocked dialog instead of letting the user fill out the form
- showBrowserBlockedDialog now only triggers on web; on Android a null FCM token at startup no longer shows a dialog since permission is requested contextually
- Made new-user-specific daily claim dialog request notification permissions for Android users
- Made the Explore tab buttons use frosted glass themes to match the rest of the app
- Updated the back button and refresh buttons as they looked too bare
- Fixed the pixel overflow error for the Nearby Experience Spots card
- Changed the card name to "Nearby Spots"

## 2026-05-07
- Changed the index.html meta description
- Made footer divider the same thickness as the others

## 2026-05-08
- Realized achievement handling is not atomic. For example, checking into a POI handles the visit atomically using row-level locking in an RPC, but the achievement itself is handled after in Python. If a crash / error happens between the two, the achievement will never write
- Moved the achievement handling out of record_poi_visit and directly into the RPC function, ensuring the achievements are also handled atomically with the visit
- Deleted test_check_in_poi_level_up_tracks_achievement as it is now obsolete
- Added a "delete account" url as per Google Play's requirements
- Added a splash screen instead of just a blank gradient background when the app is loading
- Added removeSplash to main.dart which removes the splash screen once Flutter is ready to prevent the splash screen from being removed too early

## 2026-05-09
- Removed self._track_achievement(uid, "total_achievements") and moved the handling directly into RPC for atomicity
- Used GET DIAGNOSTICS v_rows = ROW_COUNT in the claim_achievement RPC so that total_achievements only gets incremented if the row insert actually happened
- Moved achievement handling for total daily claims and daily claims streak directly into the RPC to ensure atomicity
- Added a "Continue as guest" option so users can view the app before signing up
- Created guest.dart as a single file owning all guest logic: Guest.enter(), Guest.exit(), Guest.block(), Guest.blockOnOpen(), and Guest.defaultUserData
- isGuest and guestNotifier remain in globals.dart since they are imported everywhere; all other guest behaviour lives in Guest
- Guest.blockOnOpen() wraps the WidgetsBinding.instance.addPostFrameCallback pattern so each screen that blocks guests on open is one line in initState
- Leaderboard, Explore, and Badges tabs show a guest-appropriate message and immediately show the block dialog on open
- All write actions (food logging, daily reward, username, goals, app color, profile picture, reminders, notifications) show the block dialog instead of executing
- Search bar and mic button in the food logging screen are disabled for guests so they cannot type or speak before the dialog appears
- Guests bypass the FCM, UTC offset, and backend fetch calls entirely since they serve no purpose without an account
- Router sends guests directly to / after init instead of using the web URL path restoration logic which would redirect them back to /login
- Fixed the padding of the recenter button to align with the Nearby Spots card
- Added a test-account-specific button in the Explore tab that simulates the Explore tab with hardcoded POIs and location
- Searching a food then scanning a barcode would show the search results after the scanning was done, so cleared the table upon a barcode scan
- Made it so the expanded / collapse status of recent foods is stored using SharedPreferences
- Made it so searching for a food first checks the recent foods, and if matches are found it shows a segmented toggle between "Recent" and "Database" instead of the normal search results
- If the search is found in recent foods, it bypasses the 750ms debouncer timer
- Added times_visited and category columns to the poi_visits SQL table so that the corresponding achievements that require that data can be wired up correctly
- Added poi_category to the CheckInPOI request body, threading it through the service and repository layers down to the record_poi_visit RPC
- Wired up poi_categories and poi_regular achievements directly inside record_poi_visit using COUNT(DISTINCT category) and MAX(times_visited) on the poi_visits table
- Wired up food_barcode, food_manual, and food_recent achievements
- Made the search table clear when a failed barcode lookup occurs after the user uses the search bar without selecting anything
- Fixed setDailyRewardNotification crashing on null currentUser and silently failing on network errors by adding a null check, try/catch, and a 5-second timeout
- Updated the privacy policy and linked to the delete-account page
- Added 5-second timeouts to the leaderboard fetch and set_reminder calls to prevent indefinite hangs on slow connections

## 2026-05-10
- Changed the maskable icons to have a white background instead of purple
- Fixed a small typo in the activity multiplier of calorie calculator
- Defined fcmVapidKey once in user_data_manager instead of individually defining it each time
- Replaced repeated maxFileSize code with one maxProfileImageBytes const
- Moved the pfp-related code to its own service class
- Created authenticatedPost() to remove the repeated pattern of manually attaching the id_token, Content-Type header, and timeout to every backend HTTP call
- Extracted the default app color values as a const in globals.dart for better clarity
- Added more comments for better readability and maintainability
- Fixed a bug where searching for a food, having it appear under "Recent Foods", and then clicking and changing the serving size would log the original serving size stored, not the updated one
- This didn't happen when logging a food from the Recent foods that is always there because it uses its own scaling logic
- Fixed by moving all the scaling logic to logFood
- Added a delete button for recent food entries and a removeRecentFood method that removes a single food entry from the sharedpreferences entries

## 2026-05-11
- Replaced the inline "Failed to load" frosted glass card in HomeScreen with a proper showFrostedAlertDialog so it no longer glitches with underlined text against the background
- Prevented the login screen buttons from taking up the whole width on desktop
- Made it so continuing with google does not let users bypass the tos and privacy policy check
- Redesigned the login screen UI slightly
- Made claimable achievements pulse in the badges tab to emphasize it is claimable

## 2026-05-12
- Made the cards that appear when a user clicks a POI consistent with the glass-like appearance of the Nearby Spots card
- Made the "Find nearby spots" button and overlay text align with the rest of the app style
- Added an "Open in Maps" option when clicking on a POI using the map_launcher package, which detects installed maps apps and shows a picker if multiple are installed, falling back to Google Maps on web
- Updated "POI" text in badges to "locations"
- Made most tabs use a centeredHorizontalPadding method that prevents desktop device content from spanning the whole screen and stretching too far
- Updated the UI of the Developer tab

## 2026-05-13
- Used the google_sign_in package for Android and iOS to prevent the white screen error that appears even on successful logins, along with adding a more native feel to logging in with Google
- Fixed buttons in Developer tab lightening up when scrolling by using the same NoGlowScrollBehavior class HomeScreen.dart had
- Moved the NoGlowScrollBehavior to globals.dart from home screen file
- Added a button in the Developer tab that leads to developer website
- Tweaked home buttons so that text does not touch the very edges of the buttons, and automatically resizes to be smaller if it needs to
- Fixed the login screen cutting off the Google button on short phones by subtracting SafeArea insets from the column's minHeight so it fills the actual usable space instead of the full screen height
- Made the google_sign_in picker always appear when a user taps on it instead of auto-signing into their last used account
- Made exiting Guest mode more obvious by replacing the footer on the home screen with a sign up button
- Fixed the LEVEL UP! title overlapping the settings icon on narrow screens by adding symmetric horizontal padding equal to the button width
- On native Android the app renders behind the status bar so the title appeared too high — added status bar height to the title's top padding on non-web platforms so it visually aligns with the PWA version
- Added an email field to the users table to prevent bypassing the TOS and Privacy Policy check with "Continue with Google". Upon signup, it checks if the email exists in Supabase, and if it doesn't then it blocks entry and shows a TOS dialog — on native this check runs before Firebase is touched, on web the Firebase session is kept alive after the check fails so the retry skips the popup and routes in directly once the user accepts
- Added backend route check_user_email_exists that checks if the email exists in the users table

## 2026-05-14
- Used the hugeicons package to replace defualt Material icons with more modern icons
- Added a box decoration around the icons in the Badges tab
- Added the missing border to Badges tab between header and body so it is consistent with the other screens
- Updated authDomain from firebase to the website domain to fix sessionStorage being lost when pressing Continue with Google
- Removed the hard-coded colors in the Food Analytics tab
- Replaced the pie charts with bar charts so using uniform colors stays readable
- Replaced Material icons with hugeicons package for the Food Analytics tab
- Added the desktop width constraint to the Food Analytics tab
- Renamed food_logging_charts file to food_analytics

## 2026-05-16
- Moved calories under the percentage in the bar charts so they don't intersect for different meals
- Removed the white line under the tab picker in Food Analytics
- Made checking into a POI last for a few more seconds so the user can see the xp better
- Made the "finding more spots" text appear directly below the card header so it is visible when the card is collapsed
- Changed the confetti style on POI check ins to make it less intense and to show more shapes
- Made the confetti in the explore tab begin above the screen
- Moved the confetti in the Explore tab to confetti.dart
- Unified the padding across all screens to feel more consistent across the app
- Fixed the frosted alert dialogs looking like they had two separate borders on wider screens by wrapping it in its own border and removing the default border of Dialog
- Made a showCalcDialog method that builds a mini calculator that supports basic operations and is wrapped in a frosted dialog
- Added a calcSuffixIcon method that adds a calculator icon button to the "Serving Size" dialogs that opens the calculator when clicked
- The calculator is pre-filled with what was last stored for the serving size dialog
- Fixed the calculator logic so order of operations are followed
- Made it so the expression calculates * and / first, then goes through the list again after and handles + and -

## 2026-05-17
- Added the food logging calculator icon to the Serving Amount card
- Updated the Privacy Policy to make sure it is as accurate as possible
- Removed enablePersistence() call in index.html as Firestore is no longer used for backend
- Self-hosted cropper.js so Edge's tracking prevention stops blocking it
- Added an onSet callback to calcSuffixIcon so it can update the nutrition info in the serving card when the user calculates a new serving amount
- Made negative values in the calculator clamp to 0
- Guarded division by 0 in the calculator
- Made operator buttons in the calculator bigger
- Added an outline border in the calculator for the inner section
- Added a back button to the calculator
- Replaced the spinner in the Explore tab with a pulsing globe icon
- Made the app color luminance threshold lower and the multiplier higher to prevent lighter theme colors even more drastically
- Fixed the border between the app bar and the body of the screens being obscured by the gradient with a Stack with the border on top of the screens
- Fixed the double border bug on the update app color dialog
- Added a workflow for auto daily database backups
- Added get_public_tables to functions.sql so the workflow can dynamically get all the tables instead of having to manually update it with new ones every time

## 2026-05-18
- Replaced the plain underline TabBar in Badges, Food Analytics, and Calorie Results with a frosted pill-style indicator using a BoxDecoration with rounded corners and a subtle border
- Moved the tab bar out of the AppBar bottom and into the body as a Column so it inherits the gradient background instead of the AppBar color
- Made the tab bar center on desktop and left-align on mobile using TabAlignment
- Applied a matching pill-shaped splash/hover radius so the ripple effect stays within the pill bounds
- Increased tab font size from 13 to 15 and kept Manrope font consistent across all tab bars
- Updated the "how to _____ weight" card in Results so it matches the UI with the other cards
- Replaced BMR and TDEE text with the full name
- Made the male and female icons use appColor instead of hardcoded colors
- Made the TDEE formula appear in its own card instead of being a line in the Activity Multiplier card
- Tightened the constraints for minimum zoom and added panning to the Explore map
- Added some new achievements for food logging: Using the serving calculator, night owl, early bird

## 2026-05-19
- Made the number of Recent Foods that are stored customizable instead of being fixed at 30
- 0 is used for unlimited, using a const unlimited = 0
- Added a button in Personal Preferences to update the number of stored recent foods
- Edited Recent Tab searches to also make the brand name searchable
- Overhauled the registration/login screen UI
- Replaced "Welcome" title with "Level Up!" and updated the subtitle
- Replaced the frosted glass Log In/Sign Up buttons with an orange gradient button with a matching border
- Increased input field height via content padding for better tap targets
- Replaced moving background orbs with two subtle static radial gradient blooms
- Moved "Continue as guest" below the Google button inside an IntrinsicWidth so both buttons share the same width
- Replaced "Continue as guest" with OutlinedButton.icon using the anonymous Hugeicons icon
- Removed the Set Reminder button from the Reminders tab. Reminders are set when the time is chosen
- Moved the notes section of the Reminders tab into an alert dialog that opens when a help button is pressed in the top right of the reminders screen
- Added a border around the Enter Reminder Time box

## 2026-05-22
- Created app_shell.dart, a persistent shell widget that wraps all 5 tab screens and hosts the floating nav bar
- Created floating_nav_bar.dart, the frosted glass pill nav bar with icons, labels, and animated active state
- Replaced the home screen button grid with a dashboard layout
- Added a floating frosted glass bottom navigation bar with 5 persistent tabs: Home, Food Logging, Explore, Leaderboard, Badges
- Refactored the router to use StatefulShellRoute.indexedStack so each tab keeps its own navigation stack and scroll position
- Reminders and Calorie Calculator moved to compact tool tiles on the home dashboard
- Home dashboard shows a greeting, XP progress card, daily reward card with countdown timer, streak card, quick stats, and recent activity
- XP card is the same as how it was in footer, but changed its outline to match the style of the screen better
- Daily reward card shows countdown timer to the next available claim
- Streak card shows food logging streak and daily claim streaks
- Added daily_streak field to get_user_data backend response and GetUserDataResponse schema
- Added dailyClaimStreak field to UserData model so the data can be cached in memory
- Quick stats row shows calories today with a mini progress bar and food items logged today
- Calories progress bar styled to match food logging screen
- Recent activity section shows last 3 foods logged from local cache
- Back buttons removed from Food Logging, Leaderboard, and Badges since they are now persistent tabs
- Explore tab back button changed to navigate home instead of popping
- Nav bar is hidden on Explore tab to keep the map unobstructed
- Nav bar labels shown for all 5 tabs, and the active tab label is larger and bolder
- Daily and Range tabs in Food Analytics now fill the full width on mobile instead of aligning at the center
- Added subtle border around XP bar, calorie bar in food logging, and calorie bar on home screen
- Refreshed the settings drawer after the onboarding flow so a new user immediately sees their chosen name in the drawer instead of "Unnamed"
- Since Home Screen is now persistent and doesn't rebuild when navigated to, added activate() that refreshes its contents when teh user goes back to the home screen so that it stays up-to-date
- Added a few random greetings based on time to make them feel more personalized
- Moved the guest banner from a sticky footer to a card at the top of the home dashboard
- Updated the onboarding tour tooltip text to describe the new dashboard and floating nav bar instead of the old button grid and footer
- Fixed app color not updating on persistent tabs by wrapping AppShell in a ValueListenableBuilder on appColorNotifier, forcing all tabs to rebuild when the color changes
- Reverted the AppShell ValueListenableBuilder after it caused a MediaQuery crash in dialogs opened from push routes over the shell
- Fixed app color not updating on persistent tabs by adding appColorNotifier listeners directly to Food Logging, Leaderboard, Badges, and Explore state classes
- Fixed "Maybe Later" in the guest block dialog crashing by using Navigator.of(context, rootNavigator: true).pop() and added useRootNavigator: true to showFrostedDialog
- Fixed greeting changing on every rebuild by storing the random index once at widget creation time using millisecondsSinceEpoch
- Fixed Log Food and Food Analytics screens crashing when opened by adding parentNavigatorKey pointing to the root navigator so they push over the shell instead of inside the branch navigator
- Added a root navigator key to GoRouter so sub-routes can reference it via parentNavigatorKey to push over the shell

## 2026-05-23
- Fixed daily reward dialog not appearing when resuming the app from background by implementing WidgetsBindingObserver and didChangeAppLifecycleState
- Fixed daily reward card continuing to show "ready to claim" state after the reward was already claimed by adding a setState after the dialog resolves
- Fixed XP bar re-animating from zero on every rebuild by tracking the last rendered XP value and using it as the animation start point
- Fixed recently logged foods not updating on the home screen after logging a new food by introducing a global foodLogNotifier that the home screen listens to
- Fixed food logging streak resetting to zero mid-day when no food had been logged yet by starting the streak calculation from yesterday if today is empty
- Replaced the home screen's food log streak being calculated client-side with a backend fetch because the client-side method is inaccurate and may count unvalidated streaks created client-side that don't match the real stored streaks
- Since fetchStreaks() already gets all the streak data, added dailyClaimStreakBest and foodLogStreakBest to UserData to store highest_streak to be shown on the home screen dashboard in the streaks section
- Daily claim streak now updates immediately in currentUserData after claiming since the value is already in the claim response, so the home screen reflects it on the next setState without a reload
- Food log streak refetches from the backend only when today's date differs from foodLogStreakLastDate (stored in UserData from the streak row on load), since the streak only changes on a new consecutive day
- Redesigned the home screen header: removed the standalone app bar and replaced it with a two-line greeting inline with the screen and time of day in small caps above the username in bold
- Removed the recently logged section from the home screen since it doesn't provide useful information and reads from local device cache rather than actual food log history, making it inaccurate
- Daily reward card now shows a checkmark on the right when claimed instead of hiding the trailing icon
- Calories today icon changed from fork and knife to fire, foods logged label changed to logs today, and streak day count is now larger than the days label
- foodLogNotifier increments on food delete and edit in addition to log, so all mutations trigger a home screen refresh
- Made the notch section of the Android version of the app transparent
- Removed the appbar from the main tabs accessible through the bottom navigation bar
- Added guest-specific placeholder text to the home screen

## 2026-05-24
- Replaced currentUserData with a ValueNotifier so that whenever userData updates, the screens automatically update rather than having to manually remember to create ValueNotifiers for the necessary data changes
- This creates one source of truth rather than possibly forgetting to update separate screens that depend on actions that happened in another screen
- Subclassed ValueNotifier into UserDataNotifier to expose notifyListeners() publicly, since ValueNotifier only fires listeners when the object reference changes and UserData is mutated in place rather than replaced
- Fixed the logout confirmation dialog: the cancel button was popping the drawer instead of the dialog because the dialog was shown without await and without rootNavigator: true, leaving the navigation stack broken
- Cancel now correctly dismisses only the dialog and confirm closes the drawer before signing out
- Moved the app version text so it does not get blocked by the bottom navigation bar
- Wrapped the settings drawer icon in backdrop blur so it matches the theme of the rest of the home screen
- Added a slight appColor tone to the settings drawer icon so it is not fully white

## 2026-05-25
- Fixed blank screen when pressing Claim on the daily reward dialog by wrapping the button in a Builder so it closes using the dialog's own context rather than the stale outer context
- Migrated the backend toward RESTful conventions: read-only endpoints (progress, user_data, streaks, leaderboard, reminders, achievements) are now GET routes with noun-only paths
- Firebase ID token moved from the request body to the Authorization header on all routes
- _parse_and_auth was split into _get_token, _parse_body, and _try_verify_token helpers
- Removed request schemas that only existed to carry id_token, since auth is now handled entirely by the header
- Added authenticatedGet helper in Flutter alongside authenticatedPost
- Both attach the token as a Bearer header instead of in the body

## 2026-05-26
- Updated the Browser Notification dialog to appear consistent with other dialogs
- Replaced hard-coded white colors with user app color variants
- Tweaked sizes of borders / text
- Added a font to POI categories in Explore tab
- Made the Tools section of the Home Screen have a different shape to differentiate itself
- Added animated accent dot under the active nav bar tab
- Replaced date navigation row card wrapper with plain inline arrows using HugeIcons
- Made sectionHeader use app color instead of gray
- Settings icon button fill now uses a lightened app color tint instead of near-invisible white
- Profile picture border in the settings drawer now uses a darkened app color instead of plain white
- Added percentage labels centered inside each macro gauge on the food logging screen
- Filtered tester_account out of the leaderboard
- Improved achievement card visuals: progress bar fill uses a lighter app color, description and progress count use accent color, icon container has a more defined tinted background
- Achievement title is now larger, bolder, and uses the accent color
- Tier chips now have a frosted glass look with backdrop blur and colored borders
- Achievement icon container uses a plain tinted border matching the icon color

## 2026-05-31
- Fixed daily reward card not being claimable without restarting the app if the user's cooldown passed while the app was already initialized
- canClaimDailyReward now recalculates live instead of relying on the cached value set at initialization
- Replaced magic numbers for the daily cooldown in seconds with variables in both frontend and backend
- Replaced hardcoded snackbar durations with a snackBarDuration variables and made all snackbars use the variable for consistent snackbar durations
- Added sign_up event handling for Firebase Analytics
- Edited the greeting text to specifically show a welcome greeting for new users
- Used the in_app_reviews package and added a new dialog into the onboarding flow that prompts new users to review the app
- Added status bar height to the onboarding dialog padding to "Your dashboard" and "Settings" dialogs so they don't intersect with notch bar on Android
- Added a web fallback for the review button to directly open a link to the app on Google Play
- Added a "Leave a Review" button in the Settings dialog which directly opens the Google Play page for the app (as there are API limits for natively prompting users for a review)
- Fixed the double border dialog bug on the onboarding dialogs
- Made the settings drawer shorter on mobile and tablet screens to prevent it from intersecting with the bottom nav bar

## 2026-06-02
- Integrated Google AdMob rewarded ads: added the package, AdMob App ID to AndroidManifest, and an AdService that preloads and shows rewarded ads
- Added server-side verification via a /admob_ssv backend route that verifies Google's ECDSA signature before awarding XP, with an atomic SQL RPC to prevent double-awarding
- XP awarded per ad is 5-10% of what the user needs to reach the next level
- Added Earn XP card to the Home screen for Android users to watch ads for XP
- Fixed app bar heights being too large on Android notch devices by subtracting the status bar height from the toolbar height
- Fixed Reminders and Calorie Calculator tool cards having different heights by wrapping them in IntrinsicHeight
- Added a Leave a Review button to the Settings drawer
- Added an in-app review prompt at the end of the new user onboarding flow
- Shortened the settings drawer on mobile and tablet so it clears the floating nav bar
- Wrote tests for the new ad-related backend code
- Fixed a bug where streak-based achievements (On a Roll, Consistency) could not be claimed after a streak broke, even if the user had previously reached the tier
- Limited serving size input fields to 5 digits before the decimal and 2 after, preventing arbitrarily large values
- Limited nutrition goal inputs (calories, protein, carbs, fat) to digits only with a 4-digit cap
- Added a snackbar confirmation when changing the Recent Foods limit in settings
- Made the food calculator limit to 5 digits to prevent bypassing the 5-digit limit
- Updated Privacy Policy to disclose AdMob addition
- Updated fatSecret and OpenFoodFacts attributions to fully comply with their terms
- Added attribution text for Guests on the Food Logging screen to comply with fatSecret terms that attribution must be visible without logging in

## 2026-06-06
- Made the "Best" text for streaks on the home dashboard refresh if the user claimed their daily reward to achieve a new best streak rather than showing the stale value
- Sorted the leaderboards by UID to make it deterministic

## 2026-06-07
- Added a referrals table to track referral relationships between users
- Added referral_code column to the users table, generated lazily on first request with collision checking
- Added GET /referral_code and POST /referral_code backend endpoints: GET returns the existing code, POST generates and stores a unique 8-character alphanumeric code as a fallback when none exists
- Added ReferralCodeResponse schema for the above endpoints
- Added get_referral_code, create_referral_code, referral_code_exists, and store_referral_code methods to the service and repository layers
- Added referral_code to GetUserDataResponse schema, get_user_data service method, and UserData model so the code is available on app load
- Added an Earn XP section to the home dashboard with two side-by-side cards: Watch an Ad and Refer a Friend
- Watch an Ad card shows a "coming soon" dialog on Android and a "get the app" dialog on web
- Refer a Friend card shows the user's referral code (fetched live with a GET/POST fallback), a copy button, referred count, and a field for new users to enter a code they received
- Added instructions to the referral dialog stating the referred user must reach level 3 for both users to gain XP
- Added achievements for referring users (1, 2, 3 referred)
- Added a use_referral route that is responsible for validating and using the referral code
- /use_referral calls use_referral in services.py which calls use_referral in repository.py which calls the use_referral RPC method which has row-level locking to ensure atomicity
- The RPC method also ensures that if user A refers user B, user B can't refer user A, and ensures a user can't refer themselves
- The RPC method also ensures the referred user is a high enough level (level 3 or above) and that the user who owns the referral_code has their achievement progress for referrals incremented
- Wired up the modal so that users can type in a code and press submit to call the /use_referral route
- Limited the input code to strictly allow up to 8 alphanumeric characters
- Added UseReferralRequest schema for the /use_referral route
- Added a Social tab to the Badges screen with the new referrals achievement
- Updated use_referral RPC to award XP to the referee atomically on code submission, using max(500, xp_needed * 0.75), handling level-ups and updating achievement progress
- Added experience_needed SQL function mirroring the Dart/Python formula so the RPC can calculate XP thresholds server-side
- Added referee_xp_awarded, referrer_xp_awarded, and referrer_notified columns to the referrals table
- Added GET /pending_referral_reward and POST /claim_referral_reward endpoints for the referrer reward flow
- Added claim_referral_reward RPC that atomically awards XP to the referrer and marks the referral as complete
- Added a referral reward popup that appears on app load after the daily reward dialog, showing who used the referrer's code with a claim button
- Claiming the referral reward updates the XP bar and level immediately on the client
- Referee's XP bar and level update immediately on successful code submission
- Service layer wraps Postgres exceptions from use_referral and claim_referral_reward as ValueError for clean 409 responses
- Moved referral-related code from home screen to a new referrals.dart file
- Added UseReferralResponse, ClaimReferralRewardRequest, and ClaimReferralRewardResponse schemas
- Wrote unit tests for get_referral_code, create_referral_code, use_referral, and claim_referral_reward service methods
- Replaced the hardcoded "0 friends referred" with the real amount received from the backend that is stored in UserData
- Added a has_used_referral method to return if the user has used a referral code before
- Replaced the "Have a referral code?" section for users who have already entered a referral code with text saying they've already used it for better UX

## 2026-06-08
- Replaced the ElevatedButton with frostedButton for the "Get Results" button in Calorie Calculator
- Height and weight sliders in Calorie Calculator now show "Slide to choose" when null instead of defaulting to a preset value
- Added a _showOverpassFallbackDialog method that appears when all Overpass endpoints fail (503), prompting the user to generate server-side fake POIs instead
- Added a "Generate nearby spots" button in the Nearby Spots card that shows when Overpass is unavailable or when a real fetch returns no results
- Added POST /generate_fake_pois backend route and generate_fake_pois service method that creates 10 plausible named POIs with randomized coordinates within 400m of the user
- Added generateFakePOIs method to the Flutter POI service that calls the new endpoint and returns POI objects in the same format as real POIs
- Wired up the Generate button to call generateFakePOIs, populate the POI list, open the card, and add markers to the map
- Changed createTitle font from spaceGrotesk to manrope for consistency with the rest of the app
- Added BILLING permission to AndroidManifest for in-app purchases
- Added a usingFakePOIs flag so fake POIs are preserved across location changes until a real fetch succeeds
- Added an overpassDialogShown flag to prevent the dialog from stacking multiple copies
- Edited timeout duration for Overpass calls
- Stale cached POIs are cleared immediately when the position stream fires a new location so the skeleton shows instead of showing the old list while fetching
- Non-overpass errors (moving too fast, generic failures) now show an inline error message and a retry button in the Nearby Spots card instead of leaving it empty
- Position stream fetches are no longer debounced so rapid location changes always trigger a fresh fetch
- An empty cached POI list is treated as a cache miss so a fresh backend fetch is always attempted instead of silently showing nothing
- Lowered Calorie Results appBar height to be consistent with other tabs
- Added inline "Update weight goal" buttons into Calorie Results for convenience
- Updated updateGoals() so it only updates non-null field changes
- Watch an Ad card is dimmed and shows a "Coming Soon" dialog on tap until AdMob is approved
- Refer a Friend count repositioned to the bottom right of the card
- Referral code reuse message updated to clarify each account can only enter a code once but can refer unlimited friends
- Nearby Spots card top padding now accounts for the Android status bar height to prevent overlap with the notch

## 2026-06-09
- Added a profanity filter for usernames
- Added chevrons to the Tools cards in the Home screen
- Wrapped "Calorie Calculator" card in Flexible to prevent "Calculator" text from clipping sometimes
- Overhauled the Badges tab UI: cards now use a deep frosted glass container with a colored left accent bar that reflects claim state (bright when claimable, dim when locked, tinted when complete)
- Replaced the tier chip Wrap with a horizontally swipeable PageView carousel using a frosted glass pill container styled like the bottom nav bar
- Single-tier achievements render the chip inline
- Tier chips redesigned as circles with an icon and number
- Claimable tier chips pulse with alternating phase: even-index chips use one shared AnimationController and odd-index chips use another started 600ms later
- Added an animated progress bar that fills from zero on load using a dedicated AnimationController with easeOutCubic curve
- Added milestone marker ticks on the progress bar at each tier threshold using LayoutBuilder for accurate pixel positioning
- Progress label now shows both current/next count and a percentage on the right
- Added "X to claim" frosted pill badge in the card header when unclaimed tiers are available
- Added a checkmark icon in the header when all tiers are complete
- Added an empty state for sections with no achievements
- Wrapped all cards in Skeleton.ignore to prevent skeletonizer from crashing on BackdropFilter widgets
- Added a refresh button to the Badges tab styled consistently with the leaderboard refresh button
- Replaced the skeletonizer placeholder with a custom skeleton card matching the new card layout
- Added dot indicators below the tier carousel to show scrollability
- Carousel capped at a max width on desktop and centered so it doesn't stretch across the full card
- Category tabs swipe between sections, single-tier achievements skip the carousel entirely and render the chip inline centered
- Removed unused _skeletonDefs and moved skeleton rendering to a _buildSkeletonCard method
- Moved the refresh button above the tabs in Badges
- Made refreshing the Badges tab stay on the currently selected tab with a tabController variable instead of defaulting to the first tab
- Updated the profanity filter to directly use the library's contains_profanity method
- Added firebase analytics event for reaching level 3
- Progress bar in badge cards is now static instead of animating on every tab switch
- Badge cards slide in with a staggered fade when a section loads
- Made badge tiers freely scrollable
- Added NoGlowScrollBehavior class to Badges to prevent widgets lightening up

## 2026-06-10
- Desktop layout now scales height values by 1.6x so spacing and cards feel proportional on wide screens
- Removed .fadeIn from the Badges entrance to remove the scroll overlay issue upon entrance
- Increased the slide amount on the Badges entrance
- Made the Badges animation only play one time in total instead of once per tab switch
- Decreased max desktop width from 900px to 800px
- Increased max size of the tier chip holder on desktop
- Refreshing the browser now restores the current screen instead of redirecting to the home tab
- Moved confetti controller initialization to main() so it works when landing directly on any screen
- Added a changelog screen accessible by tapping the version text in the settings drawer (this screen!)
- Added a chevron to the version text to show it is clickable
- Added a route connecting to the changelog screen
- Replaced the app icon with a new pixelated heart design across Android, iOS, and web
- Configured adaptive icon layers for Android with separate background and foreground PNGs
- Updated registration page colors to align with the new logo
- Added the desktop centeredHorzontalPadding to the Install as PWA page
- Added a "total xp" text to the progress bar card in the home screen
- Added a totalXpEarned method
- Added a formatNumber method to shrink big numbers

## 2026-06-12
- Deferred AdMob initialization to after runApp so it no longer blocks the app's cold start time
- Created a progression screen
- Added a Progress tab in the nav bar which replaces the Badges and Leaderboard tabs
- Added a Workout tab to the bottom nav bar leading to a currently empty workout screen
- Rearranged the bottom nav bar tabs
- Added cards in the progression tab leading to Badges and Leaderboard screens
- Created push routes for Badges and Leaderboard as they are now accessible through cards in the Progress tab
- Added back buttons to Badges and Leaderboard tabs
- Added workout-related SQL tables (workout tables: 1 for each workout, workout_exercises table: 1 for each exercise in each workout, workout_sets: 1 for each set of each exercise in each workout)
- Added SQL tables for workout templates for reusable routines
- Added weekly_workout_goal to the goals table
- Added a card for setting weekly_workout_goal in Personal Preferences
- Limited the workout goal entry to 1-3 digits
- Added weeklyWorkoutGoal to UserData
- Edited updatedGoals method to also include weeklyWorkoutGoal
- Edited update_goals in the backend to accept weekly_workout_goal
- Edited user_data in the backend to load weekly_workout_goal
- Edited UpdateGoalsRequest to handle the weekly workout goal
- Added a /leaderboard_standing GET endpoint with accompanying methods for getting the user's leadederboard rank and # of total users
- Added tests for the above methods
- Added indexing to users by rank to efficiently get ranks
- Added a count_users_above_rank RPC function to efficiently calculate users above a specific user for calculating the user's rank
- Added cards in the Progress tab showing the user's current rank out of the current total user count
- Added skeletonizers for the cards above
- Added Firebase Analytics screen tracking for all tab screens and push routes so Firebase reports actual screen names instead of only MainActivity

## 2026-06-14
- Set up Unity Ads to be used as mediation when AdMob is not available
- Added a /unity_ssv route for verifying the Unity Ads-specific ads
- The verification route will be wired up when approved
- Edited ad_service.dart to handle the Unity fallback
- Moved ad service initialization into ad_service.dart
- Removed the Coming Soon text on the Ad card
- Added a fallback to the ad card when no Ads load
- Hid "Your Rank" and "Total Users" cards from guests
- Added back buttons in the Badges and Leaderboard tabs for guests
- Blocked guests from initializing location in the Explore tab
- Removed the app theme gradient for a cleaner look
- Made the settings button smaller to be more proportional to the greeting text
- Updated app logo color to a blue gradient
- Completely redesigned the login/register screen layout and visual style
- Replaced the old single-page email form with a two-mode flow: an initial landing view and an expandable email form
- Added a "Continue with Google" button and "Continue as a guest" button to the landing view
- Added a "Continue with email instead" link that slides in the full email/password form
- Added a segmented Log In / Sign Up toggle that animates between modes with a sliding pill highlight
- Added animated feature chips (Track, Progress, Compete) to the landing view
- Added an XP preview card on the landing view showing Level 1 and 0 / 130 XP to preview the progression system
- Google sign-in gates users behind a TOS checkbox that slides in on first tap before proceeding
- The TOS checkbox auto-triggers Google sign-in once checked on the landing view
- Replaced the pink/magenta color scheme with a blue gradient (cyan to dark blue) to match the new app logo color
- Replaced the SVG-based Google button with a custom styled button using the Google logo PNG asset
- Added desktop padding to the login screen
- Tweaked the progress bar on the login screen to be narrower than the continue buttons
- Added a divider between the progress bar on the login screen and the continue buttons
- Removed IntrinsicHeight to fix overflow errors
- Added top and bottom padding to the initial registration UI so components don't touch the top and bottom on small screens
- Fixed overflow error in settings drawer for long usernames
- Added a guard to prevent sending blank usernames on onboarding
- Made error messages for usernames that are too long specific instead of showing generic "Invalid request"
- Fixed an overflow error on Android in onboarding when the user's keyboard appeared for entering their username
- Removed the prompt to review in onboarding (the function still exists in case it will be used at another time)
- Merged "Your Rank" and "Total Users" into one card and added a new percentage component to it, stating "Top X% of users"

## 2026-06-15
- Made the XP bar in the Home Screen only fill in after the skeletonizer finishes loading
- Redesigned the home screen action cards (Watch an Ad, Refer a Friend, Daily Reward) to use a gradient fill with a subtle border and no frosted glass, giving them a more distinct and elevated appearance
- Added a cardColors() utility in globals.dart that returns a consistent set of surface colors (gradient, border, icon box, splash, highlight, onCard text) derived from the theme color using perceptually uniform Oklab color shifts
- Implemented Oklab color space conversion in globals.dart (sRGB linearization, Oklab forward/inverse transforms) so card lightness steps look visually equal regardless of hue, fixing the issue where light cards appeared too similar to the background with HSL-only shifts
- Branching logic in cardColors() now uses WCAG relative luminance instead of HSL lightness, correctly identifying saturated colors like red as perceptually dark rather than mid-tone
- frostedGlassCard() updated to use the cardColors() gradient and border by default, so all informational cards across the app automatically match the action card style
- The floating nav bar now adapts its fill, border, and icon/label colors based on the theme color's luminance, using a white glass overlay on dark themes and a white semi-transparent fill with darker text on light themes so it always reads clearly
- Removed drop shadows from all cards for a cleaner, flatter look consistent across the whole screen
- Fixed the floating nav bar's solid background panel that was misaligned on desktop by removing it and applying the blur directly to the nav bar widget itself
- Fixed a bug where entering as a guest, logging out, then logging into an existing account showed the onboarding flow by making Guest.exit() set appReadyNotifier to false (as it stayed true and then ran before the user's data was ready, which assumed the user was null and thus new)
- Added the user's pfp (if it exists) behind the "LVL X" text of the progress bar card
- Wrapped the pfp in an AnimatedSwitcher so it smoothly appears when ready rather than abruptly popping in
- Made dialog buttons consistent: Dismissing is on the left and Confirming is on the right

## 2026-06-16
- Split the your rank and top X% card into two square cards
- Removed the workout tab button in nav bar in preparation for app update
- Made the food streak card show even when the food streak is 0 and has never been set
- Removed the red color of the Log Out text
- Removed confirm logout dialog for guests
- Replaced the lightning icon in the onboarding screen with the app logo
- Fixed the onboarding dialogs from not having a glass-like effect
- Added more random username generation possibilities to reduce collision chances
- Replaced "Tap anywhere to finish" with a pulsing finger icon that appears 5 seconds after each onboarding dialog appears
- Replaced all spaceGrotesk fonts with manrope
- Hid TOS checkbox on Log In page
- Made it so the username dialog in onboarding cannot be dismissed or exited with a gesture
- Edited the goals modal to show a label for chosen fields instead of just a number showing
- Replaced the SegmentedButton for weight goal with frosted pill buttons
- Made "Log Food" buttons bigger
- Tweaked calorie card in Food Logging colors
- Made macro text in Food Analytics more readable on darker themes
- Made the selected tab look less muddy on darker themes
- Made the "generate spots" button be clear instead of using the user's app color
- Made it so the nearby spots card cannot be opened and so the chevron is hidden if the "generate spots" button is available in the card
- Added consts to represent tab index cards
- Added a glow pulse behind the "Retrieving location..." text
- Made it so changing app color animates into the new color from the old color instead of happening instantly
- Fixed a bottom overflow error in the "Update Goals" modal on Android
- Replaced recentServingController with a state-level controller so its lifecycle is managed independently
- Replaced red color on delete icons, trash icons, and confirm buttons across food logging and reminders screens with the app color
- Added a circular bordered background behind the bell icon in reminder cards
- Made reminder card text use the onCard color so it stays readable on light themes
- Replaced the cards in changelog.dart to use frostedGlassCard so they remain readable on light themes
- Made the "Release ..." text more readable on light themes

## 2026-06-18
- Added a units column to the users table that defaults to metric
- Altered the /user_data GET and its schema to retrieve the units column
- Altered UserData to store the units column
- Added a /update_units endpoint with accompanying schema, service, and repository methods
- Added updateUnits() in user_data_manager.dart which calls /update_units and shows a success snackbar
- Added a UNITS section to Personal Preferences with a segmented picker (Metric / Imperial) that saves immediately on tap
- Made calorie calculator units default to the stored units preference on first open when no calculator data is saved
- Added water_logs and weight_logs tables to the database
- Added /upsert_water_log and /upsert_weight_log endpoints with accompanying schemas, service, and repository methods
- Added waterEntriesByDate and weightByDate fields to UserData, mapped from the /user_data response

- Added updateWaterLog() and updateWeightLog() methods in user_data_manager.dart with optimistic UI updates and rollback on failure
- Replaced the STREAKS & STATS section on the home dashboard with a LOGGING section containing a 2x2 grid: Calories Today, Logs Today, Water, and Weight
- Moved Calories Today and Logs Today into the LOGGING section and moved Streaks below TOOLS
- Water and Weight cards show + and chart buttons; + opens a logging sheet, chart shows a coming soon snackbar
- Water logging sheet uses the card gradient style for visual consistency, supports quick-add buttons (+250ml / +500ml / +750ml or oz equivalents), custom amount input, and a scrollable entry list ordered newest-first
- Each water entry shows the amount and a trash icon that confirms before deleting
- The sheet shows an inline feedback pill (Logged! / Removed / No connection) that slides in and fades out after each action
- On network failure, the optimistic UI update is rolled back so the displayed total stays accurate
- Water card total on the home dashboard converts ml to oz automatically based on the stored units preference
- Added a ListenableBuilder on userDataNotifier to the logging section so units and water totals update live when changed from preferences
- Weight logging sheet supports date navigation with left/right arrows and a date picker, pre-fills the input with the existing value for the selected date, and shows Log or Update depending on whether a value already exists
- Shows last 7 logged weight entries as a tappable history list, tapping a row jumps to that date and pre-fills the input
- Each history row shows a trend icon (up/down/same) comparing the entry to the one before it
- Weight card on the home dashboard shows today's logged value converted to lbs or kg based on units preference
- Bottom sheet background updated to use a semi-transparent darkened color with backdrop blur for better readability on saturated themes
- Applied same sheet background style to the food logging custom serving size sheet for consistency
- Added /delete_weight_log endpoint with accompanying schema, service, and repository methods
- Added deleteWeightLog() in user_data_manager.dart with optimistic removal and rollback on failure
- Added a trash icon on each weight history row that confirms before deleting and shows a feedback pill
- Water custom amount input now only accepts digits with a 5 character limit
- Feedback pill in the weight sheet now shows "Updated!" when overwriting an existing entry, "Deleted!" on deletion, and "Logged!" for new entries

## 2026-06-19
- Removed appbars from every screen with one to remove redundancy
- Added the weight logging date picker code into the water logging one
- Made the daily reward dialog only appear when the skeletonizer finishes
- Made the daily reward dialog not dismissable by accident. It can now only be dismissed by pressing the dialog's button
- Added a title next to the back button on the food logging screen showing which meal is being logged
- Replaced the manual entry collapsible section with a button that opens a frosted dialog
- Fixed text and icon colors in food logging to adapt to light and dark themes
- Food names in search results, recent foods, and database results now truncate with ellipsis
- Food name in manual entry capped at 50 characters
- Attribution text in food logging is now readable on light themes
- Made the "view analytics" button stand out more on dark themes
- Updated the log food button UI
- Calorie calculator age and height sliders replaced with text inputs; height uses separate feet and inches fields in imperial mode
- Goal and Activity Level split into separate sections in the calorie calculator, each using the same card toggle style as Basic Info
- Get Results button now matches the ghost button style used throughout the app
- About the Developer screen social link cards now have subtle contrast against the background card
- Rewrote the About the Developer bio
- Reduced padding between section headers and cards across settings screens to match the home screen
- Color preview circle in Personal Preferences is now larger and has a visible border
- Recent Foods Limit subtitle reworded from "Current value" to "Up to X foods"
- Selected pill state in the calorie calculator is now visually distinct with a tinted border and background

## 2026-06-20
- Updated the goals table to store water and weight goals
- Added endpoints and methods to handle updating water and weight goals
- Edited user data get to load water and weight goals
- Wired up water and weight goals to the frontend loading
- Added buttons for setting water and weight goals
- Split nutrition and weight goals into separate cards: Nutrition, Weight goals (goal weight and weight goal type), Weekly workout
- All goal dialogs now use the shared frosted alert dialog for consistent styling
- Goal cards in settings always show "Current: ..." with a fallback of "Current: None"
- Nutrition goal card subtitle shows all four macros
- Weight goal dialog includes goal type selector and a unit-aware target weight field
- Water goal dialog stores in ml internally but displays in oz for imperial users
- Home screen water card now shows a progress bar and goal subtext when a water goal is set
- Weight card falls back to the most recent logged weight if none is logged today
- Weight card subtext is goal-type aware: shows how far you are from your goal, "You're at your goal weight!" if reached or passed in the right direction, or "No weight goal set" if no goal exists
- Fixed calorie calculator Get Results button not firing due to a GestureDetector wrapping a frostedButton with its own onPressed
- Replaced the Logs Today card with a Macros card showing today's protein, carbs, and fat against goals
- Calories card now has a chevron button that navigates to food logging and an analytics button that opens food analytics
- Removed the recent section from water logging
- Added "no entries today" text on days with no water logs
- Referral card bottom text changed from "X friends referred" to "X referred" with no floating number
- Guest mode logging section now shows a dimmed preview of all four cards with a lock icon and sign up prompt
- Tapping Badges or Leaderboard as a guest now shows the sign up dialog instead of opening the screen
- Made the leaderboard cards visible to guests

## 2026-06-21
- Made all modal bottom sheets open at about half the screen width
- Fixed macros card not updating by parsing macros from food_description instead of looking for top-level keys that were never stored (which would always return 0)
- Redesigned log food screen with "ADDING TO / Meal" header showing logged kcal top right
- Replaced cramped icon row with a 2x2 input method grid (Scan, Voice, Manual)
- Added skeletonizer shimmer while API search results are loading
- Replaced debounce-on-type with an explicit search button to prevent accidental API calls
- Recent foods section now shows food icon, name, serving, kcal, and a + button
- When a search query matches recent foods, a Recent/Database tab switcher appears
- Added macro chips (P/C/F) to logged food tiles in the food logging screen
- Fixed hardcoded Colors.redAccent on over-limit progress bars to use the theme color
- Fixed mic icon color hardcoded to redAccent when active, now uses theme accent
- Fixed unit picker InkWell ripple bleeding over the manual entry dialog background
- Unified food selection into a single serving dialog for both search results and recent foods, replacing the separate inline dashboard for search results
- Recent/Database tab switcher replaced with a subtle underline indicator
- Search results and recent match lists separated by divider lines with "End of results" at the bottom
- Made macros pill show macros even if the value is 0
- Made the recent foods card have a slide animation
- Removed swipe-to-delete for foods as it is overly complicated and unneeded
- Deleted debouncer for api calls as it is now obsolete
- Combined edit and recent food dialogs into one as they share most of their code
- Added a "No results" snackbar
- Removed the Log Screen UI dashboard and simply replaced it with the dialog
- Moved the weight hint text so it does not recompute every time the modal is moved

## 2026-06-22
- Created a UnitConverter class for better readability
- Fixed guest sign up dialogs spanning whole width on pc
- Fixed location permissions being asked to guests
- Split home_screen.dart into new files in the home folder to make it more readable and modular
- Constrained the size of the logging cards on desktop
- Fixed Calorie Calculator overflow errors and layout of the activity level cards not taking up the card's space fully
- Added a dialog that appears and blocks app access if the user opens the app on an outdated version (as older versions may break after backend changes)

## 2026-06-23
- Fixed a bug where logging in with email would show the success message but not take the user into the app until they refreshed
- Readded the weight analytics button which leads to a new WeightsAnalytics class
- Fixed an overflow error in the macros card skeletonizer
- Extracted the range picker into a new analytics_components file
- Moved the range hint text directly into the range picker card
- Made it so the range picker UI collapses into a "Tap to change range" button when a date is selected
- Made food analytics range default to showing the past 7 days of data
- Built weight analytics screen with a curved line chart with dot markers, dashed goal line, y-axis values, and tooltips on tap
- Weight analytics quick-select chips (1W/2W/1M/3M/All) fill the full row width and default to 1W on open
- Weight analytics shows Start, Current, and Change stat tiles below the chart
- Weight analytics all-entries section has an inline add row (weight input + date picker) and tap-to-confirm delete, constrained height with internal scroll
- Weight analytics range picker auto-collapses to show selected range on open
- food_analytics.dart and weight_analytics.dart moved into a new screens/analytics/ folder alongside analytics_components.dart
- Added GRAPH, INFO, and ALL ENTRIES section headers to weight analytics
- Added SUMMARY section header to food analytics range tab
- Moved avg/logged day out of summary stat tiles and into a subtitle line inside each chart card
- Replaced food analytics range bar charts with line charts showing per-day trends over the selected range
- Added a MEAL BREAKDOWN line chart to food analytics range tab showing per-meal calorie lines (Breakfast, Lunch, Dinner, Snacks)
- Food analytics now has three graph sections: CALORIE GRAPH, MEAL BREAKDOWN, and MACRO GRAPH
- Added CALORIE SUMMARY and MACRO SUMMARY section cards below each graph with clean text rows showing totals and per-meal breakdown
- Daily view summary card redesigned to show total calories, per-meal text rows, and macro totals in one clean card
- Added focus filter chips (All/Breakfast/Lunch/Dinner/Snacks) to meal breakdown chart and (All/Protein/Carbs/Fat) to macro chart
- Chart heights increased on desktop for better readability
- Avg/day moved out of the calorie summary header and into a dedicated row below the meal list with a divider
- Added macro data per meal type on the Log Food screen and in the Food Analytics cards
- Added per-meal macro breakdown display to Food Logging page showing protein, carbs, and fat for each meal section
- Added per-meal macro breakdown to the Food Analytics daily summary card

## 2026-06-24
- Made it so no slide up animation shows when clicking the Food Analytics shortcut from Home Screen
- Fixed tooltips in line charts clipping
- Removed the code that forces web version to refresh after 30 minutes of inactivity
- Added the Water Analytics screen and the button leading to it
- Extracted more repeated code from analytics into the analytics_components file
- Removed the extra padding around the line chart graphs as the tool tips are now contained
- Moved minimum app version code gate to the backend so it works
- Added the update gate into the connectivity stream so that if a user gets in due to no connection, once they regain connection they will be blocked
- Made the retry button on home screen undismissable
- Moved the connectivity and version check listener from home screen to MyApp in main.dart so it works regardless of which screen the user is on
- Replaced the force-update dialog approach with a dedicated /update-required route that the router redirects all traffic to when isAppOutdated is true
- UpdateRequiredScreen renders the real HomeScreen under a Skeletonizer so the background matches the normal loading state
- Fixed the retry flow in home screen so repeated retries work and data loads correctly after a successful retry
- Extracted showForceUpdateDialog into globals.dart so it is shared between the startup and reconnect paths
- Added /app_config backend route with MIN_APP_VERSION so the minimum required version can be changed server-side without a client deploy
- Built a level-up overlay that shows when the user gains a level, with a rank name, next-rank hint, animated XP progress bar, and an accomplishments grid showing best streaks, total XP, days logged, water logs, weigh-ins, and friends referred
- Fixed a bug where the level-up overlay would trigger on login by gating the baseline capture behind appReadyNotifier instead of appInitialized
- Fixed gym check-in in explore.dart not calling userDataNotifier.notifyListeners, so the level-up overlay now triggers correctly after a check-in
- Level-up overlay close animation is a smooth fade instead of a jarring scale shrink
- Added a pulse effect on the search button if a user searches a food but doesn't press search for 5 seconds
- Made the search bar animate into the compressed version rather than being instant
- Added a "created_at" field in the users table and wired it to the frontend
- Made each macro chip in the serving size dialog tappable to edit, tapping switches it to a text field that writes live into an overrides map, and the caller uses those overrides instead of the proportionally scaled values when building food_description
- Added a confirmation dialog in the Results tab
- Added no connection snackbars when a user tries to tap the referral and daily reward card
- Edited the theme of the date pickers to have the app's aesthetic
- Made "All entries" card slowly grow to max height based on number of entries
- Added delete entry buttons to the all entries cards
- Made dialog buttons consistent across the app
- Fixed snackbar overflow errors
- Made the search shimmer effect visible on light themes
- Made the search shimmer effect go away if the user searches via pressing Enter

## 2026-06-25
- Made a new schema for the updated food logs as currently all meals for a date are stored in one json blob which is hard to query
- Added dual writing for food logs to not break existing users before the update goes live
- Added food_logs_v2 in the GET user data route and wired it to frontend
- Added schemas and endpoint for upserting food logs to the new table
- Replaced foodDataByDate with a flat foodLogs list, all food screens now filter by date and meal instead of nested map lookups
- Removed extractMacros and castFoodList since macros are now stored as direct fields on each food item
- extractMacrosFromFood reads direct keys first and falls back to parsing food_description for legacy items
- Food items now store protein, carbs, fat, fiber, sugar, sodium, and serving_size as direct fields when logged
- Wired macro fields through all three food logging paths: search result, manual entry, and barcode
- Added get_food_detail route and method to get micronutrient details from fatsecret (for future micro implementation)
- Made recent foods read from the new food_logs_v2 table and deleted all the SharedPreferences-related code for recent food handling
- Wired food_logs_v2's id field to the frontend so it can be used to identify specific foods when adding logged_at to a food card
- Stripped recent foods of id and logged_at when selected so that they are recalculated for the current time when a user relogs them with a new id
- Added a logged at time on each food card (hidden for foods logged before logged_at started being stored)
- Fixed slight bugs with rapid account changing (guest color not resetting, level up overlay showing if logging into an account with a higher level)
- Fixed bugs with level up overlay to directly calculate and compare the level before and after an xp event so that it fires when needed as opposed to instantly via listeners
- Added a "most logged foods" card to food analytics

## 2026-06-27
- Rebuilt onboarding into a single unified wizard dialog with 4 steps: value pitch, weight goals, calorie setup, and activation prompt
- Animated dot indicators show current step with an active dot that stretches into a pill shape
- Back button appears on steps 2-4; pressing back from the activation step goes to goals step if goals were never set
- Skipping goals jumps directly to the activation prompt, bypassing calorie setup since there is nothing to base it on
- All data writes are deferred until an activation option is tapped so back-navigation never causes double-writes or stale reads
- Goal step uses progressive disclosure: units and weight fields animate in after a goal type is selected, target weight only appears for lose/gain
- Switching units auto-converts entered weight values; unit choice syncs into the calorie step automatically
- Calorie step collects sex, age, height, and activity level, calculates TDEE using Mifflin-St Jeor, then derives a calorie target from a chosen weekly rate of loss or gain
- Rate is chosen from quick-select preset buttons or a custom pencil input; result card only appears once a rate is selected
- Switching units on the calorie step clears the rate and hides the result card so the user picks a fresh rate for the new unit
- Activity level list collapses to a summary row after selection with a change button to re-expand, animated with AnimatedSize and AnimatedSwitcher
- Height field animates between a single cm field and ft+in fields when switching units
- All numeric fields reject letters and are capped at appropriate lengths
- Inline error replaces snackbar for missing fields since the snackbar appeared behind the dialog
- Activation prompt offers: log first food, claim daily reward, or customize the app (navigates to personal preferences)
- finishOnboarding fires from every activation option so the username is always assigned regardless of path taken
- Made snackbars optional in relevant userManager methods so nothing surfaces during onboarding
- Fixed the app color dialog not using the frosted glass effect
- Extracted repeated code from onboarding and the calorie calculator into a new tdee_calculator.dart file
- Removed all code that auto-opens the daily dialog
- Added a shimmer effect when the daily reward button can be clicked
- Updated the daily dialog UI to fix issues (many different colors, important text too small)
- Added tooltips after the onboarding is finished so the user does not feel lost / overwhelmed after onboarding is finished
- Locked the bottom nav bar when the hint text is showing
- Added the option to speak reminder messages by tapping a mic icon
- Made every dialog have consistent UI buttons
- Fixed the update profile picture dialog from taking the whole width on desktop and not having the frosted glass effect
- Dialogs now shift up when the keyboard opens on iOS PWA using a visualViewport JS bridge so the keyboard no longer covers them
- Fixed Set goals buttons in Food Logging causing overflow errors
- Added a macro profile step to onboarding: pick a goal type and macros are set automatically
- Added a username step to onboarding so new users can pick a name before entering the app
- All onboarding data writes are fully deferred until an activation option is tapped, including macros
- Onboarding dialog width capped on desktop so it no longer takes the full width
- Skip button moved inline with the back button so it is always visible regardless of content length
- Added descriptions to each macro profile option explaining who it is best suited for
- Made the ad card visible to guests for potentially fixing admob rejection issues
- Made the "refer a friend" card blurred with a lock on top of it for guests
- Replaced the chevron in the calorie logging card with a +
- The + opens a dialog that lets the user choose which meal to log to
- Clicking it opens that page directly

## 2026-06-28
- Seeded Supabase with exercise library data (muscle_groups, exercises, exercise_muscles tables)
- Added personal_records table to Supabase for tracking lifetime PRs per user per exercise
- Added index on workouts table for faster date-filtered history queries
- Wired up the weekly workout amount dialog in the workout tab
- Made the weekly workout amount editable when an actual amount is set
- Did the same for food logging to quickly edit calorie and macro goals
- Added a weekly workout goal button in personal preferences
- Designed the workout tab dashboard: weekly goal card, start workout hero card, new routine and explore routines side-by-side cards, my routines empty state, and a lifts logging card
- Added a "recent workouts" card (unwired) to the workout dashboard
- Created the active workout screen
- Created the exercise selection screen which has the same search bar style as the one in food logging
- Added filters to the exercise selection screen (by muscle group, equipment, level)
- Multiple selections from the same filter group can be chosen (eg chest and back for muscle)
- Added a routine parameter to the workout screen to know when an empty workout vs a routine has been chosen
- Added a skeletonizer to the workout tab so it waits for data to be ready
- Made the workout tab cards animate into view like the home screen does
- Added backend route for search_exercises with new workout service and workout repo classes
- Added created_by and is_public columns to workout_templates in preparation for sharing user-generated routines
- Used a Postgres RPC for exercises search so the muscle group JOIN runs server-side in one query instead of fetching all rows and filtering in Python
- Wired the search bar in the frontend to the backend route
- Removed the search button from the exercises search bar and added a debouncer
- Added /log_workout and /get_recent_workouts backend routes with WorkoutService and WorkoutRepository implementations
- /log_workout inserts into workouts, workout_exercises, and workout_sets in sequence and returns the workout_id
- /get_recent_workouts returns the user's 10 most recent completed sessions ordered by date
- Added LogWorkoutRequest, LogWorkoutResponse, GetRecentWorkoutsResponse, and RecentWorkoutItem schemas

## 2026-06-29
- Wired the Finish button to POST to /log_workout with all checked sets that have real values
- Empty or zero-value sets are stripped client-side before sending and again server-side as a guard
- Added a name prompt on Finish so users can label their session before it is saved
- Built the finish workout summary screen showing duration, volume, sets, and a per-exercise set breakdown
- Added /workout/finish route to the router
- Wired recent workouts card on the workout dashboard to /get_recent_workouts
- fetchRecentWorkouts moved into UserDataManager alongside all other backend calls
- Added workoutLogNotifier to globals so the workout tab refreshes its recent sessions list immediately after a workout is saved
- Added /get_recent_exercises backend route backed by a Postgres DISTINCT ON query that returns the user's most recently used unique exercises ordered by last session date
- Exercise picker now shows a RECENTLY USED section before the search results when the user has prior workout history
- Added the option to delete, reorder, and replace exercises
- Added /get_weekly_workout_count backend route that counts completed workouts since the most recent Monday
- Weekly goal card on the workout tab now shows the real workout count for the current week
- Added /get_today_overview backend route returning today's total volume, exercises, sets, reps, duration, and muscles worked
- Replaced the Lifts card on the workout tab with a Today overview card showing all five stats and muscle chips
- Added /get_workout_heatmap backend route returning workout counts per day for the last 16 weeks
- Built a GitHub-style activity heatmap on the workout tab showing workout frequency by day with month labels, a Less/More legend, and a frosted glass tooltip on tap/hover
- Added /create_custom_exercise, /edit_custom_exercise, and /delete_custom_exercise backend routes for managing user-created exercises
- Updated the search_exercises Postgres RPC to include the user's own custom exercises alongside built-in ones, and to return an is_custom flag
- Custom exercises show a three-dot menu in the exercise picker instead of a chevron, opening an Edit or Delete option
- Edit pre-fills the create dialog with existing values; delete shows a confirmation before removing the exercise
- Creating a custom exercise immediately selects it and closes the picker
- Added a unique constraint on (name, created_by) in the exercises table so a user cannot create two exercises with the same name
- Duplicate name attempts return a 409 with a user-facing error shown inline in the create dialog
- Built the Create Routine screen with an inline name field, exercise list with reorder and remove, and a Save button that posts to the new /create_routine backend route
- /create_routine inserts into workout_templates and workout_template_exercises and returns the generated template_id
- Wired the New Routine button on the workout dashboard to push the Create Routine screen
- Built the Browse Routines screen with a horizontally scrollable Featured section and a vertical Community section, each using the home screen card style
- Added /get_my_routines backend route returning the user's saved routines with their exercise lists, fetched in a single batch query
- My Routines card on the workout dashboard now shows real data with a Start button per routine that launches an active workout pre-filled with those exercises
- Empty My Routines state shows a dialog offering to create a routine or browse existing ones
- Added /browse_routines backend route returning featured (uid null) and community (is_public true) routines in a single call with exercise lists and creator usernames
- Added 9 built-in featured routines to workout_templates covering all fitness levels and equipment availability
- Browse Routines screen now fetches real data

## 2026-06-30
- Added copy_routine endpoint that copies a public browsed routine into the user's own routines using just the template_id
- Wired up the Save This Routine button on featured and community cards in the browse routines screen
- Incremented the workoutLogNotifier when a routine is saved so the My Routines card updates immediately
- Added a source_template_id column to workout_templates for validity checks to make sure users can't save the same custom workout multiple times
- Added methods and route for deleting routines
- Added likes table with a Postgres trigger keeping like_count in sync on workout_templates
- Wired like/unlike buttons on featured and community browse cards with optimistic UI
- Fixed active workout screen to pass routine extra through the router so starting from a saved routine pre-populates exercises
- Replaced personal_records table with user_exercise_stats keyed by (uid, exercise_name), tracking last weight/reps and PRs per exercise
- log_workout now upserts user_exercise_stats after each session, updating PRs using the Epley 1RM formula where applicable
- Refactored log_workout into _create_workout, _save_sets_and_collect_stats, and _upsert_exercise_stats
- Added exercise_stats GET route and methods for loading the stats in when a user starts an exercise
- Fixed unit conversion causing decimals when loading past workout stats
- Added get_every_prev_set Postgres RPC and every_prev_set endpoint returning all sets from the most recent session per exercise
- Active workout screen now shows per-set previous weight and reps in the PREVIOUS column, falling back to the last session summary for sets beyond the previous session's count
- Fixed imperial weight entries being stored as kg without conversion
- Added displayWeightCompact to UnitConverter for clean weight formatting without trailing decimal zeros
- Create routine now supports a set count stepper per exercise and an estimated duration field
- default_sets and estimated_duration_minutes are saved to the DB and used when starting a workout from a routine
- Made heatmap legend hoverable / clickable to show exactly how many workouts correspond to each color
- Added WorkoutSessionService: all active workout state (exercises, sets, checked, weights, reps, rest duration, workout name) is now persisted to SharedPreferences on every mutation and survives navigation away from the screen
- Active workout screen reads and writes through WorkoutSessionService instead of local state; session is cleared on finish or discard
- Added chevron down button to workout header to dismiss the screen without losing session state
- Added persistent mini bar above the nav bar while a workout is active: shows workout name, exercise count, and live elapsed timer; tapping it returns to the full workout screen
- Mini bar can be collapsed to a circular floating button on the left via a compress icon; tapping the dot expands it back
- Both the mini bar and collapsed dot pulse in scale to signal an active session; dumbbell icon also pulses in opacity
- In-progress workout session is fully restored on app kill and relaunch via checkAndRestoreWorkoutSession called during app init
- Workout session is UID-stamped on start; restore is skipped for guest users and rejected if the saved session belongs to a different account
- Added download count to browse routines; shown next to like count on featured and community cards
- Added routine_downloads table to enforce one download per user per template; copy_routine now upserts into routine_downloads and only increments download_count if the row is new
- Browse screen re-fetches after any workout change so saved/deleted routines and download counts stay in sync
- Fixed setState during build crash when starting a workout by deferring workoutSessionService.startSession notify to post-frame
- Sorted featured cards by like count AND download count AND created at to enforce determinism
- Updated the onboarding flow to mention the new workout features with an activation card at the end redirecting to the workout tab

## 2026-07-01
- Added a listener into the workout tab so that instead of showing "Start Workout" it shows specific text if a workout is already in progress
- Blocked quick starting a workout from a routine if a workout is already in progress

## 2026-07-02
- Added a listener to Food Logging to refresh the page on food logs to fix a stale data bug when logging a food manually when the screen was accessed by the quick log button in the Home tab

## 2026-07-03
- Fixed download count on Browse Routines not persisting after navigating away by removing the workoutLogNotifier listener that was triggering a refetch and wiping the optimistic state
- Fixed download_count being stripped from the Browse Routines API response due to a missing field in BrowseRoutineItem schema
- Fixed /today_overview crashing when the user had no workouts logged today due to a stale "muscles" key in the no-workouts early return
- Replaced the multi-step log_workout backend flow with a single atomic Postgres RPC that inserts the workout, exercises, and sets, updates exercise PRs and stats, awards XP scaled to level and duration, updates the workout streak, and increments achievement progress in one transaction
- Added XP reward on workout completion: base XP is 40% of the daily reward for the user's level, plus a duration bonus of up to 30% of base XP for workouts 60 minutes or longer
- Added workouts_logged and workout_streak achievements
- Workout completion now updates the XP bar immediately and shows a level-up overlay if the user leveled up
- Finish Workout screen now displays the XP earned
- Added real-time PR detection during active workouts: a PR chip appears on the exercise header when a new weight or reps record is hit on a checked set
- PR detection shows a snackbar on check describing the exact improvement (e.g. "Bench Press: Weight PR: 80kg -> 100kg")
- PR badge on the Finish Workout screen now shows the type of PR (Weight PR, Reps PR, or Weight + Reps PR) per exercise
- Fixed PR detection false-positives for exercises with no stored weight PR by falling back to previous session set data before treating a value as a first-ever record
- Fixed PR detection unit mismatch in imperial mode by converting the typed value to kg before comparing against stored pr_weight_kg
- Fixed PR chip staying visible after unchecking the set that triggered it
- Blocked checking a set with 0 weight and 0 reps
- Fixed the Previous column showing the same value for all sets when the previous session had fewer sets logged; unmatched set numbers now show - instead of falling back to the session summary
- Added skeleton shimmer to the Previous column while previous set data is loading
- Fixed /today_overview XP fields returning null when no workout had been logged that day
- XP is now awarded once per calendar day per user rather than on every workout log
- Overhauled the Finish Workout screen: centered header, larger title and XP text, animated XP bar showing current progress, confetti on XP earned, staggered section animations, Personal Records card with before/after values, Muscles Worked chips showing primary and secondary muscles, consistent section labels throughout
- PR chip and snackbar now update in real time as weight or reps are edited on a checked set, and clear if the value drops back below the record
- Previous column set 1 falls back to exercise summary stats when no per-set match exists from the previous session
- Fixed routine-started workouts not showing muscle data on the finish screen by joining muscle groups when fetching routine template exercises
- is_personal_record flag now stamped on workout_sets rows at log time, enabling future PR history queries by date range or exercise
- Updated the badge card UI to look like the other cards, making them look better on light themes
- Removed the accent bar from badge cards

## 2026-07-04
- Fixed the mini workout bar border clipping
- Removed the open chevron from the mini workout bar, instead making the whole card tappable but also making the collapse icon have a much bigger hitbox so it won't be missed
- Made current and best workout streaks load into UserData to wire up a Streaks card for Workout Streaks on the home dashboard
- Replaced the "Resets on Monday" text for weekly workout with a timer to the actual reset time
- Added a replacingExercisePrimaryMuscle variable so that when a user presses "replace" on an exercise it passes it to the search exercises route and also searches for recommended exercises that match that primary muscle
- Added a fetchRecommended method that uses the search_exercises route by filtering for that primary muscle and returning the first 5
- Reduced the activity heatmap from 16 weeks to 12 weeks so cells are a more comfortable size
- Added Firebase Analytics events for workout_started, workout_completed, workout_discarded, routine_created, routine_started, daily_reward_claimed, ad_watched, onboarding_completed, onboarding_skipped, food_logged, and streak_milestone

## 2026-07-05
- Began Riverpod migration
- Created userDataProvider (AsyncNotifierProvider) as the future single source of truth for all user state, with setUserData() for full loads and patch() for small updates
- Added copyWith() to the UserData model to support immutable field updates
- Converted all widget screens from StatefulWidget/StatelessWidget to ConsumerStatefulWidget/ConsumerWidget
- Replaced all appColorNotifier.value reads with an appColor getter on each state class that reads from userDataProvider
- Replaced currentUserData reads in async methods with ref.read(userDataProvider).value
- AppInitScreen now calls setUserData() after init so the provider is populated on startup
- The provider and the existing global currently hold the same UserData object - full decoupling requires migrating mutations to go through patch() which is the next step

## 2026-07-06
- Continued Riverpod migration
- Created a reminders provider to become the pure source of truth of all reminder data. This also required removing the reminders list from being loaded into UserData so that there are not conflicting sources of truth
- Added a skeletonizer to the Reminders screen
- Made a model class for FoodData to remove raw Map<String, dynamic> usage in the food logging screens
- Added a GET food_logs_v2 route so food logs can be fetched on their own instead of being returned as a part of the user data GET
- Converted water log sheet and weight log sheet from StatefulBuilder functions to ConsumerStatefulWidget classes so they can read from userDataProvider directly instead of the currentUserData global
- Migrated food logging screens (food_logging, log_food_screen, food_analytics, home_logging_cards) to foodLogsProvider — removed foodLogNotifier counter and currentUserData.foodLogs
- Migrated remaining screens to read from userDataProvider: settings drawer, personal preferences, home logging cards, onboarding, referrals, daily rewards, level up overlay
- Extracted referral HTTP calls into userDataProvider notifier (claimReferralReward, useReferralCode, fetchReferralCode)
- Extracted onboarding write logic into commitOnboarding on userDataProvider notifier
- Removed appColorNotifier, replaced with a top-level appColor getter backed by currentUserData
- Removed expNotifier, XP bar now reacts to userDataProvider via ref.watch with select, removing the last ValueNotifier-based rebuild trigger
- Fixed classes using .read instead of .watch for user data related changes
- Added the select keyword to all appColor getters because they were currently updating the app color no matter what changed in UserData
- Added GET /water_logs and GET /weight_logs backend routes so water and weight data can be fetched independently instead of bundled in GET /user_data
- Created waterLogsProvider and weightLogsProvider as independent AsyncNotifier providers with optimistic update and rollback for all mutations
- Removed waterEntriesByDate and weightByDate from UserData and from GET /user_data response, water and weight logs are now fully owned by their own providers
- Updated all screens reading water and weight data to use the new providers instead of userDataProvider

## 2026-07-07
- Fixed home screen getting stuck on the loading skeleton due to AppInitScreen unmounting before _initApp completed, which caused the mounted check to bail before setting appReadyNotifier to true

## 2026-07-08
- Deleted the legacy UserDataNotifier ValueNotifier and global appColor/currentUserData getters
- Moved all user data mutations (updateGoals, updateNutritionGoals, updateWeightGoal, updateWaterGoal, updateWeeklyWorkoutsGoal, updateUnits, updateAppColor, updateNotificationsEnabled, updateProfilePicture) from UserDataManager into UserDataNotifierNew with optimistic update and rollback on failure
- All UI utility functions (frostedGlassCard, frostedButton, sectionHeader, showFrostedDialog, showFrostedAlertDialog, showThemedDatePicker, socialLink, buildThemeGradient, DateNavigationRow, OnboardingHint, createTitle) now receive appColor as an explicit parameter instead of reading a global
- Created workoutProvider (WorkoutNotifier) as the single source of truth for all workout state, replacing the WorkoutSessionService ChangeNotifier and workoutLogNotifier globals
- Workout tab data (recent workouts, routines, heatmap, weekly count, today overview) now loads in parallel via Future.wait instead of sequentially, cutting worst-case load time from 40s to 8s
- Converted AppShell from ConsumerStatefulWidget to ConsumerWidget, eliminating the 1-second setState timer that was rebuilding the entire shell every second; elapsed time now updates only in an isolated _MiniBarWrapper widget via workoutProvider.select
- Made water and weight providers fetch on first watch so the home screen water and weight cards populate correctly on load with a skeletonizer
- Added userDataLoadedProvider that flips to true once loadUserData completes
-All tab screens gate their skeletonizers on this so they never render with wrong colors or stale goals etc
- Removed FutureBuilder, _loadUserDataFuture, and _loadUserDataAndInit from food logging
-Meal lists are now derived reactively in build from foodLogsProvider so food always reflects the latest state without manual reloads
- Food logging goals (calories, protein, carbs, fat) now use ref.watch with .select instead of ref.read so they update immediately when user data loads
- Migrated appReadyNotifier to its own provider class and migrated the files that depend on it
- Migrated all food logging screens (food_logging, log_food_screen, food_analytics, home_logging_cards) to use FoodLog directly
- Added an Invite a Friend button to the referrals dialog and the settings drawer that opens the native share sheet with a prefilled message and your referral code
- Fixed crash when starting a workout from a routine caused by the workout provider state not being available during widget mount
- Added analytics event tracking for key user actions: daily reward tap, watch ad tap, reminders shortcut, calorie calculator shortcut, referral card open, invite a friend, explore check-in, calorie goal set from calculator, water logged, weight logged, food logged, workout started/completed/discarded, routine started/created, daily reward claimed, streak milestone reached, onboarding completed/skipped, and reached level 3
- Added Minimize to the discard workout dialog and Discard Current Workout to the workout in progress dialog
- Food items now have a three-dot menu with Edit Serving and Move to Meal options
- Added a Suggested foods tab next to Recent, showing your most frequently logged foods for the current meal based on the past two weeks, weighted toward more recent logs

## 2026-07-09
- Added more leaderboard types (workouts logged and foods logged)
- Added leaderboard time filters (all time, monthly, weekly)
- Fixed get_leaderboard getting all users and filtering the top 100 client-side which caused huge sizes for leaderboard loads
- Added a better error screen for the leaderboard tab with a retry and back button
- Replaced the workout and food leaderboard gets with RPCs
- Leaderboard results are cached in memory per type/period for the session so switching tabs is instant
- Profile pictures are now always compressed to 256x256 JPEG at 75% quality on upload, capping size at roughly 20-30KB instead of up to 750KB
- Ran a one-time migration to recompress all 79 existing user profile pictures using the same settings, reducing total pfp storage from 10.81MB to 0.77MB (93% reduction)
- Redesigned the rank card on the Progression screen into a single unified card with XP, Foods, and Workouts standing tabs
- Added get_xp_standing, get_foods_standing, and get_workouts_standing Postgres RPCs so each standing type is computed server-side in one query without fetching any rows to Python
- Added server-side size limit on profile picture uploads (200KB base64) to prevent abuse
- Fixed saving a browse routine not appearing in My Routines until app restart due to an incomplete optimistic update
- Fixed workout streak and heatmap not updating on the home and workout screens after finishing a workout
- Fixed workout streak showing a stale value on the home screen when days have been missed — now correctly shows 0 until the next workout is logged
- Fixed workout streak and heatmap not updating in real time after finishing a workout
- Fixed heatmap never updating after a workout due to a wrong response key in the refresh call
- Fixed water and weight log optimistic updates not rolling back when the backend returns a non-200 response
- Fixed food streak backend call firing repeatedly on every food log provider update instead of only after a successful log
- Fixed double-saving a browse routine being possible immediately after saving due to source_template_id not being set on the optimistic update
- Fixed My Routines card not updating after creating a new routine until app restart
- Fixed username update timing out on new accounts due to Firebase token fetch being too slow on first sign-in
- Replaced the tabbed badges layout with a vertically scrollable list of horizontal card rows grouped by section
- Each section header now uses the shared sectionHeader widget for visual consistency with other tabs
- Claimable tier count shown next to each section header so users can see at a glance what is ready to claim
- Dot indicators added below each section row, matching the browse routines pattern
- Tier chips shrunk from 72px to 40px so more fit in the carousel without scrolling
- Added 4 new workout achievements: Double Down (2 workouts in one day), Full Body (hit N distinct primary muscles in one session), Early Bird (workout before 8 AM), Night Owl (workout after 10 PM)
- Double Down and Full Body are server-tracked and awarded automatically on log_workout; Early Bird and Night Owl are client-triggered trivial achievements
- Added get_today_workout_count and get_workout_primary_muscles repository methods to support the new server-side checks
- Fixed food logs from the previous account showing on a newly signed-in account by invalidating foodLogsProvider on sign out
- Fixed weight card in home logging showing a bare unit label when no goal weight is set
- Added is_premium and premium_expires_at columns to the users table in Supabase and schema.sql
- Added /verify_purchase endpoint that validates a Play subscription token against the Google Play Developer API and sets is_premium and premium_expires_at on the user
- Added /premium_status endpoint that returns current premium state and auto-revokes if the subscription has lapsed
- Added full premium paywall sheet with animated shimmer header, pulsing logo, floating particles, and a frosted glass design that reflows to the user's chosen theme color
- Leaderboard preview inside the sheet shows the user's actual username at rank 1 with a live shimmer name and Pro badge to demonstrate the effect before subscribing
- Theme color preview lets users tap any preset swatch or open a full color picker to try any color across the entire app live before subscribing
- Closing the sheet after previewing a color starts a 30-second countdown bubble above the nav bar showing the remaining time before the color resets, with a tap-to-return action
- Added a Free vs Pro comparison as a tiered table showing the actual limit difference per feature (14-day vs full analytics, 5 vs unlimited meal templates, 20 vs unlimited recent foods, no shields vs unlimited) plus side-by-side cards for included-free features and Pro-only extras
- Plan selector shows yearly and monthly base plans with localized prices from the Play Store, defaulting to yearly selected

## 2026-07-10
- Remade the Free vs Pro comparison section into two distinct cards: an upgrade card showing each feature in the free vs pro version side by side, and a Pro exclusive card
- Comparison card fills switched to a fixed dark overlay so content stays readable on light and saturated themes
- Color picker in the theme preview now applies the same too-light guard as the settings screen
- Updated icons to HugeIcons package
- Added premium_perks table to store monthly-resetting consumable allowances per premium user (shield_count, shields_reset_at, streak_before_break)
- Updated claim_daily_reward RPC to save streak_before_break to premium_perks when a premium user's daily streak breaks, and return streak_broke to the client
- Added apply_streak_shield RPC that atomically spends one shield and restores the daily streak to streak_before_break in a single transaction
- Added GET /premium_perks endpoint returning current shield count and reset date with lazy monthly reset
- Added POST /use_streak_shield endpoint that verifies premium status, checks shield availability, and calls apply_streak_shield
- Shield count and reset date loaded on app start for premium users and stored in UserData
- Daily reward flow now checks locally if the streak broke before claiming: premium users with shields see a restore dialog, free users see an upsell dialog
- Shield restore dialog pops true/false so the normal claim is skipped if a shield was used
- Upsell dialog returns true (proceed to claim) or false (Learn More tapped, bail out); Dismiss and Don't show again both proceed to claim
- apply_streak_shield RPC now also sets last_daily_claim to prevent re-claiming after using a shield
- Shield indicator added to daily reward card on home screen: shows count for premium users, tappable info tooltip for free users
- "Don't show again" preference stored in SharedPreferences so the upsell dialog respects prior dismissals
- Added PRO banner to water and weight analytics screens matching the existing food analytics banner
- Analytics range chips (1M, 3M, All) are gated client-side for free users: locked chips display a sweeping ShaderMask shimmer and tapping opens a pro feature dialog
- Added showProFeatureDialog helper in globals.dart: frosted dialog with PRO badge, feature name, Dismiss and Learn More buttons, used consistently across all premium gates
- Theme color picker is now gated by premium: free users see a preset grid of 13 named colors plus a locked Custom swatch, premium users get the full color picker
- Preset color grid includes dark options (Navy, Forest, Midnight, Crimson) and colors matching real user data (Slate, Violet)
- Recent foods limit dialog replaced with two options: 20 foods (free) and Unlimited (Pro)
- Added a PRO badge with a shimmer effect to premium users in the leaderboard
- Replaced the set your nutrition goals card with the real calorie card and macro gauges with a lock on top of it for guests
- Added analytics collection for the premium sheet
- Fixed foods and workouts leaderboard standing showing a rank higher than the total user count: total now counts all users instead of only those who have logged, and rank is capped at total

## 2026-07-11
- Fixed the yearly plan not being pre-selected correctly when the Pro sheet opens which incorrectly showed "29.99 per month"
- Shields now update to 3 on the UI immediately after a successful purchase without requiring a restart
- Pro sheet now shows an error message and retry button when pricing fails to load instead of falling back to hardcoded placeholder prices
- Fetched 101 users from the database for the leaderboard so filtering the tester account always results in 100 displayed
- Added Google Play RTDN webhook at /play_webhook that will verify the Pub/Sub JWT, looks up the user by purchase token, calls the Android Publisher API, and updates premium status and expiry in real time when a subscription renews, cancels, or expires
- purchase_token is now stored on the user record when a subscription is verified so the webhook can resolve the uid from incoming notifications
- More analytics added
- Updated the privacy policy, ToS, and README
- Fixed the theme preview countdown bubble not reappearing after reopening and closing the Pro sheet without picking a new color

## 2026-07-12
- Replaced feature chip labels on the login screen with more descriptive text and added subtitles explaining each feature
- Chip icons now pulse subtly
- XP preview bar on the login screen now animates, filling up to the next level
- Fixed a bug where new users who selected "Explore the home dashboard" or "Customize the app" at the end of onboarding had their calorie goal, macro goals, and weight data discarded