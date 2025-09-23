import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/firms_fire_data.dart';
import 'earthdata_auth_service.dart';

class FirmsService {
  static final FirmsService _instance = FirmsService._internal();
  factory FirmsService() => _instance;

  // NASA FIRMS API endpoints
  static const String firmsBaseUrl = 'https://firms.modaps.eosdis.nasa.gov';
  static const String activeFiresUrl = '$firmsBaseUrl/api/active_fire';
  static const String archiveUrl = '$firmsBaseUrl/api/archive';
  static const String wmsUrl = '$firmsBaseUrl/wms';
  
  // API Key for FIRMS access
  static const String apiKey = 'd8abbd7e31342d3058b9d691c226cc7c';

  late final Dio _dio;
  // Auth service for potential future use
  // ignore: unused_field
  final EarthdataAuthService _authService = EarthdataAuthService();
  
  // Cache for fire data
  List<FirmsFireData>? _cachedFireData;
  DateTime? _cacheTime;
  static const Duration cacheTimeout = Duration(minutes: 30);

  FirmsService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: firmsBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent': 'NASA_GNSS_Client/1.0',
      },
    ));

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (object) => debugPrint('[FIRMS] $object'),
      ));
    }
  }

  /// Get active fire data using FIRMS API with API key
  /// Sources: 'MODIS_NRT', 'VIIRS_SNPP_NRT', 'VIIRS_NOAA20_NRT'
  /// dayRange: 1-10 days
  Future<List<FirmsFireData>> getActiveFires({
    String source = 'VIIRS_SNPP_NRT',
    int dayRange = 1,
    double? minLat,
    double? maxLat,
    double? minLon,
    double? maxLon,
    bool forceRefresh = false,
  }) async {
    // Return cached data if available and not expired
    if (!forceRefresh &&
        _cachedFireData != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < cacheTimeout) {
      return _filterFiresByBounds(
        _cachedFireData!,
        minLat,
        maxLat,
        minLon,
        maxLon,
      );
    }

    try {
      debugPrint('[FIRMS] Fetching active fires from $source with API key...');

      // Build API URL with key
      final url = _buildApiUrl(
        source: source, 
        dayRange: dayRange,
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
      );

      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        debugPrint('[FIRMS] ✅ API Response OK');
        debugPrint('[FIRMS] Response data type: ${response.data.runtimeType}');
        debugPrint('[FIRMS] Response data length: ${response.data.toString().length}');
        debugPrint('[FIRMS] Content-Type: ${response.headers['content-type']}');
        
        // Check if response is too short (likely error message)
        if (response.data.toString().length < 50) {
          debugPrint('[FIRMS] ⚠️ Response too short, likely empty/error');
          debugPrint('[FIRMS] Full response: ${response.data}');
        }
        
        debugPrint('[FIRMS] First 500 chars: ${response.data.toString().substring(0, response.data.toString().length.clamp(0, 500))}');
        
        if (response.data is String && response.data.toString().length > 50) {
          final fires = _parseCsvWithHeader(response.data as String);
          _cachedFireData = fires;
          _cacheTime = DateTime.now();
          debugPrint('[FIRMS] ✅ Retrieved ${fires.length} active fires from API');
          
          // Debug first few fires
          if (fires.isNotEmpty) {
            for (int i = 0; i < fires.length.clamp(0, 3); i++) {
              final f = fires[i];
              debugPrint('[FIRMS] Fire $i: lat=${f.latitude}, lon=${f.longitude}, conf=${f.confidence}');
            }
          }
          
          return fires;
        } else {
          debugPrint('[FIRMS] ⚠️ Response data is empty or not String, falling back...');
          return await _fetchFromPublicCsv(source: source, dayRange: dayRange);
        }
      }

      throw Exception('FIRMS API fetch failed: ${response.statusCode}');
    } catch (e) {
      debugPrint('[FIRMS] Error fetching active fires: $e');
      // Fallback to public CSV if API fails
      return await _fetchFromPublicCsv(source: source, dayRange: dayRange);
    }
  }

  /// Build correct FIRMS API URL using /area/ endpoint
  String _buildApiUrl({
    required String source,
    required int dayRange,
    double? minLat,
    double? maxLat,
    double? minLon,
    double? maxLon,
  }) {
    // Use correct FIRMS area API endpoint
    var url = 'https://firms.modaps.eosdis.nasa.gov/api/area/csv/$apiKey/$source';
    
    // Add area - bbox if specified, otherwise world
    if (minLat != null && maxLat != null && minLon != null && maxLon != null) {
      url += '/bbox/$minLon,$minLat,$maxLon,$maxLat';
      debugPrint('[FIRMS] 📦 Using bbox: $minLon,$minLat,$maxLon,$maxLat');
    } else {
      url += '/world';
      debugPrint('[FIRMS] 🌍 Using world area');
    }
    
    // Add day range
    url += '/${dayRange.clamp(1, 10)}';
    
    debugPrint('[FIRMS] 🔗 Correct API URL: $url');
    return url;
  }

  /// Fallback to public CSV if API fails
  Future<List<FirmsFireData>> _fetchFromPublicCsv({
    required String source,
    required int dayRange,
  }) async {
    try {
      debugPrint('[FIRMS] Falling back to public CSV...');
      final url = _buildPublicCsvUrl(source: source, dayRange: dayRange);
      final response = await Dio(BaseOptions(headers: {
        'User-Agent': 'NASA_GNSS_Client/1.0',
      })).get(url);

      if (response.statusCode == 200 && response.data is String) {
        final fires = _parseCsvWithHeader(response.data as String);
        debugPrint('[FIRMS] Retrieved ${fires.length} fires from public CSV');
        return fires;
      }
    } catch (e) {
      debugPrint('[FIRMS] Public CSV fallback failed: $e');
    }
    
    // Final fallback to mock data
    return _generateMockFireData();
  }

  /// Build public CSV URL
  String _buildPublicCsvUrl({required String source, required int dayRange}) {
    // Normalize dayRange to available CSV windows
    final window = dayRange <= 1
        ? '24h'
        : dayRange <= 2
            ? '48h'
            : '7d';

    switch (source) {
      case 'MODIS_NRT':
        return 'https://firms.modaps.eosdis.nasa.gov/data/active_fire/modis-c6.1/csv/MODIS_C6_1_Global_${window}.csv';
      case 'VIIRS_NOAA20_NRT':
        return 'https://firms.modaps.eosdis.nasa.gov/data/active_fire/viirs-noaa20-nrt/csv/VIIRS_NOAA20_NRT_Global_${window}.csv';
      case 'VIIRS_SNPP_NRT':
      default:
        return 'https://firms.modaps.eosdis.nasa.gov/data/active_fire/viirs-snpp-nrt/csv/VIIRS_SNPP_NRT_Global_${window}.csv';
    }
  }

  /// Get archive fire data for a specific date range using API key
  Future<List<FirmsFireData>> getArchiveFires({
    required DateTime startDate,
    required DateTime endDate,
    String source = 'VIIRS_SNPP_NRT',
    double? minLat,
    double? maxLat,
    double? minLon,
    double? maxLon,
  }) async {
    try {
      debugPrint('[FIRMS] Fetching archive fires from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}...');
      
      final baseUrl = 'https://firms.modaps.eosdis.nasa.gov/api/archive/csv';
      final params = <String, String>{
        'source': source,
        'start_date': '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
        'end_date': '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
        'format': 'csv',
        'api_key': apiKey,
      };

      // Add bounding box if specified
      if (minLat != null && maxLat != null && minLon != null && maxLon != null) {
        params['bbox'] = '$minLon,$minLat,$maxLon,$maxLat';
      }

      final queryString = params.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final url = '$baseUrl?$queryString';
      final response = await _dio.get(url);
      
      if (response.statusCode == 200 && response.data is String) {
        final fires = _parseCsvWithHeader(response.data as String);
        debugPrint('[FIRMS] Retrieved ${fires.length} archive fires');
        return fires;
      } else {
        throw Exception('Failed to fetch archive fires: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[FIRMS] Error fetching archive fires: $e');
      return [];
    }
  }

  /// Parse CSV with header-safe mapping
  List<FirmsFireData> _parseCsvWithHeader(String csvData) {
    final lines = csvData.split('\n').where((l) => l.trim().isNotEmpty).toList();
    debugPrint('[FIRMS] CSV parsing: ${lines.length} lines total');
    
    if (lines.length < 2) {
      debugPrint('[FIRMS] Not enough lines in CSV (need header + data)');
      return [];
    }

    final header = _parseCsvLine(lines.first).map((h) => h.trim().toLowerCase()).toList();
    debugPrint('[FIRMS] CSV header: $header');
    int idx(String name) => header.indexOf(name);

    final latIdx = idx('latitude');
    final lonIdx = idx('longitude');
    final brightIdx = idx('brightness'); // MODIS/VIIRS
    final scanIdx = idx('scan');
    final trackIdx = idx('track');
    final dateIdx = idx('acq_date');
    final timeIdx = idx('acq_time');
    final satIdx = idx('satellite');
    final instrIdx = header.contains('instrument') ? idx('instrument') : -1;
    final confIdx = idx('confidence');
    final verIdx = idx('version');
    final t31Idx = header.indexOf('bright_t31');
    final frpIdx = idx('frp');
    final dnIdx = idx('daynight');

    final fires = <FirmsFireData>[];

    for (var i = 1; i < lines.length; i++) {
      final fields = _parseCsvLine(lines[i]);
      try {
        final acqDate = DateTime.parse(fields[dateIdx]);
        fires.add(FirmsFireData(
          latitude: double.parse(fields[latIdx]),
          longitude: double.parse(fields[lonIdx]),
          brightness: brightIdx >= 0 && fields[brightIdx].isNotEmpty
              ? double.tryParse(fields[brightIdx])
              : null,
          scan: scanIdx >= 0 ? fields[scanIdx] : null,
          track: trackIdx >= 0 ? fields[trackIdx] : null,
          acqDate: acqDate,
          acqTime: fields[timeIdx],
          satellite: fields[satIdx],
          instrument: instrIdx >= 0 ? fields[instrIdx] : (fields[satIdx].startsWith('V') ? 'VIIRS' : 'MODIS'),
          confidence: confIdx >= 0 ? fields[confIdx] : 'nominal',
          version: verIdx >= 0 ? fields[verIdx] : 'N/A',
          brightT31: t31Idx >= 0 && fields[t31Idx].isNotEmpty ? double.tryParse(fields[t31Idx]) : null,
          frp: frpIdx >= 0 && fields[frpIdx].isNotEmpty ? double.tryParse(fields[frpIdx]) : null,
          daynight: dnIdx >= 0 ? fields[dnIdx] : null,
        ));
      } catch (e) {
        // Skip bad rows
      }
    }
    return fires;
  }

  /// Parse a single CSV line handling quoted fields
  List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        fields.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    
    // Add the last field
    fields.add(buffer.toString());
    
    return fields;
  }

  /// Filter fires by geographic bounds
  List<FirmsFireData> _filterFiresByBounds(
    List<FirmsFireData> fires,
    double? minLat,
    double? maxLat,
    double? minLon,
    double? maxLon,
  ) {
    if (minLat == null || maxLat == null || minLon == null || maxLon == null) {
      return fires;
    }
    
    return fires.where((fire) =>
      fire.latitude >= minLat &&
      fire.latitude <= maxLat &&
      fire.longitude >= minLon &&
      fire.longitude <= maxLon
    ).toList();
  }

  /// Generate mock fire data for testing
  List<FirmsFireData> _generateMockFireData() {
    final now = DateTime.now();
    final random = Random();
    return List.generate(20, (index) {
      final lat = -90 + random.nextDouble() * 180; // Random latitude
      final lon = -180 + random.nextDouble() * 360; // Random longitude
      final brightness = 300 + random.nextDouble() * 100; // 300-400K
      final frp = random.nextDouble() * 50; // 0-50 MW
      
      return FirmsFireData(
        latitude: lat,
        longitude: lon,
        brightness: brightness,
        scan: '1.0',
        track: '1.0',
        acqDate: now.subtract(Duration(hours: random.nextInt(24))),
        acqTime: '${random.nextInt(24).toString().padLeft(2, '0')}${random.nextInt(60).toString().padLeft(2, '0')}',
        satellite: random.nextBool() ? 'N' : 'T',
        instrument: random.nextBool() ? 'VIIRS' : 'MODIS',
        confidence: ['low', 'nominal', 'high'][random.nextInt(3)],
        version: '2.0',
        frp: frp,
        daynight: random.nextBool() ? 'D' : 'N',
      );
    });
  }

  /// Get fire statistics for a region
  Future<Map<String, dynamic>> getFireStatistics({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    int dayRange = 7,
  }) async {
    try {
      final fires = await getActiveFires(
        dayRange: dayRange,
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
      );

      final stats = <String, dynamic>{
        'total_fires': fires.length,
        'high_confidence': fires.where((f) => f.confidenceLevel == FireConfidence.high).length,
        'moderate_confidence': fires.where((f) => f.confidenceLevel == FireConfidence.nominal).length,
        'low_confidence': fires.where((f) => f.confidenceLevel == FireConfidence.low).length,
        'extreme_intensity': fires.where((f) => f.intensity == FireIntensity.extreme).length,
        'high_intensity': fires.where((f) => f.intensity == FireIntensity.high).length,
        'moderate_intensity': fires.where((f) => f.intensity == FireIntensity.moderate).length,
        'low_intensity': fires.where((f) => f.intensity == FireIntensity.low).length,
        'avg_brightness': fires.where((f) => f.brightness != null).isEmpty ? 0 :
          fires.where((f) => f.brightness != null).map((f) => f.brightness!).reduce((a, b) => a + b) / fires.where((f) => f.brightness != null).length,
        'avg_frp': fires.where((f) => f.frp != null).isEmpty ? 0 :
          fires.where((f) => f.frp != null).map((f) => f.frp!).reduce((a, b) => a + b) / fires.where((f) => f.frp != null).length,
        'satellites': fires.map((f) => f.satellite).toSet().toList(),
        'instruments': fires.map((f) => f.instrument).toSet().toList(),
      };

      return stats;
    } catch (e) {
      debugPrint('[FIRMS] Error calculating fire statistics: $e');
      return {};
    }
  }

  /// Get WMS URL for fire overlay
  String getFireWmsUrl({
    String source = 'VIIRS_SNPP_C2',
    int dayRange = 1,
  }) {
    return '$wmsUrl?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap'
           '&LAYERS=fires_$source'
           '&STYLES=&SRS=EPSG:4326'
           '&BBOX={bbox}'
           '&WIDTH={width}&HEIGHT={height}'
           '&FORMAT=image/png'
           '&TRANSPARENT=TRUE'
           '&TIME=${DateTime.now().subtract(Duration(days: dayRange)).toIso8601String().split('T')[0]}';
  }

  /// Test connection to FIRMS API
  Future<bool> testConnection() async {
    try {
      final response = await _dio.head('/', 
        options: Options(sendTimeout: const Duration(seconds: 10)));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[FIRMS] Connection test failed: $e');
      return false;
    }
  }

  /// Clear cached data
  void clearCache() {
    _cachedFireData = null;
    _cacheTime = null;
  }

  /// Dispose resources
  void dispose() {
    _dio.close();
  }
}
