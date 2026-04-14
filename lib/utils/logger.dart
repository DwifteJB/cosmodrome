
// ignore_for_file: avoid_print

bool printInProduction = true;

void loggerError(dynamic message) {
  // get entire stack trace
  final stackTrace = StackTrace.current;
  // print in red
  print('\x1B[31m$message\x1B[0m');
  print('\x1B[31m$stackTrace\x1B[0m');
}

void loggerPrint(dynamic message) {

  // get stack trace
  final stackTrace = StackTrace.current;

  // first line will have loggerPrint & secondLine will have where it was called (e.g onWindowEvent in DesktopTitlebar.dart)
  // get second line
  final secondLine = stackTrace.toString().split('\n')[1];

  // want formatted as:
  // [DesktopTitlebar.dart:145] Window event: $eventName

  final regex = RegExp(r'#\d+\s+.*\s+\((.*):(\d+):\d+\)');
  final match = regex.firstMatch(secondLine);
  if (match != null) {
    final fileName = match.group(1)?.split('/').last ?? 'unknown';
    final lineNumber = match.group(2) ?? 'unknown';
    print('[$fileName:$lineNumber] $message');
  } else {
    print(message);
  }
}