import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitap_nexus_app/services/storage_service.dart';

/// The password must live only in the Keystore, never in plain SharedPreferences.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final keystore = <String, String>{};

  setUp(() async {
    keystore.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = (call.arguments as Map?) ?? {};
        final key = args['key'] as String?;
        switch (call.method) {
          case 'write':
            keystore[key!] = args['value'] as String;
            return null;
          case 'read':
            return keystore[key];
          case 'delete':
            keystore.remove(key);
            return null;
          case 'deleteAll':
            keystore.clear();
            return null;
          case 'containsKey':
            return keystore.containsKey(key);
          case 'readAll':
            return Map<String, String>.from(keystore);
        }
        return null;
      },
    );
    await StorageService.clearAll();
  });

  test('saving credentials keeps the password out of SharedPreferences', () async {
    await StorageService.saveCredentials(username: '24ABC1234', password: 'secret-pass');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().any((k) => prefs.get(k) == 'secret-pass'), isFalse);
    expect(keystore['vtop_password'], 'secret-pass');
    final creds = await StorageService.getCredentials();
    expect(creds['password'], 'secret-pass');
  });

  test('an old plain copy is moved into the Keystore and deleted', () async {
    SharedPreferences.setMockInitialValues({'vtop_username': '24ABC1234', 'vtop_password': 'old-plain'});
    await StorageService.initCache();
    // Fresh process: nothing cached yet.
    final creds = await StorageService.getCredentials();
    expect(creds['password'], 'old-plain');
    expect(keystore['vtop_password'], 'old-plain');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('vtop_password'), isNull);
  });
}
