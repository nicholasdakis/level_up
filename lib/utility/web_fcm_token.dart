export 'web_fcm_token_stub.dart' // stub implementation for non-web platforms
    if (dart.library.html) 'web_fcm_token_web.dart'; // actual implementation using JS interop for web platforms
