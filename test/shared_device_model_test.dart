import 'package:flutter_test/flutter_test.dart';
import 'package:network_suite_shared/network_suite_shared.dart';

void main() {
  group('SharedDevice Model', () {
    final testDate1 = DateTime.parse('2026-10-31T10:00:00.000Z');
    final testDate2 = DateTime.parse('2026-10-31T12:00:00.000Z');

    final device = SharedDevice(
      macAddress: '00:1A:2B:3C:4D:5E',
      name: 'Living Room Apple TV',
      vendor: 'Apple, Inc.',
      deviceType: 'pc',
      notes: 'Shelf 2',
      sourceApp: 'test_app',
      createdAt: testDate1,
      updatedAt: testDate2,
    );

    test('category getter resolves DeviceCategory', () {
      expect(device.category, DeviceCategory.pc);

      final unkDevice = device.copyWith(deviceType: 'unknown_type');
      expect(unkDevice.category, DeviceCategory.other);
    });

    test('getUnifiedCategory resolves built-in and custom categories', () {
      final builtInUnified = device.getUnifiedCategory();
      expect(builtInUnified.key, 'pc');
      expect(builtInUnified.isCustom, isFalse);

      final customCategory = CustomDeviceCategory(
        id: 'smart_tv',
        label: 'Smart TV',
        iconName: 'tv',
        createdAt: testDate1,
        updatedAt: testDate2,
      );

      final tvDevice = device.copyWith(deviceType: 'smart_tv');
      final tvUnified = tvDevice.getUnifiedCategory([customCategory]);
      expect(tvUnified.key, 'smart_tv');
      expect(tvUnified.label, 'Smart TV');
      expect(tvUnified.isCustom, isTrue);
    });

    test('copyWith updates specified fields only', () {
      final updated = device.copyWith(
        name: 'New Name',
        notes: 'New Notes',
      );

      expect(updated.name, 'New Name');
      expect(updated.notes, 'New Notes');
      expect(updated.macAddress, device.macAddress);
      expect(updated.vendor, device.vendor);
      expect(updated.deviceType, device.deviceType);
      expect(updated.sourceApp, device.sourceApp);

      final macUpdated = device.copyWith(macAddress: 'aa-bb-cc-dd-ee-ff');
      expect(macUpdated.macAddress, 'AA:BB:CC:DD:EE:FF');
    });

    test('toMap and fromMap serialize and deserialize cleanly', () {
      final map = device.toMap();
      expect(map['mac_address'], '00:1A:2B:3C:4D:5E');
      expect(map['name'], 'Living Room Apple TV');
      expect(map['vendor'], 'Apple, Inc.');
      expect(map['device_type'], 'pc');
      expect(map['notes'], 'Shelf 2');
      expect(map['source_app'], 'test_app');
      expect(map['created_at'], testDate1.toIso8601String());
      expect(map['updated_at'], testDate2.toIso8601String());

      final fromMap = SharedDevice.fromMap(map);
      expect(fromMap, equals(device));
      expect(fromMap.notes, device.notes);
      expect(fromMap.sourceApp, device.sourceApp);
    });

    test('fromMap applies sensible defaults for missing or null fields', () {
      final minimal = SharedDevice.fromMap({
        'mac_address': '001122334455',
      });

      expect(minimal.macAddress, '00:11:22:33:44:55');
      expect(minimal.name, 'Unknown Device');
      expect(minimal.sourceApp, 'system');
      expect(minimal.vendor, isNull);
      expect(minimal.deviceType, isNull);
      expect(minimal.notes, isNull);
      expect(minimal.createdAt, isA<DateTime>());
      expect(minimal.updatedAt, isA<DateTime>());
    });

    test('toString, operator ==, and hashCode behave correctly', () {
      final device2 = SharedDevice(
        macAddress: '00:1A:2B:3C:4D:5E',
        name: 'Different Name',
        sourceApp: 'other',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final device3 = SharedDevice(
        macAddress: '11:22:33:44:55:66',
        name: 'Living Room Apple TV',
        sourceApp: 'test_app',
        createdAt: testDate1,
        updatedAt: testDate2,
      );

      expect(device.toString(), contains('00:1A:2B:3C:4D:5E'));
      expect(device == device2, isTrue); // Equality is based on MAC address
      expect(device.hashCode, device2.hashCode);
      expect(device == device3, isFalse);
    });

    test('hasCustomName detects real names vs auto-generated placeholders', () {
      // Custom names -> true
      expect(device.hasCustomName, isTrue);
      expect(device.copyWith(name: "Tom's Gaming Rig").hasCustomName, isTrue);
      expect(device.copyWith(name: 'Core-Switch-01').hasCustomName, isTrue);

      // Auto-generated placeholders -> false
      expect(device.copyWith(name: 'Device 00:1A:2B:3C:4D:5E').hasCustomName, isFalse);
      expect(device.copyWith(name: 'Device 001a2b3c4d5e').hasCustomName, isFalse);
      expect(device.copyWith(name: 'Device 00-1A-2B-3C-4D-5E').hasCustomName, isFalse);
      expect(device.copyWith(name: '00:1A:2B:3C:4D:5E').hasCustomName, isFalse);
      expect(device.copyWith(name: '001A2B3C4D5E').hasCustomName, isFalse);
      expect(device.copyWith(name: 'Unknown Device').hasCustomName, isFalse);
      expect(device.copyWith(name: '   ').hasCustomName, isFalse);
      expect(device.copyWith(name: '').hasCustomName, isFalse);
    });
  });
}
