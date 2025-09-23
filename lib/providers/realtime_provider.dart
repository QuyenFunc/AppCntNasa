import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/ntrip_client.dart';
import '../widgets/gnss_map_widget.dart';

class RealtimeProvider with ChangeNotifier {
  // Connection state
  bool _isConnected = false;
  bool _isConnecting = false;
  String _connectionStatus = 'Disconnected';
  
  // NTRIP client
  NtripClient? _ntripClient;
  
  // Stream data
  Map<String, dynamic> _streamStats = {};
  List<GnssStationMarker> _stations = [];
  List<String> _logEntries = [];
  
  // Charts data
  List<ChartDataPoint> _bitrateHistory = [];
  List<ChartDataPoint> _frameHistory = [];
  Map<int, int> _messageTypeStats = {};
  
  // Getters
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String get connectionStatus => _connectionStatus;
  Map<String, dynamic> get streamStats => _streamStats;
  List<GnssStationMarker> get stations => _stations;
  List<String> get logEntries => _logEntries;
  List<ChartDataPoint> get bitrateHistory => _bitrateHistory;
  List<ChartDataPoint> get frameHistory => _frameHistory;
  Map<int, int> get messageTypeStats => _messageTypeStats;

  // Connect to NTRIP caster
  Future<void> connect({
    required String host,
    required int port,
    required String mountpoint,
    required String username,
    required String password,
  }) async {
    if (_isConnecting) {
      print('⚠️ Already connecting, please wait...');
      return;
    }
    
    if (_isConnected) {
      print('⚠️ Already connected! Please disconnect first before connecting to a new station.');
      throw Exception('Already connected. Please disconnect first.');
    }

    print('🔗 Starting NTRIP connection to $host:$port/$mountpoint');
    _isConnecting = true;
    _connectionStatus = 'Connecting...';
    notifyListeners();

    try {
      _ntripClient = NtripClient(
        host: host,
        port: port,
        mountPoint: mountpoint,
        username: username,
        password: password,
        useTls: port == 443,
      );

      print('📡 Attempting NTRIP connection...');
      
      // Set up error handling BEFORE connecting
      bool connectionSuccessful = false;
      
      _ntripClient!.statsStream.listen(
        (stats) {
          // Only update stats if connection was successful
          if (_isConnected) {
            _updateStreamStats(stats);
          }
        },
        onError: (error) {
          print('❌ NTRIP connection error: $error');
          _isConnected = false;
          _isConnecting = false;

          final errorText = error.toString();
          if (errorText.contains('401')) {
            _connectionStatus = 'Authentication failed: Invalid username/password or no access to mountpoint';
          } else if (errorText.contains('404')) {
            _connectionStatus = 'Mountpoint not found: Check mountpoint name';
          } else if (errorText.contains('403')) {
            _connectionStatus = 'Access forbidden: Account may not have permission';
          } else if (errorText.toLowerCase().contains('timeout')) {
            _connectionStatus = 'Connection timeout: Check host/port and network';
          } else {
            _connectionStatus = 'Connection failed: ${errorText.replaceAll('Exception: ', '')}';
          }

          print('📊 Connection status updated: $_connectionStatus');
          notifyListeners();
        },
        onDone: () {
          if (_isConnected) {
            _isConnected = false;
            _connectionStatus = 'Disconnected by server';
            notifyListeners();
          }
        },
      );

      // Listen to raw data stream (only process if connected)
      _ntripClient!.rawDataStream.listen(
        (data) {
          if (_isConnected) {
            _updateStationFromRtcmData(data, mountpoint);
          }
        },
        onError: (_) {
          // No-op: statsStream already reports connection errors
        },
      );

      // Now attempt connection
      await _ntripClient!.connect();
      
      // Wait a bit to see if we get an error
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Only set connected if no error occurred
      if (_ntripClient!.isConnected && !connectionSuccessful) {
        _isConnected = true;
        _isConnecting = false;
        _connectionStatus = 'Connected';
        connectionSuccessful = true;
        print('✅ NTRIP connection established!');
        print('🎉 NTRIP connection successful! Status: $_connectionStatus');
        notifyListeners();
      }

    } catch (e) {
      print('💥 NTRIP connection exception: $e');
      _isConnected = false;
      _isConnecting = false;
      
      // Provide user-friendly error messages
      if (e.toString().contains('401')) {
        _connectionStatus = 'Authentication failed: Invalid username/password or no access to mountpoint';
      } else if (e.toString().contains('404')) {
        _connectionStatus = 'Mountpoint not found: Check mountpoint name';
      } else if (e.toString().contains('403')) {
        _connectionStatus = 'Access forbidden: Account may not have permission';
      } else if (e.toString().contains('timeout')) {
        _connectionStatus = 'Connection timeout: Check host/port and network';
      } else {
        _connectionStatus = 'Connection failed: ${e.toString().replaceAll('Exception: ', '')}';
      }
      
      notifyListeners();
      // Rethrow to let UI handle the error
      rethrow;
    }
  }

  // Disconnect from NTRIP caster
  Future<void> disconnect() async {
    await _ntripClient?.close();
    _ntripClient = null;
    
    _isConnected = false;
    _isConnecting = false;
    _connectionStatus = 'Disconnected';
    _streamStats.clear();
    _stations.clear();
    _logEntries.clear();
    _bitrateHistory.clear();
    _frameHistory.clear();
    _messageTypeStats.clear();
    
    notifyListeners();
  }

  // Update stream statistics
  void _updateStreamStats(NtripStats stats) {
    _streamStats = {
      'frames': stats.frames,
      'bytes': stats.bytes,
      'bitrateKbps': stats.bitrateKbps.toStringAsFixed(2),
      'messageCount': stats.msgCount.length,
      'summary': stats.summary,
    };

    // Add log entry
    final logEntry = '${DateTime.now().toIso8601String()}: '
        'Frames: ${stats.frames}, Bytes: ${stats.bytes}, '
        'Rate: ${stats.bitrateKbps.toStringAsFixed(2)} kbps';
    _logEntries.add(logEntry);

    // Keep only last 100 entries
    if (_logEntries.length > 100) {
      _logEntries.removeAt(0);
    }

    // Update charts data
    final now = DateTime.now();
    _bitrateHistory.add(ChartDataPoint(now, stats.bitrateKbps));
    _frameHistory.add(ChartDataPoint(now, stats.frames.toDouble()));

    // Keep only last 100 points
    if (_bitrateHistory.length > 100) {
      _bitrateHistory.removeAt(0);
    }
    if (_frameHistory.length > 100) {
      _frameHistory.removeAt(0);
    }

    // Update message type statistics
    _messageTypeStats = Map.from(stats.msgCount);

    _connectionStatus = 'Connected - Streaming';
    notifyListeners();
  }

  // Update station position from RTCM data
  void _updateStationFromRtcmData(List<int> data, String mountpoint) {
    // Mock station position update based on RTCM data
    final now = DateTime.now();
    
    // Generate realistic coordinates based on mountpoint
    Map<String, List<double>> regions = {
      'BCEP00BKG0': [28.5, -80.6], // Kennedy Space Center
      'BCEP00GMV0': [40.59, -3.71], // Madrid, Spain  
      'BCEP01BKG0': [50.09, 8.66], // Frankfurt, Germany
      'BCEP01JPL0': [34.20, -118.17], // JPL, California
    };
    
    final coords = regions[mountpoint] ?? [39.0, -77.0]; // Default to DC
    final lat = coords[0] + (now.second % 10 - 5) * 0.001; // Small variation
    final lon = coords[1] + (now.second % 10 - 5) * 0.001;
    
    final station = GnssStationMarker(
      id: mountpoint,
      name: 'GNSS Station $mountpoint',
      latitude: lat,
      longitude: lon,
      status: StationStatus.streaming,
      metadata: _streamStats,
    );
    
    _stations = [station]; // For now, show one station
    notifyListeners();
  }

  // Export log to file
  Future<void> exportLog() async {
    if (_logEntries.isEmpty) {
      throw Exception('No log data to export');
    }

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = 'ntrip_log_$timestamp.txt';
    final file = File('${directory.path}/$fileName');
    
    final logContent = [
      'NTRIP Connection Log',
      'Generated: ${DateTime.now()}',
      'Connection Status: $_connectionStatus',
      '=' * 50,
      ..._logEntries,
    ].join('\n');
    
    await file.writeAsString(logContent);
    
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'NTRIP connection log export',
    );
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

class ChartDataPoint {
  final DateTime timestamp;
  final double value;

  ChartDataPoint(this.timestamp, this.value);
}
