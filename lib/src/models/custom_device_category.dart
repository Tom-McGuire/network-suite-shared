import 'package:flutter/material.dart';

/// Represents a user-defined custom device category stored in `custom_device_categories`.
class CustomDeviceCategory {
  /// Unique slug identifier (e.g. "firewall", "smart_tv", "voip_phone").
  final String id;

  /// Human-readable display label (e.g. "Firewall / UTM", "Smart TV").
  final String label;

  /// Identifier for the Material Icon (e.g. "security", "tv", "gamepad").
  final String iconName;

  /// Optional hex color code for UI accents (e.g. "#FF5722").
  final String? colorHex;

  /// Timestamp when this category was created.
  final DateTime createdAt;

  /// Timestamp when this category was last updated.
  final DateTime updatedAt;

  const CustomDeviceCategory({
    required this.id,
    required this.label,
    this.iconName = 'devices_other',
    this.colorHex,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Maps an icon name string key to a Flutter [IconData].
  static IconData iconFromName(String? name) {
    if (name == null || name.isEmpty) return Icons.devices_other;
    final clean = name.trim().toLowerCase();

    switch (clean) {
      case 'security':
      case 'shield':
      case 'firewall':
        return Icons.security;
      case 'tv':
      case 'smart_tv':
      case 'television':
        return Icons.tv;
      case 'gamepad':
      case 'gaming':
      case 'console':
        return Icons.gamepad;
      case 'dns':
      case 'server':
        return Icons.dns;
      case 'memory':
      case 'chip':
      case 'cpu':
        return Icons.memory;
      case 'router':
      case 'gateway':
        return Icons.router;
      case 'developer_board':
      case 'raspberry_pi':
      case 'arduino':
      case 'iot_board':
        return Icons.developer_board;
      case 'computer':
      case 'pc':
      case 'workstation':
        return Icons.computer;
      case 'laptop':
        return Icons.laptop_mac;
      case 'switch':
      case 'hub':
        return Icons.hub;
      case 'ap':
      case 'access_point':
      case 'wifi_tethering':
        return Icons.wifi_tethering;
      case 'wifi':
        return Icons.wifi;
      case 'mobile':
      case 'smartphone':
      case 'phone':
        return Icons.smartphone;
      case 'tablet':
        return Icons.tablet_mac;
      case 'printer':
      case 'print':
        return Icons.print;
      case 'nas':
      case 'storage':
        return Icons.storage;
      case 'iot':
      case 'sensors':
        return Icons.sensors;
      case 'camera':
      case 'videocam':
      case 'cctv':
        return Icons.videocam;
      case 'lan':
      case 'ethernet':
        return Icons.lan;
      case 'settings_ethernet':
        return Icons.settings_ethernet;
      case 'voip':
      case 'phone_in_talk':
        return Icons.phone_in_talk;
      case 'cloud':
        return Icons.cloud;
      case 'terminal':
        return Icons.terminal;
      case 'audiotrack':
      case 'speaker':
      case 'audio':
        return Icons.speaker;
      case 'lightbulb':
      case 'smart_light':
        return Icons.lightbulb;
      case 'power':
      case 'smart_plug':
        return Icons.power;
      case 'devices_other':
      default:
        return Icons.devices_other;
    }
  }

  /// Resolved [IconData] for this custom category.
  IconData get icon => iconFromName(iconName);

  /// Resolved [Color] from [colorHex], or null if unparseable/missing.
  Color? get color {
    if (colorHex == null || colorHex!.trim().isEmpty) return null;
    try {
      final clean = colorHex!.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      } else if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'icon_name': iconName,
      'color_hex': colorHex,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CustomDeviceCategory.fromMap(Map<String, dynamic> map) {
    return CustomDeviceCategory(
      id: map['id'] as String,
      label: (map['label'] as String?)?.trim() ?? '',
      iconName: (map['icon_name'] as String?)?.trim() ?? 'devices_other',
      colorHex: map['color_hex'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  CustomDeviceCategory copyWith({
    String? id,
    String? label,
    String? iconName,
    String? colorHex,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomDeviceCategory(
      id: id ?? this.id,
      label: label ?? this.label,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'CustomDeviceCategory(id: $id, label: $label, icon: $iconName, color: $colorHex)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomDeviceCategory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
