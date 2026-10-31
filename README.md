# network_suite_shared

Shared device models, IEEE OUI vendor resolution, and cross-process SQLite database engine for the Network Suite ecosystem (Syslog Server, ARP-Scout, Net-App-Launcher, etc.).

---

## Overview

In the Network Suite ecosystem, multiple standalone desktop applications run simultaneously and interact with the same local physical network devices. `network_suite_shared` provides a centralized, cross-process data store and shared utilities so all tools share a unified view of device identities.

### Core Principles

- **MAC Address as Primary Identity**: Network devices are identified permanently by their physical MAC address in canonical uppercase IEEE 802 format (`XX:XX:XX:XX:XX:XX`).
- **Exclusion of Volatile Attributes**: Dynamic properties like IP addresses are deliberately **not** stored in this database. IP addresses change across DHCP leases, roaming, and subnet renumbering, whereas MAC addresses identify hardware interfaces uniquely and permanently. Each individual application tracks its own runtime IP-to-MAC associations.
- **Cross-Process Concurrency**: Multiple standalone apps (e.g., Syslog Server listening in the background while ARP-Scout runs a sweep and Net-App-Launcher manages devices) read and write to the same SQLite database file without locking conflicts.
- **Resilient Fallback**: Applications can gracefully degrade to offline vendor lookups if the shared database is temporarily unreachable or uninitialized.

---

## Features

- **Cross-Process SQLite Storage**: Configured with SQLite Write-Ahead Logging (WAL) and a 5-second busy timeout for concurrent multi-process access.
- **Canonical Storage Locations**: Automatically resolves platform-standard directories on Linux, macOS, and Windows.
- **MAC Normalization & Validation**: Robust parsing supporting colon (`00:1A:2B:3C:4D:5E`), hyphen (`00-1A-2B-3C-4D-5E`), Cisco dotted-quad (`001a.2b3c.4d5e`), and raw hex formats.
- **Offline OUI Vendor Lookup**: Built-in IEEE OUI lookup database mapping MAC prefixes to manufacturers (Apple, Cisco, Raspberry Pi, Ubiquiti, etc.), virtual router addresses (VRRP, Cisco HSRP), multicast ranges, and randomized/private MAC detection.
- **Device Categorization & Custom Categories**: 12 predefined built-in categories (`DeviceCategory`) plus user-created custom categories (`CustomDeviceCategory`) with custom Material icons and color accents.
- **Unified Category Resolution**: Unified model (`UnifiedDeviceCategory`) merging built-in and user categories for UI dropdowns, filter chips, and selector dialogues.
- **Full Metadata Editing**: Full device detail editing (`updateDeviceDetails`) allowing simultaneous updates to friendly name, device category, vendor override, and freeform notes.
- **Reactivity**: Broadcast change notifications (`onDatabaseChanged`) to refresh application UIs when records are modified.

---

## Database Architecture

### Default File Locations

The database is stored under a common directory across the suite:

| Platform | Path |
| :--- | :--- |
| **Linux / POSIX** | `~/.local/share/NetworkSuite/shared_devices.db`<br>*(or `$XDG_DATA_HOME/NetworkSuite/shared_devices.db`)* |
| **macOS** | `~/Library/Application Support/NetworkSuite/shared_devices.db` |
| **Windows** | `%LOCALAPPDATA%\NetworkSuite\shared_devices.db`<br>*(e.g., `C:\Users\<user>\AppData\Local\NetworkSuite\shared_devices.db`)* |

### Concurrency & WAL Mode

When initialized, the database automatically applies:

```sql
PRAGMA journal_mode = WAL;
PRAGMA busy_timeout = 5000;
PRAGMA synchronous = NORMAL;
```

This guarantees readers do not block writers and writers do not block readers across separate OS processes.

### Database Schema

```sql
CREATE TABLE IF NOT EXISTS shared_devices (
  mac_address TEXT PRIMARY KEY NOT NULL,
  name        TEXT NOT NULL,
  vendor      TEXT,
  device_type TEXT,
  notes       TEXT,
  source_app  TEXT NOT NULL,
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_shared_name ON shared_devices(name);
CREATE INDEX IF NOT EXISTS idx_shared_vendor ON shared_devices(vendor);
CREATE INDEX IF NOT EXISTS idx_shared_type ON shared_devices(device_type);

CREATE TABLE IF NOT EXISTS custom_device_categories (
  id         TEXT PRIMARY KEY NOT NULL,          -- Slug/key, e.g. "firewall", "smart_tv"
  label      TEXT NOT NULL,                      -- Display name, e.g. "Firewall / UTM", "Smart TV"
  icon_name  TEXT NOT NULL DEFAULT 'devices_other', -- Material icon identifier key
  color_hex  TEXT,                               -- Optional accent color, e.g. "#FF5722"
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_custom_category_label ON custom_device_categories(label);
```

---

## Integration Guide

### 1. Add Dependency

Add `network_suite_shared` to your application's `pubspec.yaml`:

#### Git Repository (Recommended for Suite Apps)
```yaml
dependencies:
  network_suite_shared:
    git:
      url: https://github.com/Tom-McGuire/network-suite-shared.git
      ref: main
```

#### Local Path (Mono-repo / Development)
```yaml
dependencies:
  network_suite_shared:
    path: ../network-suite-shared
```

Run `flutter pub get`.

---

### 2. Initialize in `main()`

Initialize the singleton database during application startup before running the app. Wrap initialization in a `try/catch` block so your application can run standalone even if file permissions or platform sandbox issues occur:

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:network_suite_shared/network_suite_shared.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Safely initialize shared device database
  try {
    await SharedDeviceDatabase.instance.init();
  } catch (e) {
    debugPrint('Shared device database fallback: $e');
  }

  runApp(const MyApp());
}
```

---

### 3. Resolving Device Names & MAC Addresses

When your application detects a MAC address (e.g. parsed from incoming syslog packets, ARP tables, or packet capture payloads), resolve a friendly display name using this priority hierarchy:

1. **User-assigned friendly name** in `SharedDeviceDatabase`
2. **Hardware Vendor** from IEEE OUI lookup + last 3 bytes of MAC
3. **Normalized MAC address**

```dart
import 'package:network_suite_shared/network_suite_shared.dart';

String resolveDeviceDisplayName(String rawMac) {
  final normalized = SharedDevice.normalizeMac(rawMac);

  // 1. Check shared database if initialized
  if (SharedDeviceDatabase.instance.isInitialized) {
    final device = SharedDeviceDatabase.instance.getDeviceByMac(normalized);
    if (device != null && device.name.trim().isNotEmpty) {
      return device.name.trim();
    }
  }

  // 2. Fall back to OUI vendor resolution
  final vendor = OuiLookup.lookupVendor(normalized);
  if (vendor != 'Unknown Vendor' && vendor != 'Unknown Hardware') {
    final suffix = normalized.split(':').sublist(3).join(':');
    return '$vendor ($suffix)';
  }

  // 3. Fall back to MAC
  return normalized;
}
```

---

### 4. Registering or Upserting Devices

When an application discovers a new hardware device, or when a user edits device details:

```dart
import 'package:network_suite_shared/network_suite_shared.dart';

void registerDiscoveredDevice({
  required String rawMac,
  String? hostNameHint,
  required String appName,
}) {
  if (!SharedDevice.isValidMac(rawMac)) return;

  final mac = SharedDevice.normalizeMac(rawMac);
  final db = SharedDeviceDatabase.instance;
  if (!db.isInitialized) return;

  final existing = db.getDeviceByMac(mac);

  if (existing == null) {
    // New device: infer vendor and category
    final vendor = OuiLookup.lookupVendor(mac);
    final category = OuiLookup.inferCategory(vendor, hostNameHint);
    final now = DateTime.now();

    final device = SharedDevice(
      macAddress: mac,
      name: hostNameHint?.isNotEmpty == true ? hostNameHint! : 'Device $mac',
      vendor: vendor != 'Unknown Vendor' ? vendor : null,
      deviceType: category.key,
      sourceApp: appName,
      createdAt: now,
      updatedAt: now,
    );

    db.upsertDevice(device);
  }
}
```

#### Updating Only the Friendly Name

To update a device's custom name without overwriting other metadata:

```dart
SharedDeviceDatabase.instance.updateDeviceName('00:1A:2B:3C:4D:5E', 'Office Core Switch');
```

#### Full Device Metadata Editing

To edit any combination of friendly name, category, vendor, and notes in a single operation:

```dart
SharedDeviceDatabase.instance.updateDeviceDetails(
  '00:1A:2B:3C:4D:5E',
  name: 'Core Distribution Switch',
  deviceType: 'firewall',                 // Built-in key or custom category slug
  vendor: 'Cisco Systems, Inc.',
  notes: 'Rack 2, Top-of-Rack Switch connected to fiber trunk',
);
```

Any parameter left `null` keeps its existing value unchanged.

---

### 5. Managing Custom Device Categories & Unified Categories

Applications can let users define custom categories (e.g., "Firewall", "Smart TV", "Solar Inverter") with custom Material icons and accent colors:

#### Creating or Updating a Custom Category

```dart
SharedDeviceDatabase.instance.upsertCustomCategory(
  CustomDeviceCategory(
    id: 'firewall',
    label: 'Firewall / UTM',
    iconName: 'security',              // Mapped automatically to Icons.security
    colorHex: '#FF5722',               // Optional accent color
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
);
```

#### Deleting a Custom Category (Safe Cascade)

When a custom category is deleted, any devices currently assigned to that category automatically have their `device_type` migrated to `'other'`:

```dart
SharedDeviceDatabase.instance.deleteCustomCategory('firewall');
```

#### Unified Category Resolver for UI Dropdowns & Filters

Use `UnifiedDeviceCategory` or `SharedDeviceDatabase.instance.getUnifiedCategories()` to seamlessly populate dropdown menus, filter chips, and device icons without worrying whether a category is built-in or user-created:

```dart
// 1. Get all unified categories for a filter bar or dropdown
final categories = SharedDeviceDatabase.instance.getUnifiedCategories();

for (final cat in categories) {
  print('${cat.label} (key: ${cat.key}, isCustom: ${cat.isCustom})');
}

// 2. Resolve category representation for a specific device
final customCats = SharedDeviceDatabase.instance.getCustomCategories();
final unifiedCategory = device.getUnifiedCategory(customCats);

// In Flutter Widget build:
Icon(unifiedCategory.icon, color: unifiedCategory.color)
Text(unifiedCategory.label)
```

---

### 6. Listening to Cross-Process Updates

To refresh your UI or view-models whenever devices are added, updated, or removed:

```dart
class DeviceAwareViewModel extends ChangeNotifier {
  StreamSubscription? _dbSubscription;

  DeviceAwareViewModel() {
    if (SharedDeviceDatabase.instance.isInitialized) {
      _dbSubscription = SharedDeviceDatabase.instance.onDatabaseChanged.listen((_) {
        // Reload device mappings and trigger UI update
        notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _dbSubscription?.cancel();
    super.dispose();
  }
}
```

---

### 7. Querying & Filtering Devices

Query devices with keyword search, category filters, sorting, and hidden defaults:

```dart
final devices = SharedDeviceDatabase.instance.getAllDevices(
  query: 'cisco',           // Matches name, MAC, vendor, or notes
  deviceType: 'switch',     // Matches DeviceCategory key or custom category slug, or null for all
  sortBy: 'updated_at',     // 'name', 'mac', 'vendor', 'type', 'created_at', 'updated_at'
  ascending: false,
  hideDefaultNamed: true,   // Excludes auto-generated "Device XX:XX:..." placeholders
);
```

---

### 8. Unit & Integration Testing

In tests, avoid reading/writing to the host filesystem by initializing `SharedDeviceDatabase` with an in-memory SQLite database (`:memory:`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:network_suite_shared/network_suite_shared.dart';

void main() {
  late SharedDeviceDatabase db;

  setUp(() async {
    db = SharedDeviceDatabase();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() {
    db.close();
  });

  test('registers and queries test device', () {
    db.upsertDevice(SharedDevice(
      macAddress: '00:11:22:33:44:55',
      name: 'Test Router',
      sourceApp: 'unit_test',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));

    final device = db.getDeviceByMac('00-11-22-33-44-55');
    expect(device, isNotNull);
    expect(device!.name, 'Test Router');
  });
}
```

---

## API Summary

### `SharedDeviceDatabase`

| Method / Property | Description |
| :--- | :--- |
| `instance` | Default singleton database instance. |
| `init({String? dbPath})` | Opens SQLite connection, enables WAL mode, and initializes tables. |
| `isInitialized` | Boolean indicating whether the database is active. |
| `databasePath` | Filesystem path to the current database file. |
| `onDatabaseChanged` | Broadcast `Stream<void>` fired on upsert, update, or deletion. |
| `getDeviceByMac(String mac)` | Retrieves `SharedDevice?` for the normalized MAC. |
| `getAllDevices(...)` | Lists registered devices with query, type, and sort options. |
| `upsertDevice(SharedDevice device)` | Inserts or updates a device record. |
| `updateDeviceName(String mac, String newName)` | Updates only the friendly name and timestamp. |
| `updateDeviceDetails(String mac, {name, deviceType, vendor, notes})` | Updates any combination of metadata fields and triggers change notification. |
| `deleteDevice(String mac)` | Deletes a device record by MAC address. |
| `getCustomCategories()` | Lists user-created custom categories ordered alphabetically by label. |
| `getCustomCategoryById(String id)` | Retrieves a specific custom category by slug ID. |
| `upsertCustomCategory(CustomDeviceCategory category)` | Inserts or updates a user-defined category and notifies listeners. |
| `deleteCustomCategory(String id)` | Deletes a custom category, migrates its devices to `'other'`, and notifies listeners. |
| `getUnifiedCategories()` | Returns merged list of built-in and custom categories for UI dropdowns. |
| `importBatch(List<SharedDevice> devices)` | Batch inserts devices inside an atomic transaction. |
| `getDeviceCount()` | Total number of recorded devices. |
| `close()` | Closes SQLite connection and stream controllers. |

### `CustomDeviceCategory`

| Member | Type | Description |
| :--- | :--- | :--- |
| `id` | `String` | Slug identifier (e.g. `"firewall"`, `"smart_tv"`). |
| `label` | `String` | Human-readable display label (e.g. `"Firewall / UTM"`). |
| `iconName` | `String` | Material icon identifier key (e.g. `"security"`, `"tv"`). |
| `colorHex` | `String?` | Optional accent color in hex format (e.g. `"#FF5722"`). |
| `icon` | `IconData` | Resolved Flutter Material `IconData`. |
| `color` | `Color?` | Parsed Flutter `Color`, if defined. |

### `UnifiedDeviceCategory`

| Member | Type | Description |
| :--- | :--- | :--- |
| `key` | `String` | Category slug (e.g. `"router"`, `"firewall"`). |
| `label` | `String` | Human-readable label for UI display. |
| `icon` | `IconData` | Resolved Material icon. |
| `isCustom` | `bool` | `true` for user-defined categories; `false` for built-in. |
| `resolve(key, {customCategories})` | `static UnifiedDeviceCategory` | Resolves any slug into its unified category representation. |
| `getAll({customCategories})` | `static List<UnifiedDeviceCategory>` | Merges built-ins with custom categories (`other` placed last). |

### `SharedDevice`

| Member | Type | Description |
| :--- | :--- | :--- |
| `macAddress` | `String` | Canonical uppercase MAC address (`XX:XX:XX:XX:XX:XX`). |
| `name` | `String` | User-assigned or inferred friendly name. |
| `vendor` | `String?` | Hardware manufacturer (from OUI or manual). |
| `deviceType` | `String?` | Category key (matches `DeviceCategory.key`). |
| `notes` | `String?` | Optional inventory or location notes. |
| `sourceApp` | `String` | Application identifier that created or updated the entry. |
| `createdAt` | `DateTime` | Creation timestamp. |
| `updatedAt` | `DateTime` | Last update timestamp. |
| `normalizeMac(String)` | `static String` | Cleans any MAC representation into canonical format. |
| `isValidMac(String)` | `static bool` | Validates 6-byte non-zero MAC address format. |

### `OuiLookup`

| Method | Description |
| :--- | :--- |
| `lookupVendor(String mac)` | Returns manufacturer name, multicast label, or virtual router type. |
| `inferCategory(String? vendor, [String? nameHint])` | Suggests a probable `DeviceCategory` based on vendor and name keywords. |

### `DeviceCategory`

Predefined categories with Material icons:
- `pc`, `laptop`, `server`, `router`, `switchDevice` (`'switch'`), `accessPoint` (`'ap'`), `mobile`, `printer`, `nas`, `iot`, `camera`, `other`.

---

## License

This package is proprietary to the Network Suite project.
