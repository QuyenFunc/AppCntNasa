import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class GnssMapWidget extends StatefulWidget {
  final List<GnssStationMarker> stations;
  final Function(GnssStationMarker)? onStationTap;

  const GnssMapWidget({
    super.key,
    required this.stations,
    this.onStationTap,
  });

  @override
  State<GnssMapWidget> createState() => _GnssMapWidgetState();
}

class _GnssMapWidgetState extends State<GnssMapWidget> {
  final MapController _mapController = MapController();
  
  @override
  void didUpdateWidget(GnssMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Auto-zoom to new stations when they appear
    if (widget.stations.isNotEmpty && oldWidget.stations.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _zoomToStations();
      });
    }
  }
  
  void _zoomToStations() {
    if (widget.stations.isEmpty) return;
    
    if (widget.stations.length == 1) {
      // For single station, zoom to it directly
      final station = widget.stations.first;
      _mapController.move(
        LatLng(station.latitude, station.longitude),
        12.0, // Good zoom level for single station
      );
    } else {
      // For multiple stations, fit all in view
      double minLat = widget.stations.first.latitude;
      double maxLat = widget.stations.first.latitude;
      double minLng = widget.stations.first.longitude;
      double maxLng = widget.stations.first.longitude;
      
      for (final station in widget.stations) {
        minLat = minLat < station.latitude ? minLat : station.latitude;
        maxLat = maxLat > station.latitude ? maxLat : station.latitude;
        minLng = minLng < station.longitude ? minLng : station.longitude;
        maxLng = maxLng > station.longitude ? maxLng : station.longitude;
      }
      
      final bounds = LatLngBounds(
        LatLng(minLat, minLng),
        LatLng(maxLat, maxLng),
      );
      
      _mapController.fitBounds(bounds, options: const FitBoundsOptions(
        padding: EdgeInsets.all(50),
      ));
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: LatLng(39.0, -77.0), // Washington DC area (NASA Goddard)
        initialZoom: 6.0,
        minZoom: 2.0,
        maxZoom: 18.0,
      ),
      children: [
        // OpenStreetMap tile layer
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.nasa.gnss_client',
          maxNativeZoom: 19,
        ),
        
        // GNSS station markers
        MarkerLayer(
          markers: widget.stations.map((station) {
            return Marker(
              point: LatLng(station.latitude, station.longitude),
              width: 50,
              height: 50,
              child: GestureDetector(
                onTap: () => widget.onStationTap?.call(station),
                child: _buildStationMarker(station),
              ),
            );
          }).toList(),
        ),
        
        // Attribution
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              'OpenStreetMap contributors',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStationMarker(GnssStationMarker station) {
    final color = _getStationColor(station.status);
    
    if (station.status == StationStatus.streaming) {
      // Animated marker for streaming stations
      return TweenAnimationBuilder<double>(
        duration: const Duration(seconds: 2),
        tween: Tween(begin: 0.0, end: 1.0),
        onEnd: () {
          // Trigger rebuild to restart animation
          if (mounted) {
            setState(() {});
          }
        },
        builder: (context, value, child) {
          final pulseScale = 1.0 + (0.3 * value);
          final opacity = 1.0 - value * 0.7;
          
          return Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing ring effect
              Transform.scale(
                scale: pulseScale,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withOpacity(opacity),
                      width: 2,
                    ),
                  ),
                ),
              ),
              // Main marker
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.satellite_alt,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              // Real-time indicator dot
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
              ),
            ],
          );
        },
      );
    } else {
      // Static marker for non-streaming stations
      return Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.satellite_alt,
          size: 18,
          color: Colors.white,
        ),
      );
    }
  }

  Color _getStationColor(StationStatus status) {
    switch (status) {
      case StationStatus.active:
        return Colors.green;
      case StationStatus.streaming:
        return Colors.blue;
      case StationStatus.warning:
        return Colors.orange;
      case StationStatus.error:
        return Colors.red;
      case StationStatus.offline:
        return Colors.grey;
    }
  }
}

class GnssStationMarker {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final StationStatus status;
  final Map<String, dynamic>? metadata;

  const GnssStationMarker({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.metadata,
  });

  factory GnssStationMarker.fromRtcmData(Map<String, dynamic> data) {
    return GnssStationMarker(
      id: data['stationId'] ?? 'unknown',
      name: data['mountPoint'] ?? 'Unknown Station',
      latitude: data['latitude'] ?? 0.0,
      longitude: data['longitude'] ?? 0.0,
      status: StationStatus.streaming,
      metadata: data,
    );
  }
}

enum StationStatus {
  active,
  streaming,
  warning,
  error,
  offline,
}

class StationInfoPopup extends StatelessWidget {
  final GnssStationMarker station;
  final VoidCallback onClose;

  const StationInfoPopup({
    super.key,
    required this.station,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  station.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoRow('ID', station.id),
            _buildInfoRow('Latitude', station.latitude.toStringAsFixed(6)),
            _buildInfoRow('Longitude', station.longitude.toStringAsFixed(6)),
            _buildInfoRow('Status', _getStatusText(station.status)),
            if (station.metadata != null) ...[
              const SizedBox(height: 8),
              const Divider(),
              const Text(
                'Stream Data:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              if (station.metadata!['bitrateKbps'] != null)
                _buildInfoRow('Bitrate', '${station.metadata!['bitrateKbps']} kbps'),
              if (station.metadata!['frames'] != null)
                _buildInfoRow('Frames', '${station.metadata!['frames']}'),
              if (station.metadata!['messageCount'] != null)
                _buildInfoRow('Messages', '${station.metadata!['messageCount']}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(StationStatus status) {
    switch (status) {
      case StationStatus.active:
        return 'Active';
      case StationStatus.streaming:
        return 'Streaming';
      case StationStatus.warning:
        return 'Warning';
      case StationStatus.error:
        return 'Error';
      case StationStatus.offline:
        return 'Offline';
    }
  }
}
