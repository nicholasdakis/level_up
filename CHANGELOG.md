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