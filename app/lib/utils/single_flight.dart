import 'dart:async';

/// Runs at most one operation at a time for a given key, handing every caller
/// that arrives while it is running the same future instead of starting a second one.
///
/// This exists for VTOP login. VTOP sends a fresh OTP email for every credentials
/// POST it sees from an unverified IP, and each POST opens its own server session
/// with its own pending code — so two concurrent logins produce two emails, of which
/// only one can validate. SingleFlight ensures only one login runs at a time.
class SingleFlight<K, T> {
  Future<T>? _pending;
  K? _pendingKey;

  /// The in-flight operation for [key], or null if nothing is running for it.
  Future<T>? pendingFor(K key) =>
      _pending != null && _pendingKey == key ? _pending : null;

  /// Whether any operation is in flight, for any key.
  bool get isRunning => _pending != null;

  /// Start [operation] as the single in-flight operation for [key].
  Future<T> run(K key, Future<T> Function() operation) {
    final existing = pendingFor(key);
    if (existing != null) {
      return existing;
    }

    final Future<T> rawFuture = operation();
    late final Future<T> guarded;
    guarded = rawFuture.whenComplete(() {
      if (identical(_pending, guarded)) {
        _pending = null;
        _pendingKey = null;
      }
    });

    _pending = guarded;
    _pendingKey = key;

    return guarded;
  }

  /// Forget the in-flight operation without cancelling it.
  void clear() {
    _pending = null;
    _pendingKey = null;
  }
}
