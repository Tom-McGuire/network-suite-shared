import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../models/custom_device_category.dart';
import '../models/shared_device.dart';
import '../models/unified_device_category.dart';

/// Manages the cross-process SQLite database storing global device identity mappings.
///
/// Multi-process concurrency is achieved via SQLite Write-Ahead Logging (WAL mode)
/// and a 5,000ms busy timeout, allowing simultaneous read/write operations
/// across multiple Network Suite processes without database locks.
class SharedDeviceDatabase {
  static SharedDeviceDatabase? _instance;
  static SharedDeviceDatabase get instance => _instance ??= SharedDeviceDatabase();

  Database? _db;
  String? _databasePath;
  final StreamController<void> _changeController = StreamController<void>.broadcast();

  SharedDeviceDatabase({Database? customDb, String? customPath}) {
    if (customDb != null) {
      _db = customDb;
      _initSchema();
    } else if (customPath != null) {
      _databasePath = customPath;
    }
  }

  /// Whether the database is currently open and initialized.
  bool get isInitialized => _db != null;

  /// Absolute filesystem path to the current database file.
  String? get databasePath => _databasePath;

  /// Broadcast stream notifying listeners when devices are added, updated, or removed.
  Stream<void> get onDatabaseChanged => _changeController.stream;

  /// Resolves the canonical shared database directory based on the host operating system.
  static String getDefaultDirectoryPath() {
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'] ??
          p.join(Platform.environment['USERPROFILE'] ?? 'C:', 'AppData', 'Local');
      return p.join(localAppData, 'NetworkSuite');
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      return p.join(home, 'Library', 'Application Support', 'NetworkSuite');
    } else {
      // Linux and other POSIX
      final xdg = Platform.environment['XDG_DATA_HOME'];
      if (xdg != null && xdg.isNotEmpty) {
        return p.join(xdg, 'NetworkSuite');
      }
      final home = Platform.environment['HOME'] ?? '';
      return p.join(home, '.local', 'share', 'NetworkSuite');
    }
  }

  /// Resolves the default shared database file path.
  static String getDefaultDatabasePath() {
    return p.join(getDefaultDirectoryPath(), 'shared_devices.db');
  }

  /// Initializes the SQLite database.
  ///
  /// If [dbPath] is provided, it uses that path; otherwise it falls back
  /// to the standard cross-platform NetworkSuite directory.
  Future<void> init({String? dbPath}) async {
    if (_db != null) return;

    final targetPath = dbPath ?? _databasePath ?? getDefaultDatabasePath();
    _databasePath = targetPath;

    if (targetPath != ':memory:') {
      final dir = Directory(p.dirname(targetPath));
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
    }

    _db = targetPath == ':memory:' ? sqlite3.openInMemory() : sqlite3.open(targetPath);
    _initSchema();
  }

  void _initSchema() {
    final db = _db;
    if (db == null) return;

    // Enable WAL mode for safe multi-process concurrency
    try {
      db.execute('PRAGMA journal_mode = WAL;');
      db.execute('PRAGMA busy_timeout = 5000;');
      db.execute('PRAGMA synchronous = NORMAL;');
    } catch (_) {
      // In-memory or restricted environments may safely ignore WAL pragma errors
    }

    db.execute('''
      CREATE TABLE IF NOT EXISTS shared_devices (
        mac_address TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        vendor TEXT,
        device_type TEXT,
        notes TEXT,
        source_app TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE INDEX IF NOT EXISTS idx_shared_name ON shared_devices(name);
      CREATE INDEX IF NOT EXISTS idx_shared_vendor ON shared_devices(vendor);
      CREATE INDEX IF NOT EXISTS idx_shared_type ON shared_devices(device_type);

      CREATE TABLE IF NOT EXISTS custom_device_categories (
        id TEXT PRIMARY KEY NOT NULL,          -- Slug/key, e.g. "firewall", "smart_tv"
        label TEXT NOT NULL,                  -- Display name, e.g. "Firewall / UTM", "Smart TV"
        icon_name TEXT NOT NULL DEFAULT 'devices_other', -- Material icon identifier key
        color_hex TEXT,                       -- Optional accent color, e.g. "#FF5722"
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE INDEX IF NOT EXISTS idx_custom_category_label ON custom_device_categories(label);
    ''');
  }

  /// Retrieves a device by its MAC address.
  /// Returns `null` if the MAC is not present in the database.
  SharedDevice? getDeviceByMac(String mac) {
    final db = _db;
    if (db == null) return null;

    final normalized = SharedDevice.normalizeMac(mac);
    final rows = db.select(
      'SELECT * FROM shared_devices WHERE mac_address = ? LIMIT 1',
      [normalized],
    );

    if (rows.isEmpty) return null;
    return _rowToDevice(rows.first);
  }

  /// Retrieves all registered devices, with optional search query, category filtering,
  /// and option to hide devices that only have default MAC address labels.
  List<SharedDevice> getAllDevices({
    String? query,
    String? deviceType,
    String sortBy = 'updated_at',
    bool ascending = false,
    bool hideDefaultNamed = false,
  }) {
    final db = _db;
    if (db == null) return [];

    final conditions = <String>[];
    final params = <dynamic>[];

    if (query != null && query.trim().isNotEmpty) {
      final cleanQuery = '%${query.trim().toLowerCase()}%';
      conditions.add(
        '(LOWER(name) LIKE ? OR LOWER(mac_address) LIKE ? OR LOWER(vendor) LIKE ? OR LOWER(notes) LIKE ?)',
      );
      params.addAll([cleanQuery, cleanQuery, cleanQuery, cleanQuery]);
    }

    if (deviceType != null && deviceType.trim().isNotEmpty && deviceType != 'all') {
      conditions.add('device_type = ?');
      params.add(deviceType.trim().toLowerCase());
    }

    final whereClause = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final order = ascending ? 'ASC' : 'DESC';

    // Whitelist sort column to prevent SQL injection
    final validColumns = {
      'name': 'name',
      'mac': 'mac_address',
      'vendor': 'vendor',
      'type': 'device_type',
      'created_at': 'created_at',
      'updated_at': 'updated_at',
    };
    final sortCol = validColumns[sortBy] ?? 'updated_at';

    final rows = db.select(
      'SELECT * FROM shared_devices $whereClause ORDER BY $sortCol $order',
      params,
    );

    final devices = rows.map(_rowToDevice);
    if (hideDefaultNamed) {
      return devices.where((d) => d.hasCustomName).toList();
    }
    return devices.toList();
  }

  /// Inserts or updates a device record.
  void upsertDevice(SharedDevice device) {
    final db = _db;
    if (db == null) return;

    final normalizedMac = SharedDevice.normalizeMac(device.macAddress);
    final now = DateTime.now().toIso8601String();

    db.execute('''
      INSERT INTO shared_devices (
        mac_address, name, vendor, device_type, notes, source_app, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(mac_address) DO UPDATE SET
        name = excluded.name,
        vendor = COALESCE(excluded.vendor, shared_devices.vendor),
        device_type = COALESCE(excluded.device_type, shared_devices.device_type),
        notes = COALESCE(excluded.notes, shared_devices.notes),
        source_app = excluded.source_app,
        updated_at = excluded.updated_at
    ''', [
      normalizedMac,
      device.name.trim(),
      device.vendor?.trim(),
      device.deviceType?.trim(),
      device.notes?.trim(),
      device.sourceApp.trim(),
      device.createdAt.toIso8601String(),
      now,
    ]);

    notifyChanged();
  }

  /// Updates only the friendly name of a device identified by its MAC address.
  /// If the device does not exist, no action is taken.
  void updateDeviceName(String mac, String newName) {
    final db = _db;
    if (db == null) return;

    final normalizedMac = SharedDevice.normalizeMac(mac);
    final now = DateTime.now().toIso8601String();

    db.execute('''
      UPDATE shared_devices 
      SET name = ?, updated_at = ?
      WHERE mac_address = ?
    ''', [newName.trim(), now, normalizedMac]);

    notifyChanged();
  }

  /// Deletes a device from the database by MAC address.
  void deleteDevice(String mac) {
    final db = _db;
    if (db == null) return;

    final normalizedMac = SharedDevice.normalizeMac(mac);
    db.execute('DELETE FROM shared_devices WHERE mac_address = ?', [normalizedMac]);

    notifyChanged();
  }

  /// Updates device metadata (name, category/device_type, vendor, notes)
  /// for a device identified by its MAC address.
  ///
  /// Any parameter left `null` will keep its existing value unchanged.
  void updateDeviceDetails(
    String mac, {
    String? name,
    String? deviceType,
    String? vendor,
    String? notes,
  }) {
    final db = _db;
    if (db == null) return;

    final normalizedMac = SharedDevice.normalizeMac(mac);
    final now = DateTime.now().toIso8601String();

    final updates = <String>['updated_at = ?'];
    final params = <dynamic>[now];

    if (name != null) {
      updates.add('name = ?');
      params.add(name.trim());
    }
    if (deviceType != null) {
      updates.add('device_type = ?');
      params.add(deviceType.trim().toLowerCase());
    }
    if (vendor != null) {
      updates.add('vendor = ?');
      params.add(vendor.trim());
    }
    if (notes != null) {
      updates.add('notes = ?');
      params.add(notes.trim());
    }

    params.add(normalizedMac);

    db.execute('''
      UPDATE shared_devices
      SET ${updates.join(', ')}
      WHERE mac_address = ?
    ''', params);

    notifyChanged();
  }

  /// Retrieves all user-defined custom categories ordered alphabetically by label.
  List<CustomDeviceCategory> getCustomCategories() {
    final db = _db;
    if (db == null) return [];

    final rows = db.select(
      'SELECT * FROM custom_device_categories ORDER BY label ASC',
    );

    return rows.map((row) => CustomDeviceCategory.fromMap(row)).toList();
  }

  /// Retrieves a single custom category by its [id] slug, or `null` if not found.
  CustomDeviceCategory? getCustomCategoryById(String id) {
    final db = _db;
    if (db == null) return null;

    final rows = db.select(
      'SELECT * FROM custom_device_categories WHERE id = ? LIMIT 1',
      [id.trim().toLowerCase()],
    );

    if (rows.isEmpty) return null;
    return CustomDeviceCategory.fromMap(rows.first);
  }

  /// Inserts or replaces a user-defined custom category.
  void upsertCustomCategory(CustomDeviceCategory category) {
    final db = _db;
    if (db == null) return;

    final now = DateTime.now().toIso8601String();
    db.execute('''
      INSERT INTO custom_device_categories (
        id, label, icon_name, color_hex, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        label = excluded.label,
        icon_name = excluded.icon_name,
        color_hex = excluded.color_hex,
        updated_at = excluded.updated_at
    ''', [
      category.id.trim().toLowerCase(),
      category.label.trim(),
      category.iconName.trim(),
      category.colorHex?.trim(),
      category.createdAt.toIso8601String(),
      now,
    ]);

    notifyChanged();
  }

  /// Deletes a user-defined custom category by [id], updates any devices
  /// assigned to this category to have `device_type = 'other'`, and fires `notifyChanged()`.
  void deleteCustomCategory(String id) {
    final db = _db;
    if (db == null) return;

    final cleanId = id.trim().toLowerCase();
    final now = DateTime.now().toIso8601String();

    db.execute('BEGIN TRANSACTION;');
    try {
      db.execute(
        'DELETE FROM custom_device_categories WHERE id = ?',
        [cleanId],
      );
      db.execute(
        'UPDATE shared_devices SET device_type = ?, updated_at = ? WHERE LOWER(device_type) = ?',
        ['other', now, cleanId],
      );
      db.execute('COMMIT;');
    } catch (e) {
      db.execute('ROLLBACK;');
      rethrow;
    }

    notifyChanged();
  }

  /// Resolves the unified list of categories combining built-ins and custom categories.
  List<UnifiedDeviceCategory> getUnifiedCategories() {
    return UnifiedDeviceCategory.getAll(customCategories: getCustomCategories());
  }

  /// Returns the total count of registered devices.
  int getDeviceCount() {
    final db = _db;
    if (db == null) return 0;

    final result = db.select('SELECT COUNT(*) AS count FROM shared_devices');
    return (result.first['count'] as int?) ?? 0;
  }

  /// Imports a batch of devices inside a single transaction.
  void importBatch(List<SharedDevice> devices) {
    final db = _db;
    if (db == null || devices.isEmpty) return;

    db.execute('BEGIN TRANSACTION;');
    try {
      for (final device in devices) {
        upsertDevice(device);
      }
      db.execute('COMMIT;');
    } catch (e) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  void notifyChanged() {
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }

  SharedDevice _rowToDevice(Row row) {
    return SharedDevice(
      macAddress: row['mac_address'] as String,
      name: row['name'] as String,
      vendor: row['vendor'] as String?,
      deviceType: row['device_type'] as String?,
      notes: row['notes'] as String?,
      sourceApp: row['source_app'] as String,
      createdAt: DateTime.tryParse(row['created_at'] as String) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(row['updated_at'] as String) ?? DateTime.now(),
    );
  }

  /// Closes the database connection.
  void close() {
    _db?.close();
    _db = null;
    _changeController.close();
  }
}
