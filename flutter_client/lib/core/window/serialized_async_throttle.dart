import 'dart:async';

/// Coalesces frequent requests while guaranteeing that only one action runs.
class SerializedAsyncThrottle {
  SerializedAsyncThrottle(this.interval);

  final Duration interval;
  Timer? _timer;
  Future<void> Function()? _latestAction;
  DateTime? _lastStartedAt;
  bool _pending = false;
  bool _running = false;
  bool _disposed = false;

  void schedule(
    Future<void> Function() action, {
    bool immediate = false,
  }) {
    if (_disposed) return;
    _latestAction = action;
    _pending = true;
    if (immediate && !_running) {
      _lastStartedAt = null;
      _timer?.cancel();
      _timer = null;
    }
    _pump();
  }

  void dispose() {
    _disposed = true;
    _pending = false;
    _latestAction = null;
    _timer?.cancel();
    _timer = null;
  }

  void _pump() {
    if (_disposed || _running || !_pending) return;
    final lastStartedAt = _lastStartedAt;
    if (lastStartedAt != null) {
      final remaining = interval - DateTime.now().difference(lastStartedAt);
      if (remaining > Duration.zero) {
        _timer ??= Timer(remaining, () {
          _timer = null;
          _pump();
        });
        return;
      }
    }

    final action = _latestAction;
    if (action == null) return;
    _pending = false;
    _running = true;
    _lastStartedAt = DateTime.now();
    unawaited(
      Future<void>.sync(action).whenComplete(() {
        _running = false;
        _pump();
      }),
    );
  }
}
