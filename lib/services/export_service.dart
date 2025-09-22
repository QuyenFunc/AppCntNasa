import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/gnss_station.dart';
import 'database_service.dart';
import 'notification_service.dart';

// Export formats enum
enum ExportFormat { csv, json, txt }

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  // Export formats

  // Export GNSS stations to CSV
  Future<String?> exportStationsToCSV(
    List<GnssStation> stations, {
    String? customFileName,
    bool includeAccuracyHistory = false,
  }) async {
    try {
      if (stations.isEmpty) {
        throw Exception('No stations to export');
      }

      // Request storage permission
      if (!await _requestStoragePermission()) {
        throw Exception('Storage permission denied');
      }

      final fileName = customFileName ?? 
          'gnss_stations_${DateTime.now().millisecondsSinceEpoch}.csv';
      
      final file = await _getExportFile(fileName);

      // Prepare CSV data
      final csvData = <List<dynamic>>[];
      
      // Header row
      csvData.add([
        'Station ID',
        'Station Name',
        'Latitude',
        'Longitude',
        'Accuracy (m)',
        'Last Updated',
        'Elevation (m)',
        'Satellite Count',
        'Signal Strength (dB)',
        'Status',
      ]);

      // Data rows
      for (final station in stations) {
        csvData.add([
          station.id,
          station.name,
          station.latitude,
          station.longitude,
          station.accuracy,
          station.updatedAt.toIso8601String(),
          station.elevation ?? 'N/A',
          station.satelliteCount ?? 'N/A',
          station.signalStrength ?? 'N/A',
          station.statusDisplay,
        ]);
      }

      // Include accuracy history if requested
      if (includeAccuracyHistory) {
        csvData.add([]); // Empty row separator
        csvData.add(['Accuracy History']);
        csvData.add(['Station ID', 'Accuracy (m)', 'Timestamp', 'Signal Strength (dB)']);
        
        for (final station in stations) {
          final history = await _databaseService.getAccuracyHistory(
            station.id,
            limit: 100, // Last 100 readings
          );
          
          for (final point in history) {
            csvData.add([
              point.stationId,
              point.accuracy,
              point.timestamp.toIso8601String(),
              point.signalStrength ?? 'N/A',
            ]);
          }
        }
      }

      // Convert to CSV string
      final csvString = const ListToCsvConverter().convert(csvData);
      
      // Write to file
      await file.writeAsString(csvString);

      // Log export
      await _databaseService.logExport('CSV', file.path, stations.length);

      // Show notification
      await _notificationService.showExportCompletionNotification(
        'CSV', 
        fileName,
      );

      debugPrint('CSV export completed: ${file.path}');
      return file.path;

    } catch (e) {
      debugPrint('CSV export error: $e');
      rethrow;
    }
  }

  // Export GNSS stations to JSON
  Future<String?> exportStationsToJSON(
    List<GnssStation> stations, {
    String? customFileName,
    bool includeAccuracyHistory = false,
    bool prettyPrint = true,
  }) async {
    try {
      if (stations.isEmpty) {
        throw Exception('No stations to export');
      }

      if (!await _requestStoragePermission()) {
        throw Exception('Storage permission denied');
      }

      final fileName = customFileName ?? 
          'gnss_stations_${DateTime.now().millisecondsSinceEpoch}.json';
      
      final file = await _getExportFile(fileName);

      // Prepare JSON data
      final exportData = <String, dynamic>{
        'export_info': {
          'timestamp': DateTime.now().toIso8601String(),
          'station_count': stations.length,
          'format_version': '1.0',
          'includes_history': includeAccuracyHistory,
        },
        'stations': stations.map((station) => station.toJson()).toList(),
      };

      // Include accuracy history if requested
      if (includeAccuracyHistory) {
        final historyData = <String, List<Map<String, dynamic>>>{};
        
        for (final station in stations) {
          final history = await _databaseService.getAccuracyHistory(
            station.id,
            limit: 100,
          );
          
          historyData[station.id] = history
              .map((point) => point.toJson())
              .toList();
        }
        
        exportData['accuracy_history'] = historyData;
      }

      // Convert to JSON string
      final jsonString = prettyPrint 
          ? const JsonEncoder.withIndent('  ').convert(exportData)
          : jsonEncode(exportData);
      
      // Write to file
      await file.writeAsString(jsonString);

      // Log export
      await _databaseService.logExport('JSON', file.path, stations.length);

      // Show notification
      await _notificationService.showExportCompletionNotification(
        'JSON', 
        fileName,
      );

      debugPrint('JSON export completed: ${file.path}');
      return file.path;

    } catch (e) {
      debugPrint('JSON export error: $e');
      rethrow;
    }
  }

  // Export GNSS stations to text format
  Future<String?> exportStationsToText(
    List<GnssStation> stations, {
    String? customFileName,
    bool includeAccuracyHistory = false,
  }) async {
    try {
      if (stations.isEmpty) {
        throw Exception('No stations to export');
      }

      if (!await _requestStoragePermission()) {
        throw Exception('Storage permission denied');
      }

      final fileName = customFileName ?? 
          'gnss_stations_${DateTime.now().millisecondsSinceEpoch}.txt';
      
      final file = await _getExportFile(fileName);

      final buffer = StringBuffer();
      
      // Header
      buffer.writeln('NASA GNSS Stations Export');
      buffer.writeln('Generated: ${DateTime.now().toString()}');
      buffer.writeln('Total Stations: ${stations.length}');
      buffer.writeln('=' * 60);
      buffer.writeln();

      // Station data
      for (int i = 0; i < stations.length; i++) {
        final station = stations[i];
        
        buffer.writeln('Station ${i + 1}/${stations.length}');
        buffer.writeln('ID: ${station.id}');
        buffer.writeln('Name: ${station.name}');
        buffer.writeln('Coordinates: ${station.coordinatesString}');
        buffer.writeln('Accuracy: ${station.accuracyString}');
        buffer.writeln('Last Updated: ${station.updatedAt}');
        
        if (station.elevation != null) {
          buffer.writeln('Elevation: ${station.elevation!.toStringAsFixed(2)}m');
        }
        
        if (station.satelliteCount != null) {
          buffer.writeln('Satellites: ${station.satelliteCount}');
        }
        
        if (station.signalStrength != null) {
          buffer.writeln('Signal Strength: ${station.signalStrength!.toStringAsFixed(2)} dB');
        }
        
        buffer.writeln('Status: ${station.statusDisplay}');
        buffer.writeln('Accuracy OK: ${station.isAccurate ? 'Yes' : 'No'}');
        
        // Include accuracy history if requested
        if (includeAccuracyHistory) {
          final history = await _databaseService.getAccuracyHistory(
            station.id,
            limit: 10, // Last 10 readings for text format
          );
          
          if (history.isNotEmpty) {
            buffer.writeln('\nRecent Accuracy History:');
            for (final point in history) {
              buffer.writeln('  ${point.timestamp}: ${point.accuracy.toStringAsFixed(2)}m');
            }
          }
        }
        
        buffer.writeln('-' * 40);
        buffer.writeln();
      }

      // Write to file
      await file.writeAsString(buffer.toString());

      // Log export
      await _databaseService.logExport('TXT', file.path, stations.length);

      // Show notification
      await _notificationService.showExportCompletionNotification(
        'Text', 
        fileName,
      );

      debugPrint('Text export completed: ${file.path}');
      return file.path;

    } catch (e) {
      debugPrint('Text export error: $e');
      rethrow;
    }
  }

  // Share exported file
  Future<void> shareExportedFile(String filePath, {String? subject}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Export file not found');
      }

      final fileName = file.path.split('/').last;
      final shareSubject = subject ?? 'NASA GNSS Stations Data - $fileName';

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: shareSubject,
        text: 'NASA GNSS Stations data export',
      );

      debugPrint('File shared: $filePath');

    } catch (e) {
      debugPrint('Share error: $e');
      rethrow;
    }
  }

  // Export with multiple formats
  Future<Map<String, String?>> exportMultipleFormats(
    List<GnssStation> stations, {
    Set<ExportFormat> formats = const {ExportFormat.csv, ExportFormat.json},
    bool includeAccuracyHistory = false,
  }) async {
    final results = <String, String?>{};
    
    for (final format in formats) {
      try {
        switch (format) {
          case ExportFormat.csv:
            results['csv'] = await exportStationsToCSV(
              stations,
              includeAccuracyHistory: includeAccuracyHistory,
            );
            break;
          case ExportFormat.json:
            results['json'] = await exportStationsToJSON(
              stations,
              includeAccuracyHistory: includeAccuracyHistory,
            );
            break;
          case ExportFormat.txt:
            results['txt'] = await exportStationsToText(
              stations,
              includeAccuracyHistory: includeAccuracyHistory,
            );
            break;
        }
      } catch (e) {
        results[format.name] = null;
        debugPrint('Failed to export ${format.name}: $e');
      }
    }
    
    return results;
  }

  // Get export history
  Future<List<Map<String, dynamic>>> getExportHistory() async {
    return await _databaseService.getExportHistory();
  }

  // Helper methods
  Future<File> _getExportFile(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${directory.path}/gnss_exports');
    
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    
    return File('${exportDir.path}/$fileName');
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (status != PermissionStatus.granted) {
        // Try external storage permission for Android 11+
        final externalStatus = await Permission.manageExternalStorage.request();
        return externalStatus == PermissionStatus.granted;
      }
      return true;
    }
    return true; // iOS doesn't need explicit permission for app documents
  }

  // Get available export formats
  List<String> getAvailableFormats() {
    return ExportFormat.values.map((format) => format.name.toUpperCase()).toList();
  }

  // Validate export data
  bool validateExportData(List<GnssStation> stations) {
    if (stations.isEmpty) return false;
    
    // Check if all stations have required data
    return stations.every((station) => 
        station.id.isNotEmpty &&
        station.name.isNotEmpty &&
        station.latitude.isFinite &&
        station.longitude.isFinite &&
        station.accuracy.isFinite
    );
  }

  // Get export directory path
  Future<String> getExportDirectoryPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/gnss_exports';
  }

  // Clean old export files
  Future<void> cleanOldExports({int daysToKeep = 7}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${directory.path}/gnss_exports');
      
      if (!await exportDir.exists()) return;
      
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final files = await exportDir.list().toList();
      
      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await file.delete();
            debugPrint('Deleted old export file: ${file.path}');
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning old exports: $e');
    }
  }
}
