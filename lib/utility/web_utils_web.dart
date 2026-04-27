import 'dart:js_interop';

// Binds to the setAppColor() JS function defined in index.html
@JS('setAppColor')
external void _setAppColor(JSString hex);

// Updates the body background color so the notch matches the app color
void setAppColor(String hex) => _setAppColor(hex.toJS);
