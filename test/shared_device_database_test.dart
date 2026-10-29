import 'package:flutter_test/flutter_test.dart';
import 'package:network_suite_shared/network_suite_shared.dart';

void main() {
  group('SharedDevice model & MAC Normalization', () {
    test('normalizes various raw MAC address formats correctly', () {
      const canonical = '00:1A:2B:3C:4D:5E';

      expect(SharedDevice.normalizeMac('001A2B3C4D5E'), canonical);
      expect(SharedDevice.normalizeMac('00-1A-2B-3C-4D-5E'), canonical);
      expect(SharedDevice.normalizeMac('00:1a:2b:3c:4d:5e'), canonical);
      expect(SharedDevice.normalizeMac('001a.2b3c.4d5e'), canonical);
      expect(SharedDevice.normalizeMac('  00 1a 2b 3c 4d 5e  '), canonical);
    });

    test('validates 6-byte MAC addresses', () {
      expect(SharedDevice.isValidMac('00:1A:2B:3C:4D:5E'), isTrue);
      expect(SharedDevice.isValidMac('001122334455'), isTrue);
      expect(SharedDevice.isValidMac('000000000000'), isFalse);
      expect(SharedDevice.isValidMac('192.168.1.1'), isFalse);
      expect(SharedDevice.isValidMac('not_a_mac'), isFalse);
    });

    test('extracts 3-byte OUI prefix', () {
      final device = SharedDevice(
        macAddress: '00:1A:2B:3C:4D:5E',
        name: 'Test Device',
        sourceApp: 'unit_test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(device.ouiPrefix, '001A2B');
    });
  });

  group('OuiLookup Service', () {
    test('resolves known vendors and multicast/virtual addresses', () {
      expect(OuiLookup.lookupVendor('00:00:0C:11:22:33'), 'Cisco Systems, Inc.');
      expect(OuiLookup.lookupVendor('F0:18:98:AA:BB:CC'), 'Apple, Inc.');
      expect(OuiLookup.lookupVendor('B8:27:EB:01:02:03'), 'Raspberry Pi Foundation');
      expect(OuiLookup.lookupVendor('01:00:5E:00:00:01'), 'IPv4 Multicast (IANA)');
    });

    test('infers category from vendor/name', () {
      expect(OuiLookup.inferCategory('Cisco Systems', 'Core Switch'), DeviceCategory.switchDevice);
      expect(OuiLookup.inferCategory('MikroTik', 'Main Gateway'), DeviceCategory.router);
      expect(OuiLookup.inferCategory('Synology Incorporated', 'DiskStation'), DeviceCategory.nas);
      expect(OuiLookup.inferCategory('HP Inc.', 'Office LaserJet'), DeviceCategory.printer);
      expect(OuiLookup.inferCategory('Apple, Inc.', "Tom's iPhone"), DeviceCategory.mobile);
    });
  });

  group('SharedDeviceDatabase CRUD & Name Updates', () {
    late SharedDeviceDatabase db;

    setUp(() async {
      db = SharedDeviceDatabase();
      await db.init(dbPath: ':memory:');
    });

    tearDown(() {
      db.close();
    });

    test('inserts and retrieves a device by MAC', () {
      final now = DateTime.now();
      final device = SharedDevice(
        macAddress: 'aa:bb:cc:dd:ee:ff',
        name: 'Office Switch',
        vendor: 'Cisco Systems, Inc.',
        deviceType: 'switch',
        notes: 'Rack 2, Port 24',
        sourceApp: 'arp-scout',
        createdAt: now,
        updatedAt: now,
      );

      db.upsertDevice(device);

      final retrieved = db.getDeviceByMac('AA-BB-CC-DD-EE-FF');
      expect(retrieved, isNotNull);
      expect(retrieved!.macAddress, 'AA:BB:CC:DD:EE:FF');
      expect(retrieved.name, 'Office Switch');
      expect(retrieved.vendor, 'Cisco Systems, Inc.');
      expect(retrieved.deviceType, 'switch');
      expect(retrieved.notes, 'Rack 2, Port 24');
      expect(retrieved.sourceApp, 'arp-scout');
    });

    test('updates device name at any point while keeping other data intact', () {
      final now = DateTime.now();
      final device = SharedDevice(
        macAddress: '00:11:22:33:44:55',
        name: 'Initial Name',
        vendor: 'Apple, Inc.',
        deviceType: 'pc',
        sourceApp: 'launcher',
        createdAt: now,
        updatedAt: now,
      );

      db.upsertDevice(device);

      // Verify initial state
      var retrieved = db.getDeviceByMac('00:11:22:33:44:55');
      expect(retrieved!.name, 'Initial Name');

      // Update name to a custom label
      db.updateDeviceName('00:11:22:33:44:55', "Tom's MacBook Pro");

      retrieved = db.getDeviceByMac('00:11:22:33:44:55');
      expect(retrieved!.name, "Tom's MacBook Pro");
      expect(retrieved.vendor, 'Apple, Inc.'); // Vendor retained
      expect(retrieved.deviceType, 'pc');      // Category retained
    });

    test('deletes device by MAC', () {
      final now = DateTime.now();
      db.upsertDevice(SharedDevice(
        macAddress: '11:22:33:44:55:66',
        name: 'Temporary Device',
        sourceApp: 'test',
        createdAt: now,
        updatedAt: now,
      ));

      expect(db.getDeviceCount(), 1);
      db.deleteDevice('11:22:33:44:55:66');
      expect(db.getDeviceCount(), 0);
      expect(db.getDeviceByMac('11:22:33:44:55:66'), isNull);
    });

    test('queries devices with search and filters', () {
      final now = DateTime.now();
      db.upsertDevice(SharedDevice(
        macAddress: '11:11:11:11:11:11',
        name: 'Gateway Router',
        vendor: 'MikroTik',
        deviceType: 'router',
        sourceApp: 'test',
        createdAt: now,
        updatedAt: now,
      ));

      db.upsertDevice(SharedDevice(
        macAddress: '22:22:22:22:22:22',
        name: 'Database Server',
        vendor: 'Dell Inc.',
        deviceType: 'server',
        sourceApp: 'test',
        createdAt: now,
        updatedAt: now,
      ));

      // Filter by type
      final routers = db.getAllDevices(deviceType: 'router');
      expect(routers.length, 1);
      expect(routers.first.name, 'Gateway Router');

      // Search by query
      final queryResults = db.getAllDevices(query: 'Dell');
      expect(queryResults.length, 1);
      expect(queryResults.first.name, 'Database Server');
    });
  });
}
