import 'package:flutter_test/flutter_test.dart';
import 'package:network_suite_shared/network_suite_shared.dart';

void main() {
  group('OuiLookup Service Extended Tests', () {
    test('lookupVendor handles short and invalid inputs', () {
      expect(OuiLookup.lookupVendor(''), 'Unknown Hardware');
      expect(OuiLookup.lookupVendor('1234'), 'Unknown Hardware');
      expect(OuiLookup.lookupVendor('00:11'), 'Unknown Hardware');
    });

    test('lookupVendor detects broadcast and protocol multicast addresses', () {
      expect(OuiLookup.lookupVendor('FF:FF:FF:FF:FF:FF'), 'Broadcast Address (L2)');
      expect(OuiLookup.lookupVendor('00:00:5E:00:01:05'), 'IETF VRRP Virtual Router');
      expect(OuiLookup.lookupVendor('00:00:0C:07:AC:01'), 'Cisco HSRP Virtual Router');
      expect(OuiLookup.lookupVendor('00:00:0C:9F:F0:01'), 'Cisco HSRP Virtual Router');
      expect(OuiLookup.lookupVendor('01:00:5E:7F:00:01'), 'IPv4 Multicast (IANA)');
      expect(OuiLookup.lookupVendor('33:33:00:00:00:01'), 'IPv6 Multicast (NDP)');
    });

    test('lookupVendor detects locally administered (randomized / private) MAC addresses', () {
      // 2nd hex digit has LAA bit set (2, 6, A, E)
      expect(OuiLookup.lookupVendor('02:00:00:00:00:01'), 'Randomized / Private MAC');
      expect(OuiLookup.lookupVendor('DA:A1:19:67:89:AB'), 'Randomized / Private MAC');
      expect(OuiLookup.lookupVendor('FE:11:22:33:44:55'), 'Randomized / Private MAC');
      expect(OuiLookup.lookupVendor('06:AA:BB:CC:DD:EE'), 'Randomized / Private MAC');
    });

    test('lookupVendor returns Unknown Vendor for globally administered unmapped OUIs', () {
      // 00 is universally administered (LAA bit not set)
      expect(OuiLookup.lookupVendor('00:99:99:11:22:33'), 'Unknown Vendor');
    });

    test('inferCategory categorizes common hardware brands and keywords', () {
      // Router / Gateway
      expect(OuiLookup.inferCategory('PFSense Technologies'), DeviceCategory.router);
      expect(OuiLookup.inferCategory('Netgate'), DeviceCategory.router);
      expect(OuiLookup.inferCategory('Fortinet'), DeviceCategory.router);
      expect(OuiLookup.inferCategory(null, 'Main Gateway'), DeviceCategory.router);

      // Switch
      expect(OuiLookup.inferCategory('Arista Networks'), DeviceCategory.switchDevice);
      expect(OuiLookup.inferCategory('Extreme Networks'), DeviceCategory.switchDevice);
      expect(OuiLookup.inferCategory(null, 'Core Switch'), DeviceCategory.switchDevice);

      // AP / Wi-Fi
      expect(OuiLookup.inferCategory('Ubiquiti Networks'), DeviceCategory.accessPoint);
      expect(OuiLookup.inferCategory('Aruba Networks'), DeviceCategory.accessPoint);
      expect(OuiLookup.inferCategory(null, 'Warehouse Access Point'), DeviceCategory.accessPoint);

      // Servers
      expect(OuiLookup.inferCategory('Super Micro Computer'), DeviceCategory.server);
      expect(OuiLookup.inferCategory('VMware, Inc.'), DeviceCategory.server);
      expect(OuiLookup.inferCategory('Proxmox Server Solutions'), DeviceCategory.server);
      expect(OuiLookup.inferCategory('QEMU Virtual Machine'), DeviceCategory.server);

      // NAS
      expect(OuiLookup.inferCategory('QNAP Systems'), DeviceCategory.nas);
      expect(OuiLookup.inferCategory(null, 'Backup Storage'), DeviceCategory.nas);

      // Printers
      expect(OuiLookup.inferCategory('Xerox Corporation'), DeviceCategory.printer);
      expect(OuiLookup.inferCategory('Seiko Epson'), DeviceCategory.printer);
      expect(OuiLookup.inferCategory('Brother Industries'), DeviceCategory.printer);

      // Cameras
      expect(OuiLookup.inferCategory('Axis Communications'), DeviceCategory.camera);
      expect(OuiLookup.inferCategory('Hikvision Digital Technology'), DeviceCategory.camera);
      expect(OuiLookup.inferCategory(null, 'Security Camera'), DeviceCategory.camera);

      // IoT
      expect(OuiLookup.inferCategory('Espressif Inc.'), DeviceCategory.iot);
      expect(OuiLookup.inferCategory('Sonos, Inc.'), DeviceCategory.iot);
      expect(OuiLookup.inferCategory(null, 'ESP32 Sensor'), DeviceCategory.iot);

      // Mobile
      expect(OuiLookup.inferCategory('Samsung Electronics'), DeviceCategory.mobile);
      expect(OuiLookup.inferCategory(null, 'iPad Air'), DeviceCategory.mobile);

      // Laptop
      expect(OuiLookup.inferCategory(null, 'MacBook Pro'), DeviceCategory.laptop);
      expect(OuiLookup.inferCategory(null, 'Lenovo ThinkPad'), DeviceCategory.laptop);

      // PC
      expect(OuiLookup.inferCategory('Intel Corporate'), DeviceCategory.pc);
      expect(OuiLookup.inferCategory('Realtek Semiconductor'), DeviceCategory.pc);
      expect(OuiLookup.inferCategory('MSI Computer'), DeviceCategory.pc);
      expect(OuiLookup.inferCategory('ASUSTek Computer'), DeviceCategory.pc);

      // Fallback
      expect(OuiLookup.inferCategory('Unrecognized Vendor', 'Random Item'), DeviceCategory.other);
      expect(OuiLookup.inferCategory(null, null), DeviceCategory.other);
    });
  });
}
