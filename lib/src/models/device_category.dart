import 'package:flutter/material.dart';

/// Predefined device categories for network hardware.
enum DeviceCategory {
  pc('Workstation / PC', 'pc', Icons.computer),
  laptop('Laptop', 'laptop', Icons.laptop_mac),
  server('Server', 'server', Icons.dns),
  router('Router / Gateway', 'router', Icons.router),
  switchDevice('Network Switch', 'switch', Icons.hub),
  accessPoint('Access Point', 'ap', Icons.wifi_tethering),
  mobile('Mobile / Tablet', 'mobile', Icons.smartphone),
  printer('Printer', 'printer', Icons.print),
  nas('Storage / NAS', 'nas', Icons.storage),
  iot('IoT / Smart Home', 'iot', Icons.sensors),
  camera('IP Camera', 'camera', Icons.videocam),
  other('Other Device', 'other', Icons.devices_other);

  final String label;
  final String key;
  final IconData icon;

  const DeviceCategory(this.label, this.key, this.icon);

  static DeviceCategory fromKey(String? key) {
    if (key == null) return DeviceCategory.other;
    final normalized = key.trim().toLowerCase();
    return DeviceCategory.values.firstWhere(
      (e) => e.key == normalized,
      orElse: () => DeviceCategory.other,
    );
  }
}
