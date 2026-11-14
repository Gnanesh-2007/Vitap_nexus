import 'package:flutter/foundation.dart';
import '../src/rust/frb_generated.dart';

/// Centralized Rust-powered VTOP native engine (lib_vtop v2.0.0).
/// Utilizes the native Rust 'lib_vtop' library via flutter_rust_bridge
/// for direct, zero-latency on-device VTOP communication & HTML parsing.
class RustVtopEngine {
  static bool _isInitialized = false;
  static Future<void>? _initFuture;

  /// Initializes the lib_vtop native Rust bridge runtime (idempotent & single-flight).
  static Future<void> init() async {
    if (_isInitialized) return;
    if (_initFuture != null) return _initFuture;
    _initFuture = _doInit();
    return _initFuture;
  }

  static Future<void> _doInit() async {
    try {
      await RustLib.init();
      _isInitialized = true;
      debugPrint('RustVtopEngine: lib_vtop v2.0.0 (Rust) initialized successfully');
    } catch (e) {
      debugPrint('RustVtopEngine: RustLib initialization note: $e');
    } finally {
      _initFuture = null;
    }
  }

  static bool get isReady => _isInitialized;
}
