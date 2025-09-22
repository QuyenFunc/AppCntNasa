import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/gnss_station.dart';
import 'nasa_real_data_service.dart';
import 'earthdata_auth_service.dart';

class NasaApiService {
  static const String _baseUrl = 'https://cmr.earthdata.nasa.gov';
  
  late final Dio _dio;
  final Random _random = Random();
  final NasaRealDataService _realDataService = NasaRealDataService();
  final EarthdataAuthService _authService = EarthdataAuthService();
  
  // Authentication service integration
  String? _currentToken;

  NasaApiService([String? bearerToken]) {
    _currentToken = bearerToken;
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'NASA_GNSS_Client/1.0',
        if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
      },
    ));

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (object) => debugPrint(object.toString()),
      ));
    }
  }

  // Set authentication token
  Future<void> setAuthToken(String token) async {
    _currentToken = token;
    _dio.options.headers['Authorization'] = 'Bearer $token';
    debugPrint('NASA API Service: Bearer token updated');
  }

  /// Get granules from CMR API - requires valid Earthdata token for protected datasets
  Future<Response> getGranules({required String shortName, int pageSize = 10}) async {
    return _dio.get(
      '/search/granules.json',
      queryParameters: {
        'short_name': shortName,
        'page_size': pageSize,
      },
    );
  }

  /// Get collections from CMR API
  Future<Response> getCollections({String? keyword, int pageSize = 10}) async {
    return _dio.get(
      '/search/collections.json',
      queryParameters: {
        if (keyword != null) 'keyword': keyword,
        'page_size': pageSize,
      },
    );
  }

  // Update authentication headers from auth service
  Future<bool> updateAuthHeaders() async {
    try {
      final headers = await _authService.getAuthHeaders();
      if (headers != null) {
        _dio.options.headers.addAll(headers);
        _currentToken = headers['Authorization']?.split(' ').last;
        debugPrint('NASA API Service: Auth headers updated successfully');
        return true;
      } else {
        debugPrint('NASA API Service: No valid auth headers available');
        return false;
      }
    } catch (e) {
      debugPrint('NASA API Service: Failed to update auth headers: $e');
      return false;
    }
  }

  // Check if we have valid authentication
  bool get hasValidAuth {
    return _authService.isAuthenticated && _currentToken != null;
  }

  // Main method to fetch GNSS stations
  Future<List<GnssStation>> fetchGnssStations({
    List<String>? stationIds,
    double? minLatitude,
    double? maxLatitude,
    double? minLongitude,
    double? maxLongitude,
  }) async {
    // Update authentication headers before making API calls
    final hasAuth = await updateAuthHeaders();
    
    if (!hasAuth) {
      throw Exception('Authentication required. Please login with NASA Earthdata credentials.');
    }

    // Try real API with authentication
    return await _fetchRealGnssData(
      stationIds: stationIds,
      minLatitude: minLatitude,
      maxLatitude: maxLatitude,
      minLongitude: minLongitude,
      maxLongitude: maxLongitude,
    );
  }

  // Attempt to fetch real GNSS data from NASA
  Future<List<GnssStation>> _fetchRealGnssData({
    List<String>? stationIds,
    double? minLatitude,
    double? maxLatitude,
    double? minLongitude,
    double? maxLongitude,
  }) async {
    // Use real NASA/IGS data service instead of mock
    debugPrint('Fetching real-time data from NASA/IGS Global Network...');
    return await _realDataService.fetchRealTimeData();
  }

  // Parse API response to GnssStation objects (unused but kept for future use)
  // ignore: unused_element
  List<GnssStation> _parseGnssResponse(dynamic data) {
    try {
      List<dynamic> stationsData;
      
      if (data is Map<String, dynamic>) {
        // Try different possible response structures
        if (data.containsKey('stations')) {
          stationsData = data['stations'] as List<dynamic>;
        } else if (data.containsKey('data')) {
          stationsData = data['data'] as List<dynamic>;
        } else if (data.containsKey('results')) {
          stationsData = data['results'] as List<dynamic>;
        } else {
          throw Exception('Unexpected response structure');
        }
      } else if (data is List<dynamic>) {
        stationsData = data;
      } else {
        throw Exception('Invalid response format');
      }

      return stationsData.map((stationData) {
        try {
          return GnssStation.fromJson(stationData as Map<String, dynamic>);
        } catch (e) {
          // If the API structure doesn't match our model, create a station manually
          return _createStationFromRawData(stationData);
        }
      }).toList();
    } catch (e) {
      debugPrint('Error parsing GNSS response: $e');
      rethrow;
    }
  }

  // Create GnssStation from raw API data with different field names
  GnssStation _createStationFromRawData(dynamic data) {
    final Map<String, dynamic> stationData = data as Map<String, dynamic>;
    
    return GnssStation(
      id: _extractField(stationData, ['id', 'station_id', 'stationId', 'ID']) ?? 
          'STATION_${_random.nextInt(10000)}',
      name: _extractField(stationData, ['name', 'station_name', 'stationName', 'site_name']) ?? 
          'Unknown Station',
      latitude: _extractDouble(stationData, ['latitude', 'lat', 'y', 'coord_lat']) ?? 0.0,
      longitude: _extractDouble(stationData, ['longitude', 'lon', 'lng', 'x', 'coord_lon']) ?? 0.0,
      accuracy: _extractDouble(stationData, ['accuracy', 'precision', 'error', 'uncertainty']) ?? 
          _random.nextDouble() * 10 + 1,
      updatedAt: _extractDateTime(stationData, ['updated_at', 'last_updated', 'timestamp', 'date']) ?? 
          DateTime.now(),
      elevation: _extractDouble(stationData, ['elevation', 'altitude', 'height', 'z']),
      satelliteCount: _extractInt(stationData, ['satellite_count', 'satellites', 'sat_count']),
      signalStrength: _extractDouble(stationData, ['signal_strength', 'signal', 'strength', 'snr']),
      status: _extractField(stationData, ['status', 'state', 'condition']) ?? 'Active',
    );
  }

  // Helper methods to extract fields with different possible names
  String? _extractField(Map<String, dynamic> data, List<String> possibleKeys) {
    for (final key in possibleKeys) {
      if (data.containsKey(key) && data[key] != null) {
        return data[key].toString();
      }
    }
    return null;
  }

  double? _extractDouble(Map<String, dynamic> data, List<String> possibleKeys) {
    for (final key in possibleKeys) {
      if (data.containsKey(key) && data[key] != null) {
        return double.tryParse(data[key].toString());
      }
    }
    return null;
  }

  int? _extractInt(Map<String, dynamic> data, List<String> possibleKeys) {
    for (final key in possibleKeys) {
      if (data.containsKey(key) && data[key] != null) {
        return int.tryParse(data[key].toString());
      }
    }
    return null;
  }

  DateTime? _extractDateTime(Map<String, dynamic> data, List<String> possibleKeys) {
    for (final key in possibleKeys) {
      if (data.containsKey(key) && data[key] != null) {
        try {
          return DateTime.parse(data[key].toString());
        } catch (e) {
          // Try parsing timestamp
          final timestamp = int.tryParse(data[key].toString());
          if (timestamp != null) {
            return DateTime.fromMillisecondsSinceEpoch(timestamp);
          }
        }
      }
    }
    return null;
  }


  // Fetch single station by ID
  Future<GnssStation?> fetchStationById(String stationId) async {
    try {
      final stations = await fetchGnssStations(stationIds: [stationId]);
      return stations.isNotEmpty ? stations.first : null;
    } catch (e) {
      debugPrint('Error fetching station $stationId: $e');
      return null;
    }
  }

  // Fetch multiple stations by IDs
  Future<List<GnssStation>> fetchStationsByIds(List<String> stationIds) async {
    return await fetchGnssStations(stationIds: stationIds);
  }

  // Fetch stations in a geographic region
  Future<List<GnssStation>> fetchStationsInRegion({
    required double centerLat,
    required double centerLon,
    required double radiusKm,
  }) async {
    // Calculate bounding box from center and radius
    const kmPerDegree = 111.0; // Approximate km per degree
    final latRadius = radiusKm / kmPerDegree;
    final lonRadius = radiusKm / (kmPerDegree * cos(centerLat * pi / 180));

    return await fetchGnssStations(
      minLatitude: centerLat - latRadius,
      maxLatitude: centerLat + latRadius,
      minLongitude: centerLon - lonRadius,
      maxLongitude: centerLon + lonRadius,
    );
  }

  // Test API connection
  Future<bool> testConnection() async {
    try {
      final response = await _dio.get('/health', 
        options: Options(sendTimeout: const Duration(seconds: 10)));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API connection test failed: $e');
      return false;
    }
  }

  // Dispose resources
  void dispose() {
    _dio.close();
  }
}
