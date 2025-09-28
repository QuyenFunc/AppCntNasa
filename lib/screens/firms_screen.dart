import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/firms_fire_data.dart';
import '../services/firms_service.dart';

class FirmsScreen extends StatefulWidget {
  const FirmsScreen({super.key});

  @override
  State<FirmsScreen> createState() => _FirmsScreenState();
}

class _FirmsScreenState extends State<FirmsScreen>
    with TickerProviderStateMixin {
  final FirmsService _firmsService = FirmsService();
  final MapController _mapController = MapController();
  
  List<FirmsFireData> _fireData = [];
  bool _isLoading = true;
  String _selectedSource = 'VIIRS_SNPP_NRT';
  int _dayRange = 1;
  Map<String, dynamic> _statistics = {};
  
  late AnimationController _filterPanelController;
  late Animation<double> _filterPanelAnimation;
  bool _isFilterPanelVisible = false;
  bool _hideInfoPanel = false; // Ẩn info panel khi filter mở
  
  // Search functionality
  final TextEditingController _locationSearchController = TextEditingController();
  List<Map<String, dynamic>> _searchSuggestions = [];
  bool _isSearching = false;
  
  // Performance settings
  bool _limitMarkers = true; // Mặc định giới hạn markers để performance tốt
  bool _showAllFires = false; // Toggle để hiển thị tất cả fires

  final List<String> _availableSources = [
    'VIIRS_SNPP_NRT',
    'VIIRS_NOAA20_NRT',
    'MODIS_NRT',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadFireData();
  }

  void _initializeAnimations() {
    _filterPanelController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _filterPanelAnimation = CurvedAnimation(
      parent: _filterPanelController,
      curve: Curves.easeInOut,
    );
  }

  Future<void> _loadFireData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final fires = await _firmsService.getActiveFires(
        source: _selectedSource,
        dayRange: _dayRange,
      );
      
      final stats = await _firmsService.getFireStatistics(
        minLat: -90,
        maxLat: 90,
        minLon: -180,
        maxLon: 180,
        dayRange: _dayRange,
      );

      setState(() {
        _fireData = fires;
        _statistics = stats;
        _isLoading = false;
      });

      debugPrint('[FIRMS UI] 🔥 Loaded ${fires.length} fires into UI');
      
      // Debug first few fires for UI
      if (fires.isNotEmpty) {
        for (int i = 0; i < fires.length.clamp(0, 2); i++) {
          final f = fires[i];
          debugPrint('[FIRMS UI] Fire $i will be at LatLng(${f.latitude}, ${f.longitude})');
        }
        _fitMapToFires(fires);
      } else {
        debugPrint('[FIRMS UI] ⚠️ No fires to display - trying different data source...');
        // Try different data source automatically
        if (_selectedSource == 'VIIRS_SNPP_NRT') {
          debugPrint('[FIRMS UI] 🔄 Switching to MODIS_NRT...');
          setState(() {
            _selectedSource = 'MODIS_NRT';
          });
          _loadFireData(); // Retry with different source
        } else if (_selectedSource == 'MODIS_NRT') {
          debugPrint('[FIRMS UI] 🔄 Switching to VIIRS_NOAA20_NRT...');
          setState(() {
            _selectedSource = 'VIIRS_NOAA20_NRT';
          });
          _loadFireData(); // Retry with different source
        } else {
          // All sources tried, show message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Không có dữ liệu cháy rừng thật. Có thể thử lại sau...'),
                backgroundColor: Colors.orange,
                action: SnackBarAction(
                  label: 'Thử lại',
                  onPressed: () {
                    setState(() {
                      _selectedSource = 'VIIRS_SNPP_NRT'; // Reset to default
                    });
                    _loadFireData();
                  },
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading fire data: $e')),
        );
      }
    }
  }

  void _fitMapToFires(List<FirmsFireData> fires) {
    if (fires.isEmpty) return;
    
    try {
      double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
      for (final f in fires) {
        if (f.latitude < minLat) minLat = f.latitude;
        if (f.latitude > maxLat) maxLat = f.latitude;
        if (f.longitude < minLon) minLon = f.longitude;
        if (f.longitude > maxLon) maxLon = f.longitude;
      }

      debugPrint('[FIRMS UI] 📍 Fire bounds: lat=$minLat to $maxLat, lon=$minLon to $maxLon');

      // Fit map to fire bounds
      try {
        final bounds = LatLngBounds(
          LatLng(minLat, minLon),
          LatLng(maxLat, maxLon),
        );

        _mapController.fitCamera(CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(32),
        ));
        
        debugPrint('[FIRMS UI] 🗺️ Map fitted to fire bounds');
      } catch (e) {
        debugPrint('[FIRMS UI] ⏳ MapController not ready, skipping fit bounds');
        // Delay fitting until map is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _fitMapToFires(fires);
        });
      }
    } catch (e) {
      debugPrint('[FIRMS UI] ❌ Error fitting map: $e');
    }
  }

  void _toggleFilterPanel() {
    setState(() {
      _isFilterPanelVisible = !_isFilterPanelVisible;
      _hideInfoPanel = _isFilterPanelVisible; // Ẩn info panel khi filter mở
    });
    if (_isFilterPanelVisible) {
      _filterPanelController.forward();
    } else {
      _filterPanelController.reverse();
    }
  }

  Color _getFireColor(FirmsFireData fire) {
    switch (fire.intensity) {
      case FireIntensity.extreme:
        return Colors.red.shade800;
      case FireIntensity.high:
        return Colors.red.shade600;
      case FireIntensity.moderate:
        return Colors.orange.shade600;
      case FireIntensity.low:
        return Colors.yellow.shade600;
      case FireIntensity.unknown:
        return Colors.grey.shade600;
    }
  }

  double _getFireSize(FirmsFireData fire) {
    switch (fire.intensity) {
      case FireIntensity.extreme:
        return 3.0; // Giảm thêm từ 4.0
      case FireIntensity.high:
        return 2.5; // Giảm thêm từ 3.5
      case FireIntensity.moderate:
        return 2.0; // Giảm thêm từ 3.0
      case FireIntensity.low:
        return 1.5; // Giảm thêm từ 2.5
      case FireIntensity.unknown:
        return 1.0; // Giảm thêm từ 2.0
    }
  }

  // PERFORMANCE OPTIMIZATION: Tối ưu markers với tùy chọn hiển thị tất cả
  List<Marker> _getOptimizedFireMarkers() {
    // Get current zoom level safely
    double currentZoom = 2.0; // Default zoom
    try {
      currentZoom = _mapController.camera.zoom;
    } catch (e) {
      // MapController chưa sẵn sàng, sử dụng default zoom
      debugPrint('[FIRMS] MapController not ready, using default zoom: $currentZoom');
    }
    
    List<FirmsFireData> firesToShow;
    
    if (_showAllFires || !_limitMarkers) {
      // Hiển thị TẤT CẢ fires - có thể lag với số lượng lớn
      firesToShow = _fireData;
      debugPrint('[FIRMS] 🔥 Showing ALL ${_fireData.length} fires (may cause lag)');
    } else {
      // Giới hạn số markers dựa trên zoom level để tối ưu performance
      int maxMarkers;
      if (currentZoom < 3) {
        maxMarkers = 200; // Tăng lên từ 100
      } else if (currentZoom < 6) {
        maxMarkers = 800; // Tăng lên từ 500
      } else {
        maxMarkers = 2000; // Tăng lên từ 1000
      }

      // Ưu tiên hiển thị fires có confidence cao và intensity lớn
      final sortedFires = List<FirmsFireData>.from(_fireData)
        ..sort((a, b) {
          // Sort theo intensity trước, confidence sau
          final intensityCompare = _getIntensityPriority(b.intensity)
              .compareTo(_getIntensityPriority(a.intensity));
          if (intensityCompare != 0) return intensityCompare;
          
          return _getConfidencePriority(b.confidenceLevel)
              .compareTo(_getConfidencePriority(a.confidenceLevel));
        });

      // Lấy top markers theo priority
      firesToShow = sortedFires.take(maxMarkers).toList();
      debugPrint('[FIRMS] 🔥 Showing top $maxMarkers/${_fireData.length} fires (zoom: ${currentZoom.toStringAsFixed(1)})');
    }

    return firesToShow.map((fire) => Marker(
      point: LatLng(fire.latitude, fire.longitude),
      width: _getFireSize(fire),
      height: _getFireSize(fire),
      child: GestureDetector(
        onTap: () => _showFireDetails(fire),
        child: Container(
          decoration: BoxDecoration(
            color: _getFireColor(fire),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 0.5, // Giảm từ 1 xuống 0.5
            ),
          ),
          child: const Icon(
            Icons.local_fire_department,
            color: Colors.white,
            size: 2, // Giảm thêm từ 3 xuống 2
          ),
        ),
      ),
    )).toList();
  }

  int _getIntensityPriority(FireIntensity intensity) {
    switch (intensity) {
      case FireIntensity.extreme: return 4;
      case FireIntensity.high: return 3;
      case FireIntensity.moderate: return 2;
      case FireIntensity.low: return 1;
      case FireIntensity.unknown: return 0;
    }
  }

  int _getConfidencePriority(FireConfidence confidence) {
    switch (confidence) {
      case FireConfidence.high: return 3;
      case FireConfidence.nominal: return 2;
      case FireConfidence.low: return 1;
      case FireConfidence.unknown: return 0;
    }
  }

  int _getDisplayedFireCount() {
    if (_showAllFires || !_limitMarkers) {
      return _fireData.length;
    }
    
    // Tính toán số markers sẽ hiển thị dựa trên zoom level
    double currentZoom = 2.0;
    try {
      currentZoom = _mapController.camera.zoom;
    } catch (e) {
      // MapController chưa sẵn sàng
    }
    
    int maxMarkers;
    if (currentZoom < 3) {
      maxMarkers = 200;
    } else if (currentZoom < 6) {
      maxMarkers = 800;
    } else {
      maxMarkers = 2000;
    }
    
    return maxMarkers.clamp(0, _fireData.length);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NASA FIRMS',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showLocationSearch,
            tooltip: 'Search Location',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _toggleFilterPanel,
            tooltip: 'Filter Options',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'statistics':
                  _showStatistics();
                  break;
                case 'api_info':
                  _showApiInfo();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'statistics',
                child: ListTile(
                  leading: Icon(Icons.bar_chart),
                  title: Text('Statistics'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'api_info',
                child: ListTile(
                  leading: Icon(Icons.api),
                  title: Text('API Info'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(0, 0),
              initialZoom: 2.0,
              minZoom: 1.0,
              maxZoom: 18.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // Base map
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.nasa_gnss_client',
                maxZoom: 19,
              ),
              // Optimized Fire markers với performance improvements
              MarkerLayer(
                // PERFORMANCE OPTIMIZATION: Giới hạn số markers hiển thị
                markers: _getOptimizedFireMarkers(),
              ),
            ],
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.red,
                ),
              ),
            ),

          // Filter panel với drag handle
          AnimatedBuilder(
            animation: _filterPanelAnimation,
            builder: (context, child) {
              return Positioned(
                top: 0,
                right: -300 + (300 * _filterPanelAnimation.value),
                width: 300,
                height: MediaQuery.of(context).size.height,
                child: Material(
                  elevation: 8,
                  child: Container(
                    color: theme.scaffoldBackgroundColor,
                    child: Column(
                      children: [
                        // Drag handle
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          color: Colors.red.shade700,
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        
                        // Panel header
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          color: Colors.red.shade700,
                          child: Row(
                            children: [
                              const Icon(Icons.filter_list, color: Colors.white),
                              const SizedBox(width: 8),
                              const Text(
                                'Fire Data Filters',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: _toggleFilterPanel,
                              ),
                            ],
                          ),
                        ),

                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Data source selector
                                const Text(
                                  'Data Source',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: _selectedSource,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _availableSources.map((source) {
                                    return DropdownMenuItem(
                                      value: source,
                                      child: Text(_getSourceDisplayName(source)),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedSource = value;
                                      });
                                    }
                                  },
                                ),

                                const SizedBox(height: 24),

                                // Day range selector
                                Text(
                                  'Time Range: $_dayRange day${_dayRange > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Slider(
                                  value: _dayRange.toDouble(),
                                  min: 1,
                                  max: 10,
                                  divisions: 9,
                                  label: '$_dayRange day${_dayRange > 1 ? 's' : ''}',
                                  onChanged: (value) {
                                    setState(() {
                                      _dayRange = value.round();
                                    });
                                  },
                                ),

                                const SizedBox(height: 24),

                                // Performance Settings
                                const Text(
                                  'Hiển Thị Markers',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                
                                // Show All Fires Toggle
                                SwitchListTile(
                                  title: const Text('Hiển thị tất cả đám cháy'),
                                  subtitle: Text(
                                    _showAllFires 
                                      ? 'Hiển thị ${_fireData.length} đám cháy (có thể lag)'
                                      : 'Chỉ hiển thị đám cháy ưu tiên (tối ưu performance)',
                                  ),
                                  value: _showAllFires,
                                  onChanged: (value) {
                                    setState(() {
                                      _showAllFires = value;
                                    });
                                  },
                                  secondary: Icon(
                                    _showAllFires ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                
                                const SizedBox(height: 8),
                                
                                // Performance Warning
                                if (_showAllFires && _fireData.length > 5000)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Cảnh báo: Hiển thị ${_fireData.length} markers có thể làm lag app.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                const SizedBox(height: 24),

                                // Apply button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade700,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      _loadFireData();
                                      _toggleFilterPanel(); // Sẽ đóng filter và hiện lại info panel
                                    },
                                    child: const Text('Apply Filters'),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Legend
                                const Text(
                                  'Fire Intensity Legend',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildLegendItem('Extreme', Colors.red.shade800),
                                _buildLegendItem('High', Colors.red.shade600),
                                _buildLegendItem('Moderate', Colors.orange.shade600),
                                _buildLegendItem('Low', Colors.yellow.shade600),
                                _buildLegendItem('Unknown', Colors.grey.shade600),
                                
                                // Thêm khoảng trống để tránh bị che bởi bottom
                                const SizedBox(height: 150), // Tăng từ 100 lên 150
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Map controls (giống WorldView)
          Positioned(
            top: 16,
            left: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  onPressed: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, zoom + 1);
                  },
                  child: const Icon(Icons.zoom_in),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  onPressed: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, zoom - 1);
                  },
                  child: const Icon(Icons.zoom_out),
                ),
              ],
            ),
          ),

          // Info panel (ẩn khi filter panel mở)
          if (!_hideInfoPanel)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.shade50,
                      Colors.white,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildInfoItem(
                            'Đám Cháy', 
                            _showAllFires 
                              ? '${_fireData.length}' 
                              : '${_getDisplayedFireCount()}/${_fireData.length}', 
                            Icons.local_fire_department
                          ),
                          _buildInfoItem('Độ Tin Cậy Cao', '${_statistics['high_confidence'] ?? 0}', Icons.verified),
                          _buildInfoItem('Nguồn Dữ Liệu', _getSourceDisplayName(_selectedSource), Icons.satellite),
                        ],
                      ),
                      if (_fireData.isEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Không có dữ liệu cháy. Thử thay đổi nguồn dữ liệu hoặc khoảng thời gian.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.red.shade700),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _getSourceDisplayName(String source) {
    switch (source) {
      case 'VIIRS_SNPP_NRT':
        return 'VIIRS SNPP';
      case 'VIIRS_NOAA20_NRT':
        return 'VIIRS NOAA-20';
      case 'MODIS_NRT':
        return 'MODIS Near Real-Time';
      default:
        return source;
    }
  }

  void _showFireDetails(FirmsFireData fire) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getFireColor(fire),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text(
                      'Fire Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildDetailRow('Location', '${fire.latitude.toStringAsFixed(4)}, ${fire.longitude.toStringAsFixed(4)}'),
                    _buildDetailRow('Acquisition Date', '${fire.acqDate.year}-${fire.acqDate.month.toString().padLeft(2, '0')}-${fire.acqDate.day.toString().padLeft(2, '0')}'),
                    _buildDetailRow('Acquisition Time', fire.acqTime),
                    _buildDetailRow('Satellite', fire.satellite),
                    _buildDetailRow('Instrument', fire.instrument),
                    _buildDetailRow('Confidence', fire.confidence),
                    if (fire.brightness != null)
                      _buildDetailRow('Brightness (K)', fire.brightness!.toStringAsFixed(1)),
                    if (fire.frp != null)
                      _buildDetailRow('Fire Radiative Power (MW)', fire.frp!.toStringAsFixed(1)),
                    if (fire.scan != null)
                      _buildDetailRow('Scan Size (km)', fire.scan!),
                    if (fire.track != null)
                      _buildDetailRow('Track Size (km)', fire.track!),
                    _buildDetailRow('Intensity', fire.intensity.name.toUpperCase()),
                    _buildDetailRow('Day/Night', fire.daynight ?? 'Unknown'),
                    _buildDetailRow('Version', fire.version),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showStatistics() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bar_chart, color: Colors.red),
            SizedBox(width: 8),
            Text('Fire Statistics'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow('Total Fires', '${_statistics['total_fires'] ?? 0}'),
              _buildStatRow('High Confidence', '${_statistics['high_confidence'] ?? 0}'),
              _buildStatRow('Moderate Confidence', '${_statistics['moderate_confidence'] ?? 0}'),
              _buildStatRow('Low Confidence', '${_statistics['low_confidence'] ?? 0}'),
              const Divider(),
              _buildStatRow('Extreme Intensity', '${_statistics['extreme_intensity'] ?? 0}'),
              _buildStatRow('High Intensity', '${_statistics['high_intensity'] ?? 0}'),
              _buildStatRow('Moderate Intensity', '${_statistics['moderate_intensity'] ?? 0}'),
              _buildStatRow('Low Intensity', '${_statistics['low_intensity'] ?? 0}'),
              const Divider(),
              _buildStatRow('Avg Brightness (K)', '${(_statistics['avg_brightness'] ?? 0).toStringAsFixed(1)}'),
              _buildStatRow('Avg FRP (MW)', '${(_statistics['avg_frp'] ?? 0).toStringAsFixed(1)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showApiInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.api, color: Colors.red),
            SizedBox(width: 8),
            Text('FIRMS API Status'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text('API Key: Active'),
              ],
            ),
            SizedBox(height: 8),
            Text('Using NASA FIRMS API with registered key'),
            SizedBox(height: 8),
            Text('Key: d8abbd...c226cc7c', 
                 style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
            SizedBox(height: 12),
            Text('Features:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• Real-time fire detection'),
            Text('• Global coverage'),
            Text('• Multiple satellite sources'),
            Text('• Custom date ranges (1-10 days)'),
            Text('• Geographic filtering'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLocationSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.search, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Tìm Kiếm Địa Điểm Cháy',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Search input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _locationSearchController,
                  decoration: InputDecoration(
                    hintText: 'Nhập tên thành phố, quốc gia...',
                    prefixIcon: const Icon(Icons.location_on),
                    suffixIcon: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _locationSearchController.clear();
                              setState(() {
                                _searchSuggestions = [];
                              });
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  onChanged: _onSearchTextChanged,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Quick locations for fire-prone areas
              if (_searchSuggestions.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Khu vực thường xảy ra cháy',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _getFireProneLocations()
                        .map((location) => _buildLocationTile(location))
                        .toList(),
                  ),
                ),
              ] else ...[
                // Search results
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Kết quả tìm kiếm',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _searchSuggestions.length,
                    itemBuilder: (context, index) {
                      return _buildLocationTile(_searchSuggestions[index]);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationTile(Map<String, dynamic> location) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.withOpacity(0.1),
          child: Icon(
            location['type'] == 'fire_area' ? Icons.local_fire_department : Icons.place,
            color: Colors.red.shade700,
          ),
        ),
        title: Text(
          location['name'],
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(location['country'] ?? ''),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          _navigateToLocation(location['lat'], location['lng']);
          Navigator.pop(context);
        },
      ),
    );
  }

  List<Map<String, dynamic>> _getFireProneLocations() {
    return [
      {
        'name': 'Amazon Rainforest, Brazil',
        'country': 'Brazil',
        'lat': -3.4653,
        'lng': -62.2159,
        'type': 'fire_area'
      },
      {
        'name': 'California, USA',
        'country': 'United States',
        'lat': 36.7783,
        'lng': -119.4179,
        'type': 'fire_area'
      },
      {
        'name': 'Australia Bushfire Areas',
        'country': 'Australia',
        'lat': -25.2744,
        'lng': 133.7751,
        'type': 'fire_area'
      },
      {
        'name': 'Siberia, Russia',
        'country': 'Russia',
        'lat': 60.0000,
        'lng': 105.0000,
        'type': 'fire_area'
      },
      {
        'name': 'Central Africa',
        'country': 'Democratic Republic of Congo',
        'lat': -4.0383,
        'lng': 21.7587,
        'type': 'fire_area'
      },
      {
        'name': 'Indonesia Forest Fires',
        'country': 'Indonesia',
        'lat': -0.7893,
        'lng': 113.9213,
        'type': 'fire_area'
      },
      {
        'name': 'Mediterranean Region',
        'country': 'Greece/Turkey',
        'lat': 39.0742,
        'lng': 21.8243,
        'type': 'fire_area'
      },
      {
        'name': 'Canadian Boreal Forest',
        'country': 'Canada',
        'lat': 54.0000,
        'lng': -105.0000,
        'type': 'fire_area'
      },
    ];
  }

  void _onSearchTextChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    // Simulate API search with debouncing
    Timer(const Duration(milliseconds: 500), () {
      if (_locationSearchController.text == query) {
        _performLocationSearch(query);
      }
    });
  }

  void _performLocationSearch(String query) {
    final results = <Map<String, dynamic>>[];
    final fireProneLocations = _getFireProneLocations();
    
    for (final location in fireProneLocations) {
      if (location['name'].toLowerCase().contains(query.toLowerCase()) ||
          (location['country']?.toLowerCase().contains(query.toLowerCase()) ?? false)) {
        results.add(location);
      }
    }

    // Add some additional search results based on query
    if (query.toLowerCase().contains('vietnam') || query.toLowerCase().contains('việt nam')) {
      results.addAll([
        {
          'name': 'Miền Trung Việt Nam',
          'country': 'Việt Nam',
          'lat': 16.0544,
          'lng': 108.2022,
          'type': 'fire_area'
        },
        {
          'name': 'Tây Nguyên Việt Nam',
          'country': 'Việt Nam',
          'lat': 12.5000,
          'lng': 108.0000,
          'type': 'fire_area'
        },
      ]);
    }

    setState(() {
      _searchSuggestions = results;
      _isSearching = false;
    });
  }

  void _navigateToLocation(double lat, double lng) {
    _mapController.move(LatLng(lat, lng), 6.0);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã chuyển đến khu vực: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red.shade700,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  void dispose() {
    _filterPanelController.dispose();
    _locationSearchController.dispose();
    super.dispose();
  }
}
