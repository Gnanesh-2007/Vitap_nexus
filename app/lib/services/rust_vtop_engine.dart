import 'package:flutter/foundation.dart';
import 'package:vit_vtop/vit_vtop.dart';
import 'package:vit_vtop/src/rust/api/vtop/parser/parseattn.dart' as rust_attn;
import 'package:vit_vtop/src/rust/api/vtop/parser/parsett.dart' as rust_tt;
import 'package:vit_vtop/src/rust/api/vtop/parser/parsemarks.dart' as rust_marks;
import 'package:vit_vtop/src/rust/api/vtop/parser/parseprofile.dart' as rust_profile;
import 'package:vit_vtop/src/rust/api/vtop/parser/parsebiometric.dart' as rust_bio;
import 'package:vit_vtop/src/rust/api/vtop/parser/parsegradehistory.dart' as rust_grades;

/// Centralized Rust-powered VTOP parser and data engine.
/// Utilizes the native Rust 'lib_vtop' library via flutter_rust_bridge
/// for blazing-fast local HTML parsing and state synchronization.
class RustVtopEngine {
  static bool _isInitialized = false;

  /// Initializes the lib_vtop native Rust bridge runtime.
  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      await RustLib.init();
      _isInitialized = true;
      debugPrint('RustVtopEngine: lib_vtop (Rust) initialized successfully');
    } catch (e) {
      debugPrint('RustVtopEngine: RustLib initialization note: $e');
    }
  }

  static bool get isReady => _isInitialized;

  /// Fast local parsing of Attendance HTML using Rust lib_vtop
  static Future<dynamic> parseAttendance(String html) async {
    if (!_isInitialized) return null;
    try {
      return await rust_attn.parseAttendance(html: html);
    } catch (e) {
      debugPrint('RustVtopEngine: parseAttendance error: $e');
      return null;
    }
  }

  /// Fast local parsing of Timetable HTML using Rust lib_vtop
  static Future<dynamic> parseTimetable(String html) async {
    if (!_isInitialized) return null;
    try {
      return await rust_tt.parseTimetable(html: html);
    } catch (e) {
      debugPrint('RustVtopEngine: parseTimetable error: $e');
      return null;
    }
  }

  /// Fast local parsing of Marks HTML using Rust lib_vtop
  static Future<dynamic> parseMarks(String html) async {
    if (!_isInitialized) return null;
    try {
      return await rust_marks.parseMarks(html: html);
    } catch (e) {
      debugPrint('RustVtopEngine: parseMarks error: $e');
      return null;
    }
  }

  /// Fast local parsing of Profile HTML using Rust lib_vtop
  static Future<dynamic> parseProfile(String html) async {
    if (!_isInitialized) return null;
    try {
      return await rust_profile.parseStudentProfile(html: html);
    } catch (e) {
      debugPrint('RustVtopEngine: parseProfile error: $e');
      return null;
    }
  }

  /// Fast local parsing of Biometric HTML using Rust lib_vtop
  static Future<dynamic> parseBiometric(String html) async {
    if (!_isInitialized) return null;
    try {
      return await rust_bio.parseBiometricData(html: html);
    } catch (e) {
      debugPrint('RustVtopEngine: parseBiometric error: $e');
      return null;
    }
  }

  /// Fast local parsing of Grade History HTML using Rust lib_vtop
  static Future<dynamic> parseGradeHistory(String html) async {
    if (!_isInitialized) return null;
    try {
      return await rust_grades.parseGradeHistory(html: html);
    } catch (e) {
      debugPrint('RustVtopEngine: parseGradeHistory error: $e');
      return null;
    }
  }
}
