import 'package:flutter/material.dart';

import 'custom_device_category.dart';
import 'device_category.dart';

/// Unified representation merging built-in [DeviceCategory] enum values
/// and dynamic user-created [CustomDeviceCategory] entries.
///
/// Enables UI dropdowns, selector menus, and filter chips to display both
/// seamlessly.
class UnifiedDeviceCategory {
  /// Category identifier/slug (e.g. "pc", "switch", "firewall", "smart_tv").
  final String key;

  /// Human-readable label for UI display.
  final String label;

  /// Material icon representing this category.
  final IconData icon;

  /// Whether this category was created by the user (`true`) or is a built-in default (`false`).
  final bool isCustom;

  /// Optional hex color code for UI accents (e.g. "#FF5722").
  final String? colorHex;

  /// Resolved [Color] for custom category accents, if defined.
  final Color? color;

  const UnifiedDeviceCategory({
    required this.key,
    required this.label,
    required this.icon,
    this.isCustom = false,
    this.colorHex,
    this.color,
  });

  /// Creates a [UnifiedDeviceCategory] from a built-in [DeviceCategory].
  factory UnifiedDeviceCategory.fromBuiltIn(DeviceCategory category) {
    return UnifiedDeviceCategory(
      key: category.key,
      label: category.label,
      icon: category.icon,
      isCustom: false,
    );
  }

  /// Creates a [UnifiedDeviceCategory] from a [CustomDeviceCategory].
  factory UnifiedDeviceCategory.fromCustom(CustomDeviceCategory custom) {
    return UnifiedDeviceCategory(
      key: custom.id,
      label: custom.label,
      icon: custom.icon,
      isCustom: true,
      colorHex: custom.colorHex,
      color: custom.color,
    );
  }

  /// Resolves a category key into a [UnifiedDeviceCategory].
  ///
  /// Checks against provided [customCategories] first, then built-in [DeviceCategory]
  /// values, and falls back to [DeviceCategory.other].
  static UnifiedDeviceCategory resolve(
    String? key, {
    List<CustomDeviceCategory> customCategories = const [],
  }) {
    if (key == null || key.trim().isEmpty) {
      return UnifiedDeviceCategory.fromBuiltIn(DeviceCategory.other);
    }

    final cleanKey = key.trim().toLowerCase();

    // 1. Check custom categories
    for (final custom in customCategories) {
      if (custom.id.trim().toLowerCase() == cleanKey) {
        return UnifiedDeviceCategory.fromCustom(custom);
      }
    }

    // 2. Check built-in categories
    for (final builtIn in DeviceCategory.values) {
      if (builtIn.key.trim().toLowerCase() == cleanKey) {
        return UnifiedDeviceCategory.fromBuiltIn(builtIn);
      }
    }

    // 3. Fallback: return as custom with devices_other icon if unknown
    return UnifiedDeviceCategory(
      key: cleanKey,
      label: key,
      icon: Icons.devices_other,
      isCustom: true,
    );
  }

  /// Combines all built-in categories with the user-defined [customCategories].
  ///
  /// Places built-in categories first, followed by custom categories,
  /// with "Other Device" retained at the end of the list.
  static List<UnifiedDeviceCategory> getAll({
    List<CustomDeviceCategory> customCategories = const [],
  }) {
    final list = <UnifiedDeviceCategory>[];

    // Built-ins (except 'other')
    for (final builtIn in DeviceCategory.values) {
      if (builtIn != DeviceCategory.other) {
        list.add(UnifiedDeviceCategory.fromBuiltIn(builtIn));
      }
    }

    // Custom user categories
    for (final custom in customCategories) {
      list.add(UnifiedDeviceCategory.fromCustom(custom));
    }

    // 'Other' as the final fallback entry
    list.add(UnifiedDeviceCategory.fromBuiltIn(DeviceCategory.other));

    return list;
  }

  @override
  String toString() =>
      'UnifiedDeviceCategory(key: $key, label: $label, isCustom: $isCustom)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnifiedDeviceCategory &&
          runtimeType == other.runtimeType &&
          key == other.key;

  @override
  int get hashCode => key.hashCode;
}
