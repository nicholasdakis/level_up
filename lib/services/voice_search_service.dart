import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceSearchService {
  final SpeechToText _speech = SpeechToText();

  // current state
  bool isListening = false;
  bool isAvailable = false;
  bool _isStarting =
      false; // prevents double-start on web where isNotListening is unreliable mid-transition

  // initialize speech engine (called once in initState when voice search is needed)
  Future<void> init(VoidCallback onUpdate) async {
    void handleStatus(String status) {
      // engine started listening
      if (status == 'listening') {
        isListening = true;
      }

      // engine stopped listening
      if (status == 'done' || status == 'notListening') {
        isListening = false;
      }

      onUpdate();
    }

    void handleError(_) {
      // resets all state on an error so the next tap can start fresh
      isListening = false;
      _isStarting = false;
      onUpdate();
    }

    // SpeechToText is a singleton; initialize() returns early if already set up
    // on a prior screen mount, which leaves the old listeners attached. Re-bind
    // them so this instance's onUpdate actually fires.
    if (_speech.isAvailable) {
      _speech.statusListener = handleStatus;
      _speech.errorListener = handleError;
      isAvailable = true;
      onUpdate();
      return;
    }

    isAvailable = await _speech.initialize(
      onStatus: handleStatus,
      onError: handleError,
    );

    onUpdate();
  }

  // drop any pending listen session so callbacks don't fire after dispose
  Future<void> cancel() async {
    if (!isAvailable) return;
    await _speech.cancel();
    isListening = false;
  }

  // start or stop listening
  Future<void> toggle(ValueChanged<String> onText) async {
    // on web, permission may be granted after init was first called; re-init if needed
    if (!isAvailable) {
      isAvailable = await _speech.initialize();
      if (!isAvailable) return;
    }

    // stop if already listening
    if (_speech.isListening) {
      await _speech.stop();
      isListening = false;
      return;
    }

    // ignore taps while a start is already in flight or the engine isn't ready
    if (_isStarting || _speech.isListening || !_speech.isNotListening) return;
    _isStarting = true;

    try {
      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords.replaceAll(
            RegExp(r'[\s.,!?;:]+$'),
            '',
          );
          if (text.isEmpty) return;
          onText(text);
        },
        listenOptions: SpeechListenOptions(partialResults: true),
        pauseFor: const Duration(seconds: 8),
        listenFor: const Duration(seconds: 15),
      );
    } finally {
      // always clear the flag so future taps aren't blocked
      _isStarting = false;
    }
  }
}
