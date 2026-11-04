import 'dart:io';

void main() {
  final source = File(
          'android/src/main/kotlin/com/csdcorp/speech_to_text/SpeechToTextPlugin.kt')
      .readAsStringSync();
  final stop = source
      .split('private fun stopListening(result: Result) {')[1]
      .split('private fun sessionListener')[0];
  if (!stop.contains('sessionGate.requestStop')) {
    throw StateError('stop does not await the native recognition session');
  }
  final listener = source
      .split('private fun sessionListener')[1]
      .split('private fun cancelListening')[0];
  if (RegExp(r'sessionGate\.finishAfterForward\(generation\)')
          .allMatches(listener)
          .length !=
      2) {
    throw StateError('results and error must both finish the native session');
  }
  final cancel = source
      .split('private fun cancelListening(result: Result) {')[1]
      .split('private fun locales')[0];
  if (!cancel.contains('sessionGate.suppressResults') ||
      !cancel.contains('stopListening(result)') ||
      cancel.contains('postDelayed')) {
    throw StateError(
        'cancel must wait for a terminal event without a delayed destroy');
  }
  final error = source
      .split('private fun sendError(errorMsg: String) {')[1]
      .split('override fun onRmsChanged')[0];
  if (error.contains('handler.post')) {
    throw StateError(
        'error must be forwarded before acknowledging its session');
  }
}
