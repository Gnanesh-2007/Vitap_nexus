import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';

/// Centralized utility to convert any raw error, exception, network failure,
/// or backend detail into a clean, human-friendly English sentence.
class ErrorFormatter {
  /// Converts any exception or error object into a user-facing plain English sentence.
  static String format(dynamic error, {String fallback = 'An unexpected error occurred. Please try again.'}) {
    if (error == null) return fallback;

    if (error is DioException) {
      return _formatDioException(error, fallback);
    }

    if (error is SocketException) {
      return 'Unable to reach the server. Please check your internet connection and try again.';
    }

    if (error is TimeoutException) {
      return 'The request timed out. Please check your connection and try again.';
    }

    if (error is FileSystemException) {
      return 'Unable to save the file. Please check storage permissions or try sharing it instead.';
    }

    if (error is FormatException) {
      return 'Received an unexpected response format. Please refresh and try again.';
    }

    final raw = error.toString().trim();
    return cleanRawMessage(raw, fallback: fallback);
  }

  /// Formats Dio-specific errors
  static String _formatDioException(DioException dioErr, String fallback) {
    switch (dioErr.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. VTOP servers may be slow or busy. Please try again.';

      case DioExceptionType.connectionError:
        return 'Could not connect to VTOP server. Please ensure you are connected to the internet.';

      case DioExceptionType.badResponse:
        final statusCode = dioErr.response?.statusCode;
        final responseData = dioErr.response?.data;

        // Try extracting detail from response JSON
        if (responseData is Map) {
          final detail = responseData['detail'] ?? responseData['message'] ?? responseData['error'];
          if (detail != null && detail.toString().isNotEmpty) {
            return cleanRawMessage(detail.toString(), fallback: fallback);
          }
        } else if (responseData is String && responseData.isNotEmpty && !responseData.contains('<html')) {
          return cleanRawMessage(responseData, fallback: fallback);
        }

        if (statusCode == 401 || statusCode == 403) {
          return 'Session expired or invalid credentials. Please log in again.';
        } else if (statusCode == 404) {
          return 'The requested resource was not found on VTOP.';
        } else if (statusCode != null && statusCode >= 500) {
          return 'VTOP server encountered an internal error. Please try again later.';
        }
        return 'Unable to complete the request (Server error ${statusCode ?? ""}).';

      case DioExceptionType.cancel:
        return 'The operation was cancelled.';

      case DioExceptionType.unknown:
      default:
        if (dioErr.error != null) {
          return format(dioErr.error, fallback: fallback);
        }
        return cleanRawMessage(dioErr.message ?? fallback, fallback: fallback);
    }
  }

  /// Converts technical / raw strings into friendly English phrases
  static String cleanRawMessage(String msg, {String fallback = 'An unexpected error occurred. Please try again.'}) {
    var s = msg.trim();

    // Strip "Exception: ", "Error: ", "PathAccessException: ", etc.
    s = s.replaceFirst(RegExp(r'^(Exception|Error|PathAccessException|FileSystemException|HttpException|DioException):\s*', caseSensitive: false), '');

    final lower = s.toLowerCase();

    // Storage / File Permissions
    if (lower.contains('permission denied') ||
        lower.contains('errno = 13') ||
        lower.contains('pathaccess') ||
        lower.contains('cannot open file')) {
      return 'Unable to save to device storage. Please check your storage permissions or share the file.';
    }

    // Network & Connection
    if (lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable') ||
        lower.contains('handshakeexception') ||
        lower.contains('connection reset') ||
        lower.contains('connection closed')) {
      return 'No internet connection or server is unreachable. Please check your network.';
    }

    // Timeout
    if (lower.contains('timed out') || lower.contains('timeoutexception') || lower.contains('timeout')) {
      return 'Server took too long to respond. Please try again in a few moments.';
    }

    // Login & Credentials
    if (lower.contains('invalid user id') ||
        lower.contains('invalid password') ||
        lower.contains('invalid credentials') ||
        lower.contains('wrong credentials') ||
        lower.contains('user id or password wrong') ||
        lower.contains('authentication failed')) {
      return 'Incorrect username or password. Please verify your credentials and try again.';
    }

    // OTP verification
    if (lower.contains('invalid otp') || lower.contains('wrong otp') || lower.contains('incorrect otp')) {
      return 'The OTP entered is incorrect. Please check and re-enter the code.';
    }
    if (lower.contains('otp expired') || lower.contains('expired otp')) {
      return 'The OTP has expired. Please request a new code.';
    }
    if (lower.contains('otp resend') && lower.contains('fail')) {
      return 'Could not resend OTP. Please wait a moment before trying again.';
    }

    // Session
    if (lower.contains('session timed out') ||
        lower.contains('session expired') ||
        lower.contains('session is invalid') ||
        lower.contains('re-login') ||
        lower.contains('login again') ||
        lower.contains('please login')) {
      return 'Your VTOP session has expired. Please log in again to continue.';
    }

    // Captcha
    if (lower.contains('captcha') || lower.contains('invalid security code')) {
      return 'Security verification failed. Please try again.';
    }

    // Outing
    if (lower.contains('outing') && (lower.contains('already applied') || lower.contains('exists'))) {
      return 'An outing request for this date already exists.';
    }
    if (lower.contains('parent phone') || lower.contains('parent contact')) {
      return 'Please provide a valid 10-digit parent contact number.';
    }

    // If string is raw HTML or too long/technical stack trace
    if (s.contains('<html') || s.contains('<!DOCTYPE') || s.contains('Traceback') || s.contains('at Object.') || s.length > 200) {
      return fallback;
    }

    // Ensure it starts capitalized and ends with period
    if (s.isNotEmpty) {
      s = s[0].toUpperCase() + s.substring(1);
      if (!s.endsWith('.') && !s.endsWith('!') && !s.endsWith('?')) {
        s += '.';
      }
      return s;
    }

    return fallback;
  }
}
