import 'package:flutter_test/flutter_test.dart';
import 'package:vitap_nexus_app/utils/vtop_helpers.dart';

void main() {
  group('VtopHelpers.extractCallingName Tests', () {
    test('Extracts middle/given calling name from 3-word name', () {
      expect(
        VtopHelpers.extractCallingName('VENKATA RAHUL SHARMA'),
        equals('Rahul'),
      );
      expect(
        VtopHelpers.extractCallingName('BATHINA CHANDRA SEKHAR'),
        equals('Chandra'),
      );
    });

    test('Extracts given name from 2-word name with surname first', () {
      expect(
        VtopHelpers.extractCallingName('VENKATA RAHUL'),
        equals('Rahul'),
      );
      expect(
        VtopHelpers.extractCallingName('SHARMA SURYA'),
        equals('Surya'),
      );
    });

    test('Handles names with initials and titles', () {
      expect(
        VtopHelpers.extractCallingName('K. SAI CHARAN'),
        equals('Sai'),
      );
      expect(
        VtopHelpers.extractCallingName('DR. RAHUL SHARMA'),
        equals('Sharma'),
      );
    });

    test('Handles single name token properly in Title Case', () {
      expect(
        VtopHelpers.extractCallingName('RAHUL'),
        equals('Rahul'),
      );
      expect(
        VtopHelpers.extractCallingName('rahul'),
        equals('Rahul'),
      );
    });

    test('Falls back to registration number / username when name is missing', () {
      expect(
        VtopHelpers.extractCallingName(null, '22BCE10001'),
        equals('22BCE10001'),
      );
      expect(
        VtopHelpers.extractCallingName('', '22BCE10001'),
        equals('22BCE10001'),
      );
      expect(
        VtopHelpers.extractCallingName(null, null),
        equals('Student'),
      );
    });
  });
}
