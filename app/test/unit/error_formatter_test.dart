import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart' hide ErrorFormatter;
import 'package:vitap_nexus_app/utils/error_formatter.dart';

void main() {
  group('ErrorFormatter Unit Tests', () {
    test('Formats null or empty error to fallback message', () {
      expect(ErrorFormatter.format(null), 'An unexpected error occurred. Please try again.');
      expect(ErrorFormatter.format('', fallback: 'Custom fallback'), 'Custom fallback');
    });

    test('Translates HandshakeException into user-friendly message', () {
      const handshake = 'HandshakeException: Connection terminated during handshake';
      final formatted = ErrorFormatter.format(handshake);
      expect(formatted, contains('No internet connection or server is unreachable'));
    });

    test('Translates SocketException into network reachability message', () {
      const socket = 'SocketException: Failed host lookup: vitap-nexus-api.onrender.com';
      final formatted = ErrorFormatter.format(socket);
      expect(formatted, contains('No internet connection or server is unreachable'));
    });

    test('Translates timeout into response delay message', () {
      final dioTimeout = DioException(
        requestOptions: RequestOptions(path: '/student/attendance'),
        type: DioExceptionType.connectionTimeout,
        message: 'The connection timed out',
      );
      final formatted = ErrorFormatter.format(dioTimeout);
      expect(formatted.toLowerCase(), contains('timed out'));
    });

    test('Translates 401 session expiry and awaiting OTP', () {
      final dio401 = DioException(
        requestOptions: RequestOptions(path: '/student/marks'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/student/marks'),
          statusCode: 401,
          data: {'detail': 'VTOP session expired or awaiting OTP'},
        ),
      );
      final formatted = ErrorFormatter.format(dio401);
      expect(formatted, contains('session requires OTP verification'));
    });

    test('Translates 502 / 503 / 504 server overload errors', () {
      final dio503 = DioException(
        requestOptions: RequestOptions(path: '/student/all_data'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/student/all_data'),
          statusCode: 503,
          data: {'detail': 'Service Unavailable'},
        ),
      );
      final formatted = ErrorFormatter.format(dio503);
      expect(formatted, contains('Service Unavailable'));
    });

    test('Strips raw HTML tags and developer URLs from error message', () {
      const htmlError = '<html><body><h1>502 Bad Gateway</h1><a href="https://developer.mozilla.org/502">Help</a></body></html>';
      final formatted = ErrorFormatter.format(htmlError);
      expect(formatted.contains('<html>'), isFalse);
      expect(formatted.contains('developer.mozilla.org'), isFalse);
      expect(formatted.isNotEmpty, isTrue);
    });
  });
}
