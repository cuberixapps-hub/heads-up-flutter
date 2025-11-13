import 'dart:async';

/// A simple debounce utility for delaying function execution
class Debouncer {
  final int milliseconds;
  Timer? _timer;
  
  Debouncer({required this.milliseconds});
  
  /// Run the action after the specified delay.
  /// If called again before the delay, cancels the previous timer.
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
  
  /// Cancel any pending action
  void cancel() {
    _timer?.cancel();
  }
  
  /// Dispose of the timer
  void dispose() {
    _timer?.cancel();
  }
}
