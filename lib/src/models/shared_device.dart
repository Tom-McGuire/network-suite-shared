import 'device_category.dart';

/// Represents a persistent network device identified permanently by its MAC address.
///
/// NOTE: Volatile properties such as IP addresses are intentionally not stored here,
/// because IP addresses dynamically change via DHCP, roaming, or subnet migrations,
/// whereas MAC addresses identify hardware interfaces uniquely and permanently.
class SharedDevice {
  /// Normalized uppercase MAC address in IEEE 802 format (e.g. "00:1A:2B:3C:4D:5E").
  final String macAddress;

  /// User-defined friendly device name (e.g. "Living Room Apple TV", "Tom's Gaming Rig").
  /// This can be updated at any time.
  final String name;

  /// Hardware vendor / manufacturer derived from OUI or user specified (e.g. "Apple, Inc.", "Cisco").
  final String? vendor;

  /// Device category key matching [DeviceCategory.key] (e.g. "pc", "router", "iot").
  final String? deviceType;

  /// Freeform user notes or inventory metadata.
  final String? notes;

  /// Name of the suite application that registered or last updated this entry.
  final String sourceApp;

  /// Timestamp when this device was first recorded.
  final DateTime createdAt;

  /// Timestamp when this device or its name was last modified.
  final DateTime updatedAt;

  const SharedDevice({
    required this.macAddress,
    required this.name,
    this.vendor,
    this.deviceType,
    this.notes,
    required this.sourceApp,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Normalizes any common MAC address string format
  /// (e.g. "001122334455", "00-11-22-33-44-55", "0011.2233.4455", "00:11:22:33:44:55")
  /// into canonical uppercase "00:11:22:33:44:55".
  static String normalizeMac(String raw) {
    final clean = raw.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
    if (clean.length != 12) {
      return raw.trim().toUpperCase();
    }
    return List.generate(6, (i) => clean.substring(i * 2, (i * 2) + 2)).join(':');
  }

  /// Validates whether the given string represents a valid 6-byte MAC address.
  static bool isValidMac(String raw) {
    final clean = raw.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    return clean.length == 12 && clean != '000000000000';
  }

  /// Extracts the 3-byte OUI prefix in uppercase (e.g. "00:1A:2B" or "001A2B").
  String get ouiPrefix {
    final clean = macAddress.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
    if (clean.length >= 6) {
      return clean.substring(0, 6);
    }
    return '';
  }

  /// Returns the corresponding [DeviceCategory] enum value.
  DeviceCategory get category => DeviceCategory.fromKey(deviceType);

  SharedDevice copyWith({
    String? macAddress,
    String? name,
    String? vendor,
    String? deviceType,
    String? notes,
    String? sourceApp,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SharedDevice(
      macAddress: macAddress != null ? normalizeMac(macAddress) : this.macAddress,
      name: name ?? this.name,
      vendor: vendor ?? this.vendor,
      deviceType: deviceType ?? this.deviceType,
      notes: notes ?? this.notes,
      sourceApp: sourceApp ?? this.sourceApp,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mac_address': macAddress,
      'name': name,
      'vendor': vendor,
      'device_type': deviceType,
      'notes': notes,
      'source_app': sourceApp,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SharedDevice.fromMap(Map<String, dynamic> map) {
    return SharedDevice(
      macAddress: normalizeMac(map['mac_address'] as String? ?? ''),
      name: (map['name'] as String?)?.trim() ?? 'Unknown Device',
      vendor: map['vendor'] as String?,
      deviceType: map['device_type'] as String?,
      notes: map['notes'] as String?,
      sourceApp: (map['source_app'] as String?) ?? 'system',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  String toString() =>
      'SharedDevice(mac: $macAddress, name: $name, vendor: $vendor, type: $deviceType)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharedDevice &&
          runtimeType == other.runtimeType &&
          macAddress == other.macAddress;

  @override
  int get hashCode => macAddress.hashCode;
}
