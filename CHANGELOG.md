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

# 2026-04-02
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