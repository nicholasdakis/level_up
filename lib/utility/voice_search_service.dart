import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceSearchService {
  final SpeechToText _speech = SpeechToText();

  // current state
  bool isListening = false;
  bool isAvailable = false;

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
      // resets the state on an error
      isListening = false;
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
    if (!isAvailable) return;

    // stop if already listening
    if (_speech.isListening) {
      await _speech.stop();
      isListening = false;
      return;
    }

    // ignore taps while the engine is mid-start
    if (!_speech.isNotListening) return;

    // start listening
    await _speech.listen(
      onResult: (result) {
        // remove punctuation from the recognized words
        final text = result.recognizedWords.replaceAll(
          RegExp(r'[\s.,!?;:]+$'),
          '',
        );

        // ignore empty results
        if (text.isEmpty) return;

        onText(text);
      },
      listenOptions: SpeechListenOptions(partialResults: true),
      // auto stop after 2s of silence
      pauseFor: const Duration(seconds: 2),
      // hard cap on total listen duration
      listenFor: const Duration(seconds: 15),
    );
  }
}
