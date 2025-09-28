import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/worldview_layer.dart';
import '../services/worldview_service.dart';
import '../providers/theme_provider.dart';

class WorldviewScreen extends StatefulWidget {
  const WorldviewScreen({super.key});

  @override
  State<WorldviewScreen> createState() => _WorldviewScreenState();
}

class _WorldviewScreenState extends State<WorldviewScreen>
    with TickerProviderStateMixin {
  final WorldviewService _worldviewService = WorldviewService();
  final MapController _mapController = MapController();
  
  List<WorldviewLayer> _availableLayers = [];
  List<WorldviewLayer> _activeLayers = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now().subtract(const Duration(days: 1)); // Default to yesterday for real-time data availability
  
  late AnimationController _layerPanelController;
  late Animation<double> _layerPanelAnimation;
  bool _isLayerPanelVisible = false;
  
  Timer? _dateChangeTimer;
  
  // Search functionality
  final TextEditingController _locationSearchController = TextEditingController();
  List<Map<String, dynamic>> _searchSuggestions = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadAvailableLayers();
  }

  void _initializeAnimations() {
    _layerPanelController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _layerPanelAnimation = CurvedAnimation(
      parent: _layerPanelController,
      curve: Curves.easeInOut,
    );
  }

  Future<void> _loadAvailableLayers() async {
    try {
      final layers = await _worldviewService.getAvailableLayers();
      setState(() {
        _availableLayers = layers;
        if (layers.isNotEmpty) {
          _activeLayers = [];
          // TỰ ĐỘNG LOAD VIIRS LAYER THAY VÌ TERRA
          final viirsLayer = layers.firstWhere(
            (l) => l.id.contains('VIIRS_SNPP_CorrectedReflectance_TrueColor'),
            orElse: () => layers.firstWhere(
              (l) => l.id.contains('MODIS_Terra_CorrectedReflectance_TrueColor'),
              orElse: () => layers.first,
            ),
          );
          _activeLayers.add(viirsLayer);
          debugPrint('[Worldview] 🛰️ Auto-loaded VIIRS SNPP TrueColor layer (best working layer)');
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading layers: $e')),
        );
      }
    }
  }

  void _toggleLayerPanel() {
    setState(() {
      _isLayerPanelVisible = !_isLayerPanelVisible;
    });
    if (_isLayerPanelVisible) {
      _layerPanelController.forward();
    } else {
      _layerPanelController.reverse();
    }
  }

  void _toggleLayer(WorldviewLayer layer) {
    setState(() {
      if (_activeLayers.contains(layer)) {
        _activeLayers.remove(layer);
      } else {
        _activeLayers.add(layer);
      }
    });
  }

  void _updateLayerOpacity(WorldviewLayer layer, double opacity) {
    setState(() {
      final index = _activeLayers.indexOf(layer);
      if (index != -1) {
        _activeLayers[index] = layer.copyWith(opacity: opacity);
      }
    });
  }

  List<WorldviewLayer> get _filteredLayers {
    return _availableLayers;
  }

  /// Build correct URL template for flutter_map
  String _buildTileUrlTemplate(WorldviewLayer layer) {
    // SỬ DỤNG REAL-TIME DATE (ngày được chọn hoặc ngày hiện tại)
    final dateString = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final extension = layer.format == 'image/png' ? 'png' : 'jpg';
    final url = '${layer.baseUrl}/${layer.id}/default/$dateString/${layer.tileMatrixSet}/{z}/{y}/{x}.$extension';
    debugPrint('[Worldview] 🌍 Real-time URL Template: $url (Date: $dateString)');
    return url;
  }

  int _failedTileCount = 0;
  bool _showErrorIndicator = false;

  void _handleTileError() {
    _failedTileCount++;
    if (_failedTileCount > 5) {
      setState(() => _showErrorIndicator = true);
      _tryFallbackDate();
    }
  }

  void _tryFallbackDate() {
    final fallbackDate = _selectedDate.subtract(const Duration(days: 3));
    debugPrint('[Worldview] 📅 Trying fallback date: $fallbackDate');
    setState(() {
      _selectedDate = fallbackDate;
      _failedTileCount = 0;
      _showErrorIndicator = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NASA Worldview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: themeProvider.primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showLocationSearch,
            tooltip: 'Search Location',
          ),
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: _toggleLayerPanel,
            tooltip: 'Layer Control',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Pure Satellite Map - No base layer needed
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(20.0, 0.0), // Start at more interesting location
              initialZoom: 2.0, // Lower start for better overview
              minZoom: 0.0, // Match GoogleMapsCompatible_Level9
              maxZoom: 9.0, // Strict limit for GoogleMapsCompatible_Level9
              crs: const Epsg3857(), // Web Mercator projection
              backgroundColor: const Color(0xFF0a0a0a), // Dark space background
              // Add bounds constraint for better UX
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  const LatLng(-85.0, -180.0),
                  const LatLng(85.0, 180.0),
                ),
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // Optimized Worldview satellite layers với performance improvements
              ..._activeLayers.map((layer) {
                return TileLayer(
                  // Tile configuration
                  tms: false,
                  urlTemplate: _buildTileUrlTemplate(layer),
                  userAgentPackageName: 'com.nasagnss.worldview',
                  
                  // Zoom limits - FIXED: Chỉ một maxNativeZoom
                  maxZoom: 9,
                  maxNativeZoom: 8, // Giới hạn native zoom để tránh quá tải
                  minZoom: 1,
                  
                  // PERFORMANCE OPTIMIZATIONS
                  // Giảm animation duration để responsive hơn
                  tileDisplay: TileDisplay.fadeIn(duration: const Duration(milliseconds: 100)),
                  
                  // Tăng buffer để load trước tiles
                  keepBuffer: 3,
                  
                  // Tile bounds để tránh load tiles không cần thiết
                  tileBounds: LatLngBounds(
                    const LatLng(-85.0, -180.0),
                    const LatLng(85.0, 180.0),
                  ),
                  
                  // Optimized error handling
                  errorTileCallback: (tile, error, stackTrace) {
                    // Chỉ log error trong debug mode
                    if (kDebugMode) {
                      debugPrint('🔴 Tile error for ${layer.id}: $error');
                    }
                    _handleTileError();
                  },
                  
                  // Tile loading optimization
                  backgroundColor: Colors.transparent,
                );
              }),
            ],
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),

          // Error indicator
          if (_showErrorIndicator)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.white),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Some tiles failed to load. Trying fallback date...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _showErrorIndicator = false),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

          // Layer control panel
          AnimatedBuilder(
            animation: _layerPanelAnimation,
            builder: (context, child) {
              return Positioned(
                top: 0,
                right: -300 + (300 * _layerPanelAnimation.value),
                width: 300,
                height: MediaQuery.of(context).size.height,
                child: Material(
                  elevation: 8,
                  child: Container(
                    color: theme.scaffoldBackgroundColor,
                    child: Column(
                      children: [
                        // Panel header
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: themeProvider.primaryColor,
                          child: Row(
                            children: [
                              const Icon(Icons.layers, color: Colors.white),
                              const SizedBox(width: 8),
                              const Text(
                                'Satellite Layers',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: _toggleLayerPanel,
                              ),
                            ],
                          ),
                        ),


                        // Date selector
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Date: ${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _selectDate(),
                                    tooltip: 'Select Date',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _selectedDate = DateTime.now().subtract(const Duration(days: 1));
                                        });
                                        _refreshLayers();
                                      },
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('Latest Data', style: TextStyle(fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _selectedDate = DateTime.now();
                                        });
                                        _refreshLayers();
                                      },
                                      icon: const Icon(Icons.today, size: 16),
                                      label: const Text('Today', style: TextStyle(fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const Divider(),

                        // Layer list
                        Expanded(
                          child: ListView.builder(
                            itemCount: _filteredLayers.length,
                            itemBuilder: (context, index) {
                              final layer = _filteredLayers[index];
                              final isActive = _activeLayers.contains(layer);
                              final activeLayer = isActive 
                                  ? _activeLayers.firstWhere((l) => l.id == layer.id)
                                  : layer;

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: ExpansionTile(
                                  leading: Checkbox(
                                    value: isActive,
                                    onChanged: (value) => _toggleLayer(layer),
                                  ),
                                  title: Text(
                                    layer.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    layer.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  children: [
                                    if (isActive) ...[
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Opacity: ${(activeLayer.opacity * 100).round()}%',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                            Slider(
                                              value: activeLayer.opacity,
                                              onChanged: (value) =>
                                                  _updateLayerOpacity(layer, value),
                                              min: 0.0,
                                              max: 1.0,
                                              divisions: 10,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Type: ${layer.type.toUpperCase()}',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                            Text(
                                              'Format: ${layer.format}',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Map controls
          Positioned(
            top: 16,
            left: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  onPressed: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, zoom + 1);
                  },
                  child: const Icon(Icons.zoom_in),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  onPressed: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, zoom - 1);
                  },
                  child: const Icon(Icons.zoom_out),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'previous_day',
                  backgroundColor: Colors.orange,
                  onPressed: () {
                    _dateChangeTimer?.cancel();
                    setState(() {
                      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                    });
                    
                    // Debounce tile reloading
                    _dateChangeTimer = Timer(const Duration(milliseconds: 500), () {
                      if (mounted) {
                        setState(() {}); // Trigger tile reload after debounce
                      }
                    });
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Switched to ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Icon(Icons.skip_previous),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'next_day',
                  backgroundColor: Colors.green,
                  onPressed: () {
                    // Không cho phép tua quá ngày hiện tại
                    final tomorrow = _selectedDate.add(const Duration(days: 1));
                    if (tomorrow.isAfter(DateTime.now())) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cannot go beyond today'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    
                    _dateChangeTimer?.cancel();
                    setState(() {
                      _selectedDate = tomorrow;
                    });
                    
                    // Debounce tile reloading
                    _dateChangeTimer = Timer(const Duration(milliseconds: 500), () {
                      if (mounted) {
                        setState(() {}); // Trigger tile reload after debounce
                      }
                    });
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Switched to ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Icon(Icons.skip_next),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(), // Allow up to today for real-time data
      helpText: 'Select satellite imagery date (real-time data available)',
      errorFormatText: 'Invalid date format',
      errorInvalidText: 'Date out of range',
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
      // Tự động cập nhật layers khi ngày thay đổi
      _refreshLayers();
    }
  }

  void _refreshLayers() {
    // Trigger rebuild của tile layers với ngày mới
    setState(() {
      // Force rebuild of tile layers
    });
    debugPrint('[Worldview] 🔄 Refreshed layers for date: ${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}');
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
                        const Icon(Icons.search, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Tìm Kiếm Địa Điểm',
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
              
              // Quick locations
              if (_searchSuggestions.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Địa điểm phổ biến',
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
                    children: _getPopularLocations()
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
          backgroundColor: Colors.blue.withOpacity(0.1),
          child: Icon(
            location['type'] == 'city' ? Icons.location_city : Icons.place,
            color: Colors.blue,
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

  List<Map<String, dynamic>> _getPopularLocations() {
    return [
      {
        'name': 'Hà Nội, Việt Nam',
        'country': 'Việt Nam',
        'lat': 21.0285,
        'lng': 105.8542,
        'type': 'city'
      },
      {
        'name': 'TP. Hồ Chí Minh, Việt Nam',
        'country': 'Việt Nam',
        'lat': 10.8231,
        'lng': 106.6297,
        'type': 'city'
      },
      {
        'name': 'Đà Nẵng, Việt Nam',
        'country': 'Việt Nam',
        'lat': 16.0544,
        'lng': 108.2022,
        'type': 'city'
      },
      {
        'name': 'New York, USA',
        'country': 'United States',
        'lat': 40.7128,
        'lng': -74.0060,
        'type': 'city'
      },
      {
        'name': 'London, UK',
        'country': 'United Kingdom',
        'lat': 51.5074,
        'lng': -0.1278,
        'type': 'city'
      },
      {
        'name': 'Tokyo, Japan',
        'country': 'Japan',
        'lat': 35.6762,
        'lng': 139.6503,
        'type': 'city'
      },
      {
        'name': 'Sydney, Australia',
        'country': 'Australia',
        'lat': -33.8688,
        'lng': 151.2093,
        'type': 'city'
      },
      {
        'name': 'Paris, France',
        'country': 'France',
        'lat': 48.8566,
        'lng': 2.3522,
        'type': 'city'
      },
    ];
  }

  Timer? _searchDebounceTimer;

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

    // PERFORMANCE OPTIMIZATION: Cancel previous timer để tránh multiple searches
    _searchDebounceTimer?.cancel();
    
    // Debounced search với delay ngắn hơn
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _locationSearchController.text == query) {
        _performLocationSearch(query);
      }
    });
  }

  void _performLocationSearch(String query) {
    // Simulate search results - in real app, this would call a geocoding API
    final results = <Map<String, dynamic>>[];
    final popularLocations = _getPopularLocations();
    
    for (final location in popularLocations) {
      if (location['name'].toLowerCase().contains(query.toLowerCase()) ||
          (location['country']?.toLowerCase().contains(query.toLowerCase()) ?? false)) {
        results.add(location);
      }
    }

    // Add some mock international results
    if (query.toLowerCase().contains('vietnam') || query.toLowerCase().contains('việt nam')) {
      results.addAll([
        {
          'name': 'Nha Trang, Việt Nam',
          'country': 'Việt Nam',
          'lat': 12.2388,
          'lng': 109.1967,
          'type': 'city'
        },
        {
          'name': 'Hạ Long, Việt Nam',
          'country': 'Việt Nam',
          'lat': 20.9101,
          'lng': 107.1839,
          'type': 'city'
        },
      ]);
    }

    setState(() {
      _searchSuggestions = results;
      _isSearching = false;
    });
  }

  void _navigateToLocation(double lat, double lng) {
    _mapController.move(LatLng(lat, lng), 8.0);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã chuyển đến vị trí: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  void dispose() {
    _layerPanelController.dispose();
    _dateChangeTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _locationSearchController.dispose();
    super.dispose();
  }
}
