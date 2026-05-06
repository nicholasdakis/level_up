import 'dart:js_interop';

@JS('isPwa')
external bool isPwa();

@JS('supportsNativePrompt')
external bool supportsNativePrompt();

@JS('hasInstallPrompt')
external bool hasInstallPrompt();
