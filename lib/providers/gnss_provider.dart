import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../models/gnss_station.dart';
import '../services/nasa_api_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/ntrip_client_service.dart';
import '../services/earthdata_auth_service.dart';

class GnssProvider with ChangeNotifier {
  final NasaApiService _apiService = NasaApiService();
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();
  final NtripClientService _ntripService = NtripClientService();
  final EarthdataAuthService _authService = EarthdataAuthService();
  
  // Real-time subscriptions
  StreamSubscription? _stationUpdateSubscription;
  StreamSubscription? _authStateSubscription;

  // State variables
  List<GnssStation> _stations = [];
  List<GnssStation> _selectedStations = [];
  List<AccuracyDataPoint> _accuracyHistory = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  DateTime? _lastUpdateTime;
  
  // Filters and settings
  double _accuracyThreshold = 5.0;
  bool _showOnlyInaccurate = false;
  String _sortBy = 'name'; // name, accuracy, updated_at
  bool _sortAscending = true;

  // Getters
  List<GnssStation> get stations => _filteredAndSortedStations();
  List<GnssStation> get allStations => _stations;
  List<GnssStation> get selectedStations => _selectedStations;
  List<AccuracyDataPoint> get accuracyHistory => _accuracyHistory;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdateTime => _lastUpdateTime;
  double get accuracyThreshold => _accuracyThreshold;
  bool get showOnlyInaccurate => _showOnlyInaccurate;
  String get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;

  // Statistics
  int get totalStations => _stations.length;
  int get accurateStations => _stations.where((s) => s.isAccurate).length;
  int get inaccurateStations => _stations.where((s) => !s.isAccurate).length;
  double get averageAccuracy => _stations.isEmpty 
      ? 0.0 
      : _stations.map((s) => s.accuracy).reduce((a, b) => a + b) / _stations.length;

  // Initialize provider
  Future<void> initialize() async {
    await _databaseService.initialize();
    await _notificationService.initialize();
    await _ntripService.initialize();
    await _authService.initialize();
    
    // Set up real-time listeners
    _setupRealtimeListeners();
    
    // Load cached stations first
    await loadCachedStations();
    
    // Try to connect to real-time data if authenticated
    if (_authService.isAuthenticated) {
      await _connectToRealtimeData();
    }
  }
  
  // Set up real-time data listeners
  void _setupRealtimeListeners() {
    // Listen for station updates from NTRIP stream
    _stationUpdateSubscription = _ntripService.stationUpdates.listen(
      (station) {
        _updateStationFromRealtime(station);
      },
      onError: (error) {
        debugPrint('Real-time station update error: $error');
        _setError('Real-time data error: $error');
      },
    );
    
    // Listen for authentication state changes
    _authStateSubscription = _authService.authStateChanges.listen(
      (isAuthenticated) {
        if (isAuthenticated) {
          _connectToRealtimeData();
        } else {
          _ntripService.disconnect();
        }
      },
    );
  }
  
  // Update station from real-time data
  void _updateStationFromRealtime(GnssStation station) {
    // Schedule update after current build cycle to avoid setState during build
    Future.microtask(() {
      // Find existing station or add new one
      final existingIndex = _stations.indexWhere((s) => s.id == station.id);
      
      if (existingIndex >= 0) {
        // Update existing station
        _stations[existingIndex] = station;
      } else {
        // Add new station
        _stations.add(station);
      }
      
      // Update accuracy history
      _accuracyHistory.add(AccuracyDataPoint(
        stationId: station.id,
        accuracy: station.accuracy,
        timestamp: station.updatedAt,
        signalStrength: station.signalStrength,
      ));
      
      // Update last update time
      _lastUpdateTime = DateTime.now();
      
      // Notify listeners
      notifyListeners();
      
      debugPrint('Real-time update: ${station.name} - ${station.accuracyString}');
    });
  }
  
  // Connect to NASA CDDIS real-time data
  Future<void> _connectToRealtimeData() async {
    if (!_authService.isAuthenticated) {
      debugPrint('Not authenticated - cannot connect to real-time data');
      return;
    }
    
    try {
      // Get NTRIP credentials from auth service
      final credentials = await _authService.getNtripCredentials();
      if (credentials == null) {
        throw Exception('Could not get NTRIP credentials');
      }
      
      // Connect to NASA CDDIS NTRIP Caster
      final connected = await _ntripService.connect(
        username: credentials['username']!,
        password: credentials['password']!,
        mountPoint: 'SSRA00BKG1', // Default to orbit corrections
      );
      
      if (connected) {
        debugPrint('Successfully connected to NASA real-time data');
        _clearError();
      } else {
        throw Exception('Failed to connect to NASA CDDIS');
      }
      
    } catch (e) {
      debugPrint('Error connecting to real-time data: $e');
      _setError('Could not connect to NASA real-time data: $e');
    }
  }

  // Load cached stations from database
  Future<void> loadCachedStations() async {
    try {
      _setLoading(true);
      _clearError();

      final cachedStations = await _databaseService.getAllStations();
      _stations = cachedStations;
      
      if (_stations.isNotEmpty) {
        _lastUpdateTime = _stations
            .map((s) => s.updatedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to load cached data: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Fetch fresh data from API
  Future<void> fetchStations({
    List<String>? stationIds,
    double? minLatitude,
    double? maxLatitude,
    double? minLongitude,
    double? maxLongitude,
    bool showNotification = true,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final freshStations = await _apiService.fetchGnssStations(
        stationIds: stationIds,
        minLatitude: minLatitude,
        maxLatitude: maxLatitude,
        minLongitude: minLongitude,
        maxLongitude: maxLongitude,
      );

      _stations = freshStations;
      _lastUpdateTime = DateTime.now();

      // Save to database
      await _databaseService.saveStations(freshStations);

      // Check for accuracy warnings
      await _notificationService.checkMultipleStations(freshStations);

      // Show success notification if requested
      if (showNotification) {
        await _notificationService.showDataRefreshNotification(freshStations.length);
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to fetch stations: $e');
      
      // Try to load cached data as fallback
      if (_stations.isEmpty) {
        await loadCachedStations();
      }
      
      // Show connection error notification
      await _notificationService.showConnectionErrorNotification();
    } finally {
      _setLoading(false);
    }
  }

  // Refresh data (pull to refresh)
  Future<void> refreshStations() async {
    if (_isRefreshing) return;

    try {
      _isRefreshing = true;
      notifyListeners();

      await fetchStations(showNotification: false);
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  // Fetch stations in a specific region
  Future<void> fetchStationsInRegion({
    required double centerLat,
    required double centerLon,
    required double radiusKm,
  }) async {
    final stations = await _apiService.fetchStationsInRegion(
      centerLat: centerLat,
      centerLon: centerLon,
      radiusKm: radiusKm,
    );

    // Merge with existing stations (avoid duplicates)
    final existingIds = _stations.map((s) => s.id).toSet();
    final newStations = stations.where((s) => !existingIds.contains(s.id)).toList();
    
    _stations.addAll(newStations);
    await _databaseService.saveStations(newStations);
    
    notifyListeners();
  }

  // Fetch single station by ID
  Future<GnssStation?> fetchStationById(String stationId) async {
    try {
      final station = await _apiService.fetchStationById(stationId);
      
      if (station != null) {
        // Update existing station or add new one
        final existingIndex = _stations.indexWhere((s) => s.id == stationId);
        if (existingIndex >= 0) {
          _stations[existingIndex] = station;
        } else {
          _stations.add(station);
        }
        
        await _databaseService.saveStation(station);
        notifyListeners();
      }
      
      return station;
    } catch (e) {
      debugPrint('Error fetching station $stationId: $e');
      return null;
    }
  }

  // Load accuracy history for a station
  Future<void> loadAccuracyHistory(String stationId, {DateTime? startTime, DateTime? endTime}) async {
    try {
      _accuracyHistory = await _databaseService.getAccuracyHistory(
        stationId,
        startTime: startTime,
        endTime: endTime,
        limit: 100,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading accuracy history: $e');
    }
  }

  // Station selection methods
  void selectStation(GnssStation station) {
    if (!_selectedStations.contains(station)) {
      _selectedStations.add(station);
      Future.microtask(() => notifyListeners());
    }
  }

  void deselectStation(GnssStation station) {
    _selectedStations.remove(station);
    Future.microtask(() => notifyListeners());
  }

  void toggleStationSelection(GnssStation station) {
    if (_selectedStations.contains(station)) {
      deselectStation(station);
    } else {
      selectStation(station);
    }
  }

  void selectAllStations() {
    _selectedStations = List.from(_stations);
    Future.microtask(() => notifyListeners());
  }

  void clearSelection() {
    _selectedStations.clear();
    Future.microtask(() => notifyListeners());
  }

  bool isStationSelected(GnssStation station) {
    return _selectedStations.contains(station);
  }

  // Filter and sort methods
  void setAccuracyThreshold(double threshold) {
    _accuracyThreshold = threshold;
    Future.microtask(() => notifyListeners());
  }

  void setShowOnlyInaccurate(bool show) {
    _showOnlyInaccurate = show;
    Future.microtask(() => notifyListeners());
  }

  void setSortBy(String sortBy, {bool? ascending}) {
    _sortBy = sortBy;
    if (ascending != null) {
      _sortAscending = ascending;
    }
    Future.microtask(() => notifyListeners());
  }

  void toggleSortOrder() {
    _sortAscending = !_sortAscending;
    Future.microtask(() => notifyListeners());
  }

  // Get filtered and sorted stations
  List<GnssStation> _filteredAndSortedStations() {
    var filtered = List<GnssStation>.from(_stations);

    // Apply accuracy filter
    if (_showOnlyInaccurate) {
      filtered = filtered.where((station) => !station.isAccurate).toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      int comparison = 0;
      
      switch (_sortBy) {
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'accuracy':
          comparison = a.accuracy.compareTo(b.accuracy);
          break;
        case 'updated_at':
          comparison = a.updatedAt.compareTo(b.updatedAt);
          break;
        case 'latitude':
          comparison = a.latitude.compareTo(b.latitude);
          break;
        case 'longitude':
          comparison = a.longitude.compareTo(b.longitude);
          break;
        default:
          comparison = a.name.compareTo(b.name);
      }
      
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  // Search stations
  List<GnssStation> searchStations(String query) {
    if (query.isEmpty) return stations;
    
    final lowercaseQuery = query.toLowerCase();
    return stations.where((station) =>
        station.name.toLowerCase().contains(lowercaseQuery) ||
        station.id.toLowerCase().contains(lowercaseQuery) ||
        station.coordinatesString.contains(lowercaseQuery)
    ).toList();
  }

  // Get stations by status
  List<GnssStation> getStationsByStatus(String status) {
    return _stations.where((station) => 
        station.statusDisplay.toLowerCase() == status.toLowerCase()
    ).toList();
  }

  // Get nearby stations
  List<GnssStation> getNearbyStations(double lat, double lon, double radiusKm) {
    return _stations.where((station) {
      final distance = _calculateDistance(lat, lon, station.latitude, station.longitude);
      return distance <= radiusKm;
    }).toList();
  }

  // Calculate distance between two points (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth radius in kilometers
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (math.pi / 180);
  }

  // Update single station
  void updateStation(GnssStation updatedStation) {
    final index = _stations.indexWhere((s) => s.id == updatedStation.id);
    if (index >= 0) {
      _stations[index] = updatedStation;
      _databaseService.saveStation(updatedStation);
      notifyListeners();
    }
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    if (loading) {
      _clearError();
    }
    Future.microtask(() => notifyListeners());
  }

  void _setError(String error) {
    _errorMessage = error;
    debugPrint('GnssProvider Error: $error');
    Future.microtask(() => notifyListeners());
  }

  void _clearError() {
    _errorMessage = null;
  }

  // Dispose
  @override
  void dispose() {
    // Cancel real-time subscriptions
    _stationUpdateSubscription?.cancel();
    _authStateSubscription?.cancel();
    
    // Disconnect from real-time services
    _ntripService.dispose();
    _authService.dispose();
    
    // Dispose other services
    _apiService.dispose();
    _databaseService.dispose();
    _notificationService.dispose();
    super.dispose();
  }
}
