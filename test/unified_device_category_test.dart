import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_suite_shared/network_suite_shared.dart';

void main() {
  group('UnifiedDeviceCategory Model', () {
    final now = DateTime.now();

    test('resolve handles null and empty keys gracefully', () {
      final fromNull = UnifiedDeviceCategory.resolve(null);
      expect(fromNull.key, 'other');
      expect(fromNull.isCustom, isFalse);

      final fromEmpty = UnifiedDeviceCategory.resolve('   ');
      expect(fromEmpty.key, 'other');
      expect(fromEmpty.isCustom, isFalse);
    });

    test('resolve matches custom categories before built-ins and falls back to custom unknown', () {
      final custom = CustomDeviceCategory(
        id: 'nas_custom',
        label: 'Custom Storage',
        iconName: 'storage',
        createdAt: now,
        updatedAt: now,
      );

      final resolvedCustom = UnifiedDeviceCategory.resolve(
        'nas_custom',
        customCategories: [custom],
      );
      expect(resolvedCustom.key, 'nas_custom');
      expect(resolvedCustom.label, 'Custom Storage');
      expect(resolvedCustom.isCustom, isTrue);

      final resolvedBuiltIn = UnifiedDeviceCategory.resolve('server');
      expect(resolvedBuiltIn.key, 'server');
      expect(resolvedBuiltIn.isCustom, isFalse);

      final resolvedUnknown = UnifiedDeviceCategory.resolve('special_device');
      expect(resolvedUnknown.key, 'special_device');
      expect(resolvedUnknown.label, 'special_device');
      expect(resolvedUnknown.isCustom, isTrue);
    });

    test('getAll preserves ordering with Other Device at the end', () {
      final custom1 = CustomDeviceCategory(
        id: 'iot_gate',
        label: 'IoT Gate',
        createdAt: now,
        updatedAt: now,
      );
      final custom2 = CustomDeviceCategory(
        id: 'smart_meter',
        label: 'Smart Meter',
        createdAt: now,
        updatedAt: now,
      );

      final list = UnifiedDeviceCategory.getAll(customCategories: [custom1, custom2]);
      expect(list.first.key, 'pc');
      expect(list.any((c) => c.key == 'iot_gate'), isTrue);
      expect(list.any((c) => c.key == 'smart_meter'), isTrue);
      expect(list.last.key, 'other');
    });

    test('toString, operator ==, and hashCode behave correctly', () {
      const u1 = UnifiedDeviceCategory(
        key: 'pc',
        label: 'Workstation',
        icon: Icons.computer,
        isCustom: false,
      );
      const u2 = UnifiedDeviceCategory(
        key: 'pc',
        label: 'Different Label',
        icon: Icons.computer,
        isCustom: false,
      );
      const u3 = UnifiedDeviceCategory(
        key: 'laptop',
        label: 'Laptop',
        icon: Icons.laptop_mac,
        isCustom: false,
      );

      expect(u1.toString(), contains('pc'));
      expect(u1 == u2, isTrue); // Equality based on key
      expect(u1.hashCode, u2.hashCode);
      expect(u1 == u3, isFalse);
    });
  });
}
