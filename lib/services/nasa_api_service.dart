import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/gnss_station.dart';
import 'nasa_real_data_service.dart';

class NasaApiService {
  static const String _baseUrl = 'https://urs.earthdata.nasa.gov';
  static const String _token = 'eyJ0eXAiOiJKV1QiLCJvcmlnaW4iOiJFYXJ0aGRhdGEgTG9naW4iLCJzaWciOiJlZGxqd3RwdWJrZXlfb3BzIiwiYWxnIjoiUlMyNTYifQ.eyJ0eXBlIjoiVXNlciIsInVpZCI6InF1eWVuZnVuYyIsImV4cCI6MTc2Mzc2OTU5OSwiaWF0IjoxNzU4NTM0MDg0LCJpc3MiOiJodHRwczovL3Vycy5lYXJ0aGRhdGEubmFzYS5nb3YiLCJpZGVudGl0eV9wcm92aWRlciI6ImVkbF9vcHMiLCJhY3IiOiJlZGwiLCJhc3N1cmFuY2VfbGV2ZWwiOjN9.IsqZWwdcxf8NyQEJ238smiXscqaWZoG1ieYqig6vjyj7Gqnp2vipg3H08TEb1xIzqnmbGYNNiZ4QCy3fBHkqn6QZ4wM5WX3_bSv4JhG0ZNdkCxT10bB4B7igpjnCMsM6Z3RDxpj78ZA0RHeEX3HbaTFV9KeS1OWPgp7Vg6lbmRZ6yPpu8z_FY0w3VmfRkdEwQ9fLjzLwSlxHdwaYH_rBD25PWFJ0CjnqsmvJo4uMAUkDnLVYKGnruum4-LuYlXlS1Lz3m-JzsUBfcwqv4tin5Ge_tzFp42cbjXHsZaaiIYimNhFzAH2RAFCsWV80RvuZK923yYq-Et41kLJQKmGdGg';
  
  late final Dio _dio;
  final Random _random = Random();
  final NasaRealDataService _realDataService = NasaRealDataService();

  NasaApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
        'User-Agent': 'NASA_GNSS_Client/1.0',
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

  // Main method to fetch GNSS stations
  Future<List<GnssStation>> fetchGnssStations({
    List<String>? stationIds,
    double? minLatitude,
    double? maxLatitude,
    double? minLongitude,
    double? maxLongitude,
  }) async {
    try {
      // Since NASA's real GNSS API might be complex or restricted,
      // we'll first try the real API and fallback to mock data
      return await _fetchRealGnssData(
        stationIds: stationIds,
        minLatitude: minLatitude,
        maxLatitude: maxLatitude,
        minLongitude: minLongitude,
        maxLongitude: maxLongitude,
      );
    } catch (e) {
      debugPrint('Real API failed, using mock data: $e');
      return _generateMockGnssStations(
        stationIds: stationIds,
        minLatitude: minLatitude,
        maxLatitude: maxLatitude,
        minLongitude: minLongitude,
        maxLongitude: maxLongitude,
      );
    }
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

  // Generate mock GNSS stations for development and fallback
  List<GnssStation> _generateMockGnssStations({
    List<String>? stationIds,
    double? minLatitude,
    double? maxLatitude,
    double? minLongitude,
    double? maxLongitude,
  }) {
    final stations = <GnssStation>[];
    final stationNames = [
      'NASA JPL Goldstone',
      'Canberra Deep Space',
      'Madrid Deep Space',
      'Arecibo Observatory',
      'Green Bank Telescope',
      'Parkes Observatory',
      'Effelsberg Radio',
      'Jodrell Bank',
      'VLA Socorro',
      'ALMA Chile',
      'Mauna Kea Hawaii',
      'Atacama Desert',
      'Antarctic Research',
      'Greenland Ice',
      'Siberian Station',
    ];

    // Generate stations within specified bounds or globally
    final latMin = minLatitude ?? -90.0;
    final latMax = maxLatitude ?? 90.0;
    final lonMin = minLongitude ?? -180.0;
    final lonMax = maxLongitude ?? 180.0;

    final count = stationIds?.length ?? 15;
    
    for (int i = 0; i < count; i++) {
      final stationId = stationIds?.elementAtOrNull(i) ?? 'GNSS_${1000 + i}';
      final stationName = stationNames[i % stationNames.length];
      
      // Generate coordinates within bounds
      final lat = latMin + _random.nextDouble() * (latMax - latMin);
      final lon = lonMin + _random.nextDouble() * (lonMax - lonMin);
      
      stations.add(GnssStation(
        id: stationId,
        name: '$stationName $stationId',
        latitude: lat,
        longitude: lon,
        accuracy: 0.5 + _random.nextDouble() * 9.5, // 0.5m to 10m
        updatedAt: DateTime.now().subtract(
          Duration(
            minutes: _random.nextInt(60),
            seconds: _random.nextInt(60),
          ),
        ),
        elevation: 0 + _random.nextDouble() * 4000, // 0 to 4000m
        satelliteCount: 8 + _random.nextInt(16), // 8 to 24 satellites
        signalStrength: 20 + _random.nextDouble() * 25, // 20 to 45 dB
        status: _random.nextBool() ? 'Active' : 'Maintenance',
      ));
    }

    return stations;
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
