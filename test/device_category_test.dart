import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_suite_shared/network_suite_shared.dart';

void main() {
  group('DeviceCategory Enum', () {
    test('contains all expected categories with valid properties', () {
      for (final cat in DeviceCategory.values) {
        expect(cat.label, isNotEmpty);
        expect(cat.key, isNotEmpty);
        expect(cat.icon, isA<IconData>());
      }
    });

    test('fromKey resolves matching keys case-insensitively', () {
      expect(DeviceCategory.fromKey('pc'), DeviceCategory.pc);
      expect(DeviceCategory.fromKey('PC'), DeviceCategory.pc);
      expect(DeviceCategory.fromKey('  router  '), DeviceCategory.router);
      expect(DeviceCategory.fromKey('switch'), DeviceCategory.switchDevice);
      expect(DeviceCategory.fromKey('ap'), DeviceCategory.accessPoint);
      expect(DeviceCategory.fromKey('mobile'), DeviceCategory.mobile);
      expect(DeviceCategory.fromKey('nas'), DeviceCategory.nas);
      expect(DeviceCategory.fromKey('camera'), DeviceCategory.camera);
      expect(DeviceCategory.fromKey('iot'), DeviceCategory.iot);
    });

    test('fromKey falls back to other for null or unknown keys', () {
      expect(DeviceCategory.fromKey(null), DeviceCategory.other);
      expect(DeviceCategory.fromKey(''), DeviceCategory.other);
      expect(DeviceCategory.fromKey('unknown_category_xyz'), DeviceCategory.other);
    });
  });
}
