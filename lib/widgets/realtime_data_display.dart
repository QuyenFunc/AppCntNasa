import 'package:flutter/material.dart';
import 'dart:async';
import '../services/ntrip_client_service.dart';

class RealtimeDataDisplay extends StatefulWidget {
  const RealtimeDataDisplay({super.key});

  @override
  State<RealtimeDataDisplay> createState() => _RealtimeDataDisplayState();
}

class _RealtimeDataDisplayState extends State<RealtimeDataDisplay> {
  final NtripClientService _ntripService = NtripClientService();
  StreamSubscription<String>? _connectionStatusSubscription;
  StreamSubscription<Map<String, dynamic>>? _realtimeDataSubscription;
  
  String _connectionStatus = 'Disconnected';
  Map<String, dynamic>? _currentData;
  bool _isConnecting = false;
  bool _isRealtimeEnabled = true;

  @override
  void initState() {
    super.initState();
    _initializeStreams();
  }

  @override
  void dispose() {
    _connectionStatusSubscription?.cancel();
    _realtimeDataSubscription?.cancel();
    super.dispose();
  }

  void _initializeStreams() {
    // Listen to connection status
    _connectionStatusSubscription = _ntripService.connectionStatus.listen((status) {
      setState(() {
        _connectionStatus = status;
        _isConnecting = status.contains('Connecting');
      });
    });

    // Listen to real-time data
    _realtimeDataSubscription = _ntripService.realtimeData.listen((data) {
      if (_isRealtimeEnabled) {
        setState(() {
          _currentData = data;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(12), // Giảm từ 16 xuống 12
      child: Padding(
        padding: const EdgeInsets.all(12), // Giảm từ 16 xuống 12
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.satellite_alt,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Real-time GNSS Data',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16, // Giảm từ 18 xuống 16
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isRealtimeEnabled = !_isRealtimeEnabled;
                          if (!_isRealtimeEnabled) {
                            _currentData = null;
                          }
                        });
                      },
                      icon: Icon(
                        _isRealtimeEnabled ? Icons.pause_circle : Icons.play_circle,
                        color: _isRealtimeEnabled ? Colors.orange : Colors.green,
                      ),
                      tooltip: _isRealtimeEnabled ? 'Pause real-time data' : 'Resume real-time data',
                    ),
                    const SizedBox(width: 8),
                    _buildConnectionStatusIndicator(),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12), // Giảm từ 16 xuống 12
            
            // Connection Status
            _buildConnectionStatusCard(),
            
            const SizedBox(height: 12), // Giảm từ 16 xuống 12
            
            // Real-time Data Display
            if (!_isRealtimeEnabled) ...[
              _buildPausedMessage(),
            ] else if (_currentData != null) ...[
              _buildDataGrid(),
            ] else ...[
              _buildNoDataMessage(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusIndicator() {
    Color indicatorColor;
    IconData indicatorIcon;
    
    if (_isConnecting) {
      indicatorColor = Colors.orange;
      indicatorIcon = Icons.sync;
    } else if (_connectionStatus.contains('Connected')) {
      indicatorColor = Colors.green;
      indicatorIcon = Icons.check_circle;
    } else if (_connectionStatus.contains('Error') || _connectionStatus.contains('Failed')) {
      indicatorColor = Colors.red;
      indicatorIcon = Icons.error;
    } else {
      indicatorColor = Colors.grey;
      indicatorIcon = Icons.radio_button_unchecked;
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isConnecting) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
            ),
          ),
        ] else ...[
          Icon(
            indicatorIcon,
            color: indicatorColor,
            size: 16,
          ),
        ],
        const SizedBox(width: 4),
        Text(
          _connectionStatus,
          style: TextStyle(
            color: indicatorColor,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionStatusCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getStatusBackgroundColor(),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getStatusBorderColor()),
      ),
      child: Row(
        children: [
          Icon(
            _getStatusIcon(),
            color: _getStatusIconColor(),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connection Status',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _connectionStatus,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _getStatusIconColor(),
                  ),
                ),
              ],
            ),
          ),
          if (_currentData != null) ...[
            Text(
              'Last Update: ${_formatTimestamp(_currentData!['timestamp'])}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDataGrid() {
    final data = _currentData!;
    
    return Column(
      children: [
        // Position Data
        Row(
          children: [
            Expanded(
              child: _buildDataCard(
                'Latitude',
                '${data['latitude']?.toStringAsFixed(6) ?? 'N/A'}°',
                Icons.place,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDataCard(
                'Longitude',
                '${data['longitude']?.toStringAsFixed(6) ?? 'N/A'}°',
                Icons.place,
                Colors.blue,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Altitude and Accuracy
        Row(
          children: [
            Expanded(
              child: _buildDataCard(
                'Altitude',
                '${data['altitude']?.toStringAsFixed(1) ?? 'N/A'} m',
                Icons.terrain,
                Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDataCard(
                'Accuracy',
                '±${data['accuracy']?.toStringAsFixed(1) ?? 'N/A'} m',
                Icons.gps_fixed,
                Colors.orange,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Satellites and Messages
        Row(
          children: [
            Expanded(
              child: _buildDataCard(
                'Satellites',
                '${data['satelliteCount'] ?? 'N/A'}',
                Icons.satellite,
                Colors.purple,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDataCard(
                'Messages',
                '${data['messageCount'] ?? 'N/A'}',
                Icons.message,
                Colors.teal,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Mount Point Info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Icon(
                Icons.router,
                color: Colors.grey[600],
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Mount Point: ${data['mountPoint'] ?? 'Unknown'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDataCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10), // Giảm từ 12 xuống 10
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14, // Giảm từ 16 xuống 14
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPausedMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.pause_circle_outline,
            size: 48,
            color: Colors.orange[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Real-time data paused',
            style: TextStyle(
              fontSize: 16,
              color: Colors.orange[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Click the play button to resume real-time updates',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.satellite_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
              Text(
                'No real-time data available',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _connectionStatus.contains('Connected') 
                    ? 'Connected to NASA CDDIS - waiting for real RTCM data...'
                    : 'Need VALID JWT token from NASA Earthdata to access real CDDIS data',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
        ],
      ),
    );
  }

  Color _getStatusBackgroundColor() {
    if (_isConnecting) return Colors.orange[50]!;
    if (_connectionStatus.contains('Connected')) return Colors.green[50]!;
    if (_connectionStatus.contains('Error') || _connectionStatus.contains('Failed')) {
      return Colors.red[50]!;
    }
    return Colors.grey[50]!;
  }

  Color _getStatusBorderColor() {
    if (_isConnecting) return Colors.orange[300]!;
    if (_connectionStatus.contains('Connected')) return Colors.green[300]!;
    if (_connectionStatus.contains('Error') || _connectionStatus.contains('Failed')) {
      return Colors.red[300]!;
    }
    return Colors.grey[300]!;
  }

  Color _getStatusIconColor() {
    if (_isConnecting) return Colors.orange[700]!;
    if (_connectionStatus.contains('Connected')) return Colors.green[700]!;
    if (_connectionStatus.contains('Error') || _connectionStatus.contains('Failed')) {
      return Colors.red[700]!;
    }
    return Colors.grey[600]!;
  }

  IconData _getStatusIcon() {
    if (_isConnecting) return Icons.sync;
    if (_connectionStatus.contains('Connected')) return Icons.check_circle;
    if (_connectionStatus.contains('Error') || _connectionStatus.contains('Failed')) {
      return Icons.error;
    }
    return Icons.radio_button_unchecked;
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Never';
    
    try {
      final DateTime dateTime;
      if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else if (timestamp is DateTime) {
        dateTime = timestamp;
      } else {
        return 'Invalid';
      }
      
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inSeconds < 60) {
        return '${difference.inSeconds}s ago';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else {
        return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return 'Error';
    }
  }
}
