import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/gnss_station.dart';
import '../providers/gnss_provider.dart';
import '../widgets/station_info_popup.dart';
import '../widgets/map_controls.dart';
import '../widgets/realtime_data_display.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  OverlayEntry? _popupOverlay;

  // Map settings
  double _currentZoom = 3.0;
  LatLng _currentCenter = const LatLng(0, 0); // World center
  bool _showAccuracyCircles = true;
  bool _showOnlyInaccurate = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _removePopup();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final gnssProvider = Provider.of<GnssProvider>(context, listen: false);
    await gnssProvider.fetchStations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<GnssProvider>(
        builder: (context, gnssProvider, child) {
          return Stack(
            children: [
              // Main map
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentCenter,
                  initialZoom: _currentZoom,
                  minZoom: 1.0,
                  maxZoom: 18.0,
                  onTap: (tapPosition, point) => _removePopup(),
                  onPositionChanged: (position, hasGesture) {
                    if (hasGesture) {
                      _currentCenter = position.center!;
                      _currentZoom = position.zoom!;
                    }
                  },
                ),
                children: [
                  // Tile layer (OpenStreetMap)
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.nasa.gnss_client',
                    maxZoom: 18,
                  ),
                  
                  // Accuracy circles layer (if enabled)
                  if (_showAccuracyCircles) 
                    CircleLayer(
                      circles: _buildAccuracyCircles(gnssProvider.stations),
                    ),
                  
                  // Markers layer
                  MarkerLayer(
                    markers: _buildMarkers(gnssProvider.stations),
                  ),
                ],
              ),

              // Loading overlay
              if (gnssProvider.isLoading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),

              // Map controls
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: MapControls(
                  onZoomIn: () => _mapController.move(_currentCenter, _currentZoom + 1),
                  onZoomOut: () => _mapController.move(_currentCenter, _currentZoom - 1),
                  onCenterOnUser: _centerOnUserLocation,
                  onToggleAccuracyCircles: () {
                    setState(() {
                      _showAccuracyCircles = !_showAccuracyCircles;
                    });
                  },
                  onToggleInaccurateOnly: () {
                    setState(() {
                      _showOnlyInaccurate = !_showOnlyInaccurate;
                    });
                  },
                  showAccuracyCircles: _showAccuracyCircles,
                  showOnlyInaccurate: _showOnlyInaccurate,
                ),
              ),

              // Floating action button for refresh
              Positioned(
                bottom: 100,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton(
                      heroTag: "refresh",
                      onPressed: () => _refreshData(gnssProvider),
                      child: gnssProvider.isRefreshing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: "center_all",
                      onPressed: () => _centerOnAllStations(gnssProvider.stations),
                      child: const Icon(Icons.center_focus_strong),
                    ),
                  ],
                ),
              ),

              // Real-time data display
              Positioned(
                bottom: 80,
                left: 16,
                right: 90, // Leave space for FABs
                child: const RealtimeDataDisplay(),
              ),

              // Station count info
              Positioned(
                bottom: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Stations: ${gnssProvider.totalStations}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Accurate: ${gnssProvider.accurateStations}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'Inaccurate: ${gnssProvider.inaccurateStations}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Error message
              if (gnssProvider.errorMessage != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 80,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            gnssProvider.errorMessage!,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        IconButton(
                          onPressed: () => gnssProvider.clearSelection(),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Marker> _buildMarkers(List<GnssStation> stations) {
    final filteredStations = _showOnlyInaccurate 
        ? stations.where((station) => !station.isAccurate).toList()
        : stations;

    return filteredStations.map((station) {
      return Marker(
        point: LatLng(station.latitude, station.longitude),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showStationPopup(station),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: station.isAccurate ? Colors.green : Colors.red,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.satellite_alt,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  List<CircleMarker> _buildAccuracyCircles(List<GnssStation> stations) {
    final filteredStations = _showOnlyInaccurate 
        ? stations.where((station) => !station.isAccurate).toList()
        : stations;

    return filteredStations.map((station) {
      // Convert accuracy from meters to approximate degrees
      // This is a rough approximation for visualization
      final radiusInDegrees = station.accuracy / 111000; // 1 degree ≈ 111km

      return CircleMarker(
        point: LatLng(station.latitude, station.longitude),
        radius: radiusInDegrees * 1000, // Scale for visibility
        color: (station.isAccurate ? Colors.green : Colors.red).withOpacity(0.2),
        borderColor: station.isAccurate ? Colors.green : Colors.red,
        borderStrokeWidth: 1,
      );
    }).toList();
  }

  void _showStationPopup(GnssStation station) {
    _removePopup();
    
    _popupOverlay = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 120,
        left: 16,
        right: 16,
        child: StationInfoPopup(
          station: station,
          onClose: _removePopup,
          onViewDetails: () => _viewStationDetails(station),
          onCenterOnStation: () => _centerOnStation(station),
        ),
      ),
    );
    
    Overlay.of(context).insert(_popupOverlay!);
  }

  void _removePopup() {
    _popupOverlay?.remove();
    _popupOverlay = null;
  }

  void _viewStationDetails(GnssStation station) {
    _removePopup();
    // Navigate to station details screen
    Navigator.pushNamed(
      context, 
      '/station-details',
      arguments: station,
    );
  }

  void _centerOnStation(GnssStation station) {
    _mapController.move(
      LatLng(station.latitude, station.longitude),
      15.0,
    );
  }

  void _centerOnAllStations(List<GnssStation> stations) {
    if (stations.isEmpty) return;

    // Calculate bounds for all stations
    double minLat = stations.first.latitude;
    double maxLat = stations.first.latitude;
    double minLon = stations.first.longitude;
    double maxLon = stations.first.longitude;

    for (final station in stations) {
      minLat = minLat < station.latitude ? minLat : station.latitude;
      maxLat = maxLat > station.latitude ? maxLat : station.latitude;
      minLon = minLon < station.longitude ? minLon : station.longitude;
      maxLon = maxLon > station.longitude ? maxLon : station.longitude;
    }

    // Add padding
    const padding = 1.0; // degrees
    minLat -= padding;
    maxLat += padding;
    minLon -= padding;
    maxLon += padding;

    // Calculate center and zoom
    final centerLat = (minLat + maxLat) / 2;
    final centerLon = (minLon + maxLon) / 2;
    final center = LatLng(centerLat, centerLon);

    // Calculate appropriate zoom level
    final latDiff = maxLat - minLat;
    final lonDiff = maxLon - minLon;
    final maxDiff = latDiff > lonDiff ? latDiff : lonDiff;
    
    double zoom = 10.0;
    if (maxDiff > 50) zoom = 3.0;
    else if (maxDiff > 20) zoom = 5.0;
    else if (maxDiff > 10) zoom = 6.0;
    else if (maxDiff > 5) zoom = 7.0;
    else if (maxDiff > 2) zoom = 8.0;

    _mapController.move(center, zoom);
  }

  Future<void> _centerOnUserLocation() async {
    // This would typically use location services
    // For now, we'll center on a default location (NASA JPL)
    const jplLocation = LatLng(34.2048, -118.1717);
    _mapController.move(jplLocation, 10.0);
    
    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Centered on NASA JPL location'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _refreshData(GnssProvider gnssProvider) async {
    await gnssProvider.refreshStations();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated ${gnssProvider.totalStations} stations'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
