import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/worldview_layer.dart';
import 'earthdata_auth_service.dart';

class WorldviewService {
  static final WorldviewService _instance = WorldviewService._internal();
  factory WorldviewService() => _instance;

  // NASA GIBS (Global Imagery Browse Services) endpoints
  static const String gibsBaseUrl = 'https://gibs.earthdata.nasa.gov';
  static const String wmtsEndpoint = '$gibsBaseUrl/wmts/epsg3857/best';
  static const String wmsEndpoint = '$gibsBaseUrl/wms/epsg3857/best';
  static const String capabilitiesEndpoint = '$gibsBaseUrl/wmts/epsg3857/best/1.0.0/WMTSCapabilities.xml';

  late final Dio _dio;
  // Auth service for potential future use
  // ignore: unused_field
  final EarthdataAuthService _authService = EarthdataAuthService();
  
  // Cache for available layers
  List<WorldviewLayer>? _cachedLayers;
  DateTime? _cacheTime;
  static const Duration cacheTimeout = Duration(hours: 6);

  WorldviewService._internal() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30), // Increased for WiFi
      receiveTimeout: const Duration(seconds: 60), // Increased for WiFi
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent': 'NASA_GNSS_Client/1.0',
        'Accept': 'application/xml,text/xml,*/*',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
      },
      followRedirects: true,
      maxRedirects: 5,
    ));

    // Custom retry interceptor for WiFi/mobile data instability
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        if (_shouldRetry(error) && error.requestOptions.extra['retryCount'] == null) {
          error.requestOptions.extra['retryCount'] = 0;
        }
        
        final retryCount = error.requestOptions.extra['retryCount'] as int? ?? 0;
        if (retryCount < 5 && _shouldRetry(error)) {
          debugPrint('[Worldview Retry] Attempt ${retryCount + 1}/5 - ${error.message}');
          error.requestOptions.extra['retryCount'] = retryCount + 1;
          
          // Progressive delay for mobile data
          final delay = Duration(seconds: (retryCount + 1) * 2);
          await Future.delayed(delay);
          
          try {
            final response = await _dio.fetch(error.requestOptions);
            handler.resolve(response);
          } catch (e) {
            handler.next(error);
          }
        } else {
          handler.next(error);
        }
      },
    ));

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (object) => debugPrint('[Worldview] $object'),
      ));
    }
  }

  /// Get available satellite layers from NASA GIBS
  Future<List<WorldviewLayer>> getAvailableLayers({bool forceRefresh = false}) async {
    // Return cached data if available and not expired
    if (!forceRefresh && 
        _cachedLayers != null && 
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < cacheTimeout) {
      return _cachedLayers!;
    }

    try {
      debugPrint('[Worldview] Fetching available layers...');
      
      // Get WMTS capabilities
      final response = await _dio.get(capabilitiesEndpoint);
      
      if (response.statusCode == 200) {
        final layers = _parseCapabilities(response.data);
        _cachedLayers = layers;
        _cacheTime = DateTime.now();
        
        debugPrint('[Worldview] Retrieved ${layers.length} layers');
        return layers;
      } else {
        throw Exception('Failed to fetch capabilities: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[Worldview] Error fetching layers: $e');
      // Return default layers if API fails
      return WorldviewLayer.defaultLayers;
    }
  }

  /// Parse WMTS capabilities XML to extract layer information
  List<WorldviewLayer> _parseCapabilities(String xmlData) {
    // For now, return predefined popular layers with working configurations
    // Using GIBS WMTS service with proper tile matrix sets
    return [
      const WorldviewLayer(
        id: 'MODIS_Terra_CorrectedReflectance_TrueColor',
        title: 'MODIS Terra True Color',
        description: 'Corrected Reflectance True Color from MODIS Terra',
        type: 'wmts',
        format: 'image/jpeg',
        tileMatrixSet: 'GoogleMapsCompatible_Level9',
        baseUrl: wmtsEndpoint,
        availableDates: [],
      ),
      const WorldviewLayer(
        id: 'MODIS_Aqua_CorrectedReflectance_TrueColor',
        title: 'MODIS Aqua True Color',
        description: 'Corrected Reflectance True Color from MODIS Aqua',
        type: 'wmts',
        format: 'image/jpeg',
        tileMatrixSet: 'GoogleMapsCompatible_Level9',
        baseUrl: wmtsEndpoint,
        availableDates: [],
      ),
      const WorldviewLayer(
        id: 'VIIRS_SNPP_CorrectedReflectance_TrueColor',
        title: 'VIIRS SNPP True Color',
        description: 'Corrected Reflectance True Color from VIIRS SNPP',
        type: 'wmts',
        format: 'image/jpeg',
        tileMatrixSet: 'GoogleMapsCompatible_Level9',
        baseUrl: wmtsEndpoint,
        availableDates: [],
      ),
      const WorldviewLayer(
        id: 'MODIS_Terra_CorrectedReflectance_Bands721',
        title: 'MODIS Terra False Color (Bands 7-2-1)',
        description: 'False color composite useful for fire detection',
        type: 'wmts',
        format: 'image/jpeg',
        tileMatrixSet: 'GoogleMapsCompatible_Level9',
        baseUrl: wmtsEndpoint,
        availableDates: [],
      ),
      const WorldviewLayer(
        id: 'MODIS_Combined_Thermal_Anomalies_All',
        title: 'MODIS Thermal Anomalies',
        description: 'Combined thermal anomalies from MODIS Terra and Aqua',
        type: 'wmts',
        format: 'image/png',
        tileMatrixSet: 'GoogleMapsCompatible_Level9',
        baseUrl: wmtsEndpoint,
        availableDates: [],
      ),
      const WorldviewLayer(
        id: 'VIIRS_SNPP_Thermal_Anomalies_375m_All',
        title: 'VIIRS Thermal Anomalies',
        description: 'Thermal anomalies from VIIRS SNPP at 375m resolution',
        type: 'wmts',
        format: 'image/png',
        tileMatrixSet: 'GoogleMapsCompatible_Level9',
        baseUrl: wmtsEndpoint,
        availableDates: [],
      ),
    ];
  }

  /// Generate WMTS tile URL for a specific layer, zoom, x, y coordinates and date
  String getTileUrl({
    required WorldviewLayer layer,
    required int z,
    required int x,
    required int y,
    DateTime? date,
    bool fallbackToPreviousDay = false,
  }) {
    // Use a date that definitely has data - try 7 days ago to be very safe
    final safeDefaultDate = DateTime.now().subtract(const Duration(days: 7));
    var targetDate = date ?? safeDefaultDate;
    
    // If fallback requested, try previous day
    if (fallbackToPreviousDay) {
      targetDate = targetDate.subtract(const Duration(days: 1));
      debugPrint('[Worldview] 📅 Fallback to previous day: $targetDate');
    }
    
    // Ensure we don't request future dates or too recent dates
    final safeDate = targetDate.isAfter(safeDefaultDate) ? safeDefaultDate : targetDate;
    
    final dateStr = '${safeDate.year}-${safeDate.month.toString().padLeft(2, '0')}-${safeDate.day.toString().padLeft(2, '0')}';
    
    // Debug URL generation - CORRECT ORDER: z/x/y for XYZ tiles
    final url = '${layer.baseUrl}/${layer.id}/default/$dateStr/${layer.tileMatrixSet}/$z/$x/$y.${_getFileExtension(layer.format)}';
    if (z <= 3) { // Only log low zoom levels to avoid spam
      debugPrint('[Worldview] 🗺️ Tile URL (z=$z, date=$dateStr): $url');
    }
    
    return url;
  }

  /// Get file extension from MIME type
  String _getFileExtension(String mimeType) {
    switch (mimeType) {
      case 'image/jpeg':
        return 'jpg';
      case 'image/png':
        return 'png';
      default:
        return 'jpg';
    }
  }

  /// Get available dates for a specific layer
  Future<List<DateTime>> getAvailableDates(String layerId) async {
    try {
      // This would typically query the GIBS API for available dates
      // For now, return recent dates
      final now = DateTime.now();
      final dates = <DateTime>[];
      
      for (int i = 0; i < 30; i++) {
        dates.add(now.subtract(Duration(days: i)));
      }
      
      return dates;
    } catch (e) {
      debugPrint('[Worldview] Error fetching available dates: $e');
      return [];
    }
  }

  /// Search layers by keyword
  List<WorldviewLayer> searchLayers(List<WorldviewLayer> layers, String query) {
    if (query.isEmpty) return layers;
    
    final lowerQuery = query.toLowerCase();
    return layers.where((layer) =>
      layer.title.toLowerCase().contains(lowerQuery) ||
      layer.description.toLowerCase().contains(lowerQuery) ||
      layer.id.toLowerCase().contains(lowerQuery)
    ).toList();
  }

  /// Filter layers by type (e.g., 'wmts', 'wms')
  List<WorldviewLayer> filterLayersByType(List<WorldviewLayer> layers, String type) {
    return layers.where((layer) => layer.type == type).toList();
  }

  /// Get layers suitable for fire monitoring
  List<WorldviewLayer> getFireLayers(List<WorldviewLayer> layers) {
    return layers.where((layer) =>
      layer.id.contains('Thermal') ||
      layer.id.contains('Fire') ||
      layer.id.contains('Bands721') ||
      layer.title.toLowerCase().contains('fire') ||
      layer.title.toLowerCase().contains('thermal') ||
      layer.description.toLowerCase().contains('fire')
    ).toList();
  }

  /// Test connection to NASA GIBS
  Future<bool> testConnection() async {
    try {
      final response = await _dio.head(gibsBaseUrl, 
        options: Options(sendTimeout: const Duration(seconds: 10)));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[Worldview] Connection test failed: $e');
      return false;
    }
  }

  /// Check if request should be retried
  bool _shouldRetry(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
           error.type == DioExceptionType.receiveTimeout ||
           error.type == DioExceptionType.sendTimeout ||
           error.type == DioExceptionType.connectionError ||
           (error.response?.statusCode != null && 
            error.response!.statusCode! >= 500);
  }

  /// Dispose resources
  void dispose() {
    _dio.close();
  }
}
