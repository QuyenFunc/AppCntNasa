import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/gnss_station.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;
  Box<GnssStation>? _stationsBox;
  Box<AccuracyDataPoint>? _accuracyBox;

  // Initialize both SQLite and Hive
  Future<void> initialize() async {
    await _initializeHive();
    await _initializeSQLite();
  }

  // Initialize Hive for caching
  Future<void> _initializeHive() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(GnssStationAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AccuracyDataPointAdapter());
    }

    await Hive.initFlutter();
    
    _stationsBox = await Hive.openBox<GnssStation>('gnss_stations');
    _accuracyBox = await Hive.openBox<AccuracyDataPoint>('accuracy_data');
  }

  // Initialize SQLite for persistent storage
  Future<void> _initializeSQLite() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'gnss_database.db');
    
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // GNSS Stations table
    await db.execute('''
      CREATE TABLE gnss_stations (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy REAL NOT NULL,
        updated_at TEXT NOT NULL,
        elevation REAL,
        satellite_count INTEGER,
        signal_strength REAL,
        status TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Accuracy history table
    await db.execute('''
      CREATE TABLE accuracy_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        station_id TEXT NOT NULL,
        accuracy REAL NOT NULL,
        timestamp TEXT NOT NULL,
        signal_strength REAL,
        FOREIGN KEY (station_id) REFERENCES gnss_stations (id)
      )
    ''');

    // Export logs table
    await db.execute('''
      CREATE TABLE export_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        export_type TEXT NOT NULL,
        file_path TEXT NOT NULL,
        station_count INTEGER NOT NULL,
        timestamp TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // User preferences table
    await db.execute('''
      CREATE TABLE user_preferences (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_station_updated ON gnss_stations(updated_at)');
    await db.execute('CREATE INDEX idx_accuracy_station_time ON accuracy_history(station_id, timestamp)');
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades if needed
    if (oldVersion < newVersion) {
      debugPrint('Upgrading database from version $oldVersion to $newVersion');
      // Add upgrade logic here when needed
    }
  }

  // GNSS Stations operations
  Future<void> saveStation(GnssStation station) async {
    if (_database == null) await initialize();
    
    // Save to SQLite
    await _database!.insert(
      'gnss_stations',
      {
        'id': station.id,
        'name': station.name,
        'latitude': station.latitude,
        'longitude': station.longitude,
        'accuracy': station.accuracy,
        'updated_at': station.updatedAt.toIso8601String(),
        'elevation': station.elevation,
        'satellite_count': station.satelliteCount,
        'signal_strength': station.signalStrength,
        'status': station.status,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Save to Hive cache
    await _stationsBox?.put(station.id, station);

    // Save accuracy data point
    final accuracyPoint = AccuracyDataPoint.fromStation(station);
    await saveAccuracyDataPoint(accuracyPoint);
  }

  Future<void> saveStations(List<GnssStation> stations) async {
    if (_database == null) await initialize();
    
    final batch = _database!.batch();
    
    for (final station in stations) {
      batch.insert(
        'gnss_stations',
        {
          'id': station.id,
          'name': station.name,
          'latitude': station.latitude,
          'longitude': station.longitude,
          'accuracy': station.accuracy,
          'updated_at': station.updatedAt.toIso8601String(),
          'elevation': station.elevation,
          'satellite_count': station.satelliteCount,
          'signal_strength': station.signalStrength,
          'status': station.status,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);

    // Save to Hive cache
    final stationsMap = {for (var station in stations) station.id: station};
    await _stationsBox?.putAll(stationsMap);
  }

  Future<List<GnssStation>> getAllStations() async {
    if (_database == null) await initialize();
    
    final List<Map<String, dynamic>> maps = await _database!.query(
      'gnss_stations',
      orderBy: 'updated_at DESC',
    );

    return maps.map((map) => _stationFromMap(map)).toList();
  }

  Future<GnssStation?> getStationById(String stationId) async {
    if (_database == null) await initialize();
    
    // Try Hive cache first
    final cachedStation = _stationsBox?.get(stationId);
    if (cachedStation != null) {
      return cachedStation;
    }

    // Fallback to SQLite
    final List<Map<String, dynamic>> maps = await _database!.query(
      'gnss_stations',
      where: 'id = ?',
      whereArgs: [stationId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      final station = _stationFromMap(maps.first);
      // Cache in Hive
      await _stationsBox?.put(stationId, station);
      return station;
    }

    return null;
  }

  Future<List<GnssStation>> getStationsInRegion({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) async {
    if (_database == null) await initialize();
    
    final List<Map<String, dynamic>> maps = await _database!.query(
      'gnss_stations',
      where: 'latitude BETWEEN ? AND ? AND longitude BETWEEN ? AND ?',
      whereArgs: [minLat, maxLat, minLon, maxLon],
      orderBy: 'updated_at DESC',
    );

    return maps.map((map) => _stationFromMap(map)).toList();
  }

  // Accuracy data operations
  Future<void> saveAccuracyDataPoint(AccuracyDataPoint dataPoint) async {
    if (_database == null) await initialize();
    
    await _database!.insert(
      'accuracy_history',
      {
        'station_id': dataPoint.stationId,
        'accuracy': dataPoint.accuracy,
        'timestamp': dataPoint.timestamp.toIso8601String(),
        'signal_strength': dataPoint.signalStrength,
      },
    );

    // Save to Hive
    final key = '${dataPoint.stationId}_${dataPoint.timestamp.millisecondsSinceEpoch}';
    await _accuracyBox?.put(key, dataPoint);
  }

  Future<List<AccuracyDataPoint>> getAccuracyHistory(
    String stationId, {
    DateTime? startTime,
    DateTime? endTime,
    int? limit,
  }) async {
    if (_database == null) await initialize();
    
    String whereClause = 'station_id = ?';
    List<dynamic> whereArgs = [stationId];
    
    if (startTime != null) {
      whereClause += ' AND timestamp >= ?';
      whereArgs.add(startTime.toIso8601String());
    }
    
    if (endTime != null) {
      whereClause += ' AND timestamp <= ?';
      whereArgs.add(endTime.toIso8601String());
    }

    final List<Map<String, dynamic>> maps = await _database!.query(
      'accuracy_history',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return maps.map((map) => AccuracyDataPoint(
      stationId: map['station_id'],
      accuracy: map['accuracy'],
      timestamp: DateTime.parse(map['timestamp']),
      signalStrength: map['signal_strength'],
    )).toList();
  }

  // User preferences
  Future<void> savePreference(String key, String value) async {
    if (_database == null) await initialize();
    
    await _database!.insert(
      'user_preferences',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getPreference(String key) async {
    if (_database == null) await initialize();
    
    final List<Map<String, dynamic>> maps = await _database!.query(
      'user_preferences',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    return maps.isNotEmpty ? maps.first['value'] : null;
  }

  // Export logging
  Future<void> logExport(String exportType, String filePath, int stationCount) async {
    if (_database == null) await initialize();
    
    await _database!.insert('export_logs', {
      'export_type': exportType,
      'file_path': filePath,
      'station_count': stationCount,
    });
  }

  Future<List<Map<String, dynamic>>> getExportHistory() async {
    if (_database == null) await initialize();
    
    return await _database!.query(
      'export_logs',
      orderBy: 'timestamp DESC',
      limit: 50,
    );
  }

  // Maintenance operations
  Future<void> clearOldData({int daysToKeep = 30}) async {
    if (_database == null) await initialize();
    
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    
    await _database!.delete(
      'accuracy_history',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  Future<void> clearAllData() async {
    if (_database == null) await initialize();
    
    await _database!.delete('gnss_stations');
    await _database!.delete('accuracy_history');
    await _stationsBox?.clear();
    await _accuracyBox?.clear();
  }

  Future<Map<String, int>> getDatabaseStats() async {
    if (_database == null) await initialize();
    
    final stationCount = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(*) FROM gnss_stations')
    ) ?? 0;
    
    final accuracyCount = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(*) FROM accuracy_history')
    ) ?? 0;
    
    return {
      'stations': stationCount,
      'accuracy_points': accuracyCount,
      'hive_stations': _stationsBox?.length ?? 0,
      'hive_accuracy': _accuracyBox?.length ?? 0,
    };
  }

  // Helper method to convert map to GnssStation
  GnssStation _stationFromMap(Map<String, dynamic> map) {
    return GnssStation(
      id: map['id'],
      name: map['name'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      accuracy: map['accuracy'],
      updatedAt: DateTime.parse(map['updated_at']),
      elevation: map['elevation'],
      satelliteCount: map['satellite_count'],
      signalStrength: map['signal_strength'],
      status: map['status'],
    );
  }

  // Dispose resources
  Future<void> dispose() async {
    await _database?.close();
    await _stationsBox?.close();
    await _accuracyBox?.close();
  }
}
