import 'dart:js_interop';

// Sets window.onViewportHeightChanged so the visualViewport resize listener
// in index.html can call into Flutter as soon as the iOS PWA keyboard opens.
@JS('onViewportHeightChanged')
external set _onViewportHeightChanged(JSFunction? fn);

void listenToViewportHeight(void Function(double) onHeight) {
  _onViewportHeightChanged = (JSNumber height) {
    onHeight(height.toDartDouble);
  }.toJS;
}
