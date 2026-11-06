import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_suite_shared/network_suite_shared.dart';

void main() {
  group('CustomDeviceCategory Model', () {
    final now = DateTime.now();

    test('iconFromName maps all supported identifier keys', () {
      final mappings = {
        'security': Icons.security,
        'shield': Icons.security,
        'firewall': Icons.security,
        'tv': Icons.tv,
        'smart_tv': Icons.tv,
        'television': Icons.tv,
        'gamepad': Icons.gamepad,
        'gaming': Icons.gamepad,
        'console': Icons.gamepad,
        'dns': Icons.dns,
        'server': Icons.dns,
        'memory': Icons.memory,
        'chip': Icons.memory,
        'cpu': Icons.memory,
        'router': Icons.router,
        'gateway': Icons.router,
        'developer_board': Icons.developer_board,
        'raspberry_pi': Icons.developer_board,
        'arduino': Icons.developer_board,
        'iot_board': Icons.developer_board,
        'computer': Icons.computer,
        'pc': Icons.computer,
        'workstation': Icons.computer,
        'laptop': Icons.laptop_mac,
        'switch': Icons.hub,
        'hub': Icons.hub,
        'ap': Icons.wifi_tethering,
        'access_point': Icons.wifi_tethering,
        'wifi_tethering': Icons.wifi_tethering,
        'wifi': Icons.wifi,
        'mobile': Icons.smartphone,
        'smartphone': Icons.smartphone,
        'phone': Icons.smartphone,
        'tablet': Icons.tablet_mac,
        'printer': Icons.print,
        'print': Icons.print,
        'nas': Icons.storage,
        'storage': Icons.storage,
        'iot': Icons.sensors,
        'sensors': Icons.sensors,
        'camera': Icons.videocam,
        'videocam': Icons.videocam,
        'cctv': Icons.videocam,
        'lan': Icons.lan,
        'ethernet': Icons.lan,
        'settings_ethernet': Icons.settings_ethernet,
        'voip': Icons.phone_in_talk,
        'phone_in_talk': Icons.phone_in_talk,
        'cloud': Icons.cloud,
        'terminal': Icons.terminal,
        'audiotrack': Icons.speaker,
        'speaker': Icons.speaker,
        'audio': Icons.speaker,
        'lightbulb': Icons.lightbulb,
        'smart_light': Icons.lightbulb,
        'power': Icons.power,
        'smart_plug': Icons.power,
        'devices_other': Icons.devices_other,
        '': Icons.devices_other,
        'unknown_icon_xyz': Icons.devices_other,
      };

      for (final entry in mappings.entries) {
        expect(
          CustomDeviceCategory.iconFromName(entry.key),
          equals(entry.value),
          reason: 'Failed for icon key: ${entry.key}',
        );
      }

      expect(CustomDeviceCategory.iconFromName(null), Icons.devices_other);
    });

    test('color parser parses 6-digit and 8-digit hex colors safely', () {
      final cat6 = CustomDeviceCategory(
        id: 'c1',
        label: 'C1',
        colorHex: '#FF5722',
        createdAt: now,
        updatedAt: now,
      );
      expect(cat6.color, equals(const Color(0xFFFF5722)));

      final cat8 = CustomDeviceCategory(
        id: 'c2',
        label: 'C2',
        colorHex: '80FF5722',
        createdAt: now,
        updatedAt: now,
      );
      expect(cat8.color, equals(const Color(0x80FF5722)));

      final catInvalid = CustomDeviceCategory(
        id: 'c3',
        label: 'C3',
        colorHex: 'not_a_color',
        createdAt: now,
        updatedAt: now,
      );
      expect(catInvalid.color, isNull);

      final catEmpty = CustomDeviceCategory(
        id: 'c4',
        label: 'C4',
        colorHex: '',
        createdAt: now,
        updatedAt: now,
      );
      expect(catEmpty.color, isNull);

      final catNull = CustomDeviceCategory(
        id: 'c5',
        label: 'C5',
        colorHex: null,
        createdAt: now,
        updatedAt: now,
      );
      expect(catNull.color, isNull);
    });

    test('copyWith updates fields as requested', () {
      final cat = CustomDeviceCategory(
        id: 'cat_id',
        label: 'Original Label',
        iconName: 'tv',
        colorHex: '#123456',
        createdAt: now,
        updatedAt: now,
      );

      final updated = cat.copyWith(
        label: 'New Label',
        iconName: 'speaker',
      );

      expect(updated.id, 'cat_id');
      expect(updated.label, 'New Label');
      expect(updated.iconName, 'speaker');
      expect(updated.colorHex, '#123456');

      final later = now.add(const Duration(minutes: 5));
      final allUpdated = cat.copyWith(
        id: 'new_id',
        label: 'All Updated',
        iconName: 'router',
        colorHex: '#654321',
        createdAt: later,
        updatedAt: later,
      );
      expect(allUpdated.id, 'new_id');
      expect(allUpdated.label, 'All Updated');
      expect(allUpdated.iconName, 'router');
      expect(allUpdated.colorHex, '#654321');
      expect(allUpdated.createdAt, later);
      expect(allUpdated.updatedAt, later);
    });

    test('fromMap handles missing optional timestamps and fields cleanly', () {
      final minimal = CustomDeviceCategory.fromMap({
        'id': 'minimal_id',
      });
      expect(minimal.id, 'minimal_id');
      expect(minimal.label, '');
      expect(minimal.iconName, 'devices_other');
      expect(minimal.colorHex, isNull);
      expect(minimal.createdAt, isA<DateTime>());
      expect(minimal.updatedAt, isA<DateTime>());
    });

    test('toString, operator ==, and hashCode behave correctly', () {
      final cat1 = CustomDeviceCategory(
        id: 'cat_id',
        label: 'Label 1',
        createdAt: now,
        updatedAt: now,
      );
      final cat2 = CustomDeviceCategory(
        id: 'cat_id',
        label: 'Label 2',
        createdAt: now,
        updatedAt: now,
      );
      final cat3 = CustomDeviceCategory(
        id: 'other_id',
        label: 'Label 1',
        createdAt: now,
        updatedAt: now,
      );

      expect(cat1.toString(), contains('cat_id'));
      expect(cat1 == cat2, isTrue); // Equality based on id
      expect(cat1.hashCode, cat2.hashCode);
      expect(cat1 == cat3, isFalse);
    });
  });
}
