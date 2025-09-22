import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../services/earthdata_auth_service.dart';

class OfflineProvider with ChangeNotifier {
  final EarthdataAuthService _authService = EarthdataAuthService();

  // Authentication state
  bool _isAuthenticated = false;
  bool _isAuthenticating = false;
  String _authStatusMessage = '';
  Map<String, dynamic> _userInfo = {};

  // Search state
  bool _isSearching = false;
  List<SearchResult> _searchResults = [];
  String _searchQuery = '';

  // Download state
  List<DownloadItem> _downloads = [];
  bool _isDownloading = false;

  // Viewer state
  DownloadItem? _selectedFile;
  String _fileContent = '';

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isAuthenticating => _isAuthenticating;
  String get authStatusMessage => _authStatusMessage;
  Map<String, dynamic> get userInfo => _userInfo;
  
  bool get isSearching => _isSearching;
  List<SearchResult> get searchResults => _searchResults;
  String get searchQuery => _searchQuery;
  
  List<DownloadItem> get downloads => _downloads;
  bool get isDownloading => _isDownloading;
  
  DownloadItem? get selectedFile => _selectedFile;
  String get fileContent => _fileContent;

  // Initialize
  Future<void> initialize() async {
    await _authService.initialize();
    _checkAuthStatus();
  }

  void _checkAuthStatus() {
    _isAuthenticated = _authService.isAuthenticated;
    if (_isAuthenticated) {
      _authStatusMessage = 'Successfully authenticated with NASA Earthdata';
      _userInfo = _authService.userProfile ?? {};
    }
    notifyListeners();
  }

  // Authentication methods
  Future<void> authenticate(String apiKey) async {
    _isAuthenticating = true;
    _authStatusMessage = 'Authenticating...';
    notifyListeners();

    try {
      final success = await _authService.loginWithJwt(apiKey);
      
      if (success) {
        _isAuthenticated = true;
        _authStatusMessage = 'Authentication successful!';
        _userInfo = _authService.userProfile ?? {};
      } else {
        _isAuthenticated = false;
        _authStatusMessage = 'Authentication failed. Please check your API key.';
        _userInfo = {};
      }
    } catch (e) {
      _isAuthenticated = false;
      _authStatusMessage = 'Authentication error: $e';
      _userInfo = {};
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _isAuthenticated = false;
    _authStatusMessage = '';
    _userInfo = {};
    _searchResults.clear();
    _downloads.clear();
    _selectedFile = null;
    _fileContent = '';
    notifyListeners();
  }

  // Search methods
  Future<void> search({
    required String stationId,
    required DateTime startDate,
    required DateTime endDate,
    required String dataType,
  }) async {
    if (!_isAuthenticated) {
      throw Exception('Not authenticated. Please login first.');
    }

    _isSearching = true;
    _searchQuery = '$stationId ($dataType) ${startDate.toIso8601String().split('T')[0]} to ${endDate.toIso8601String().split('T')[0]}';
    notifyListeners();

    try {
      // Mock search results for now
      await Future.delayed(const Duration(seconds: 2));
      
      _searchResults = _generateMockSearchResults(stationId, startDate, endDate, dataType);
    } catch (e) {
      _searchResults = [];
      rethrow;
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  List<SearchResult> _generateMockSearchResults(
    String stationId, 
    DateTime startDate, 
    DateTime endDate, 
    String dataType,
  ) {
    final results = <SearchResult>[];
    final days = endDate.difference(startDate).inDays;
    
    for (int i = 0; i <= days; i++) {
      final date = startDate.add(Duration(days: i));
      results.add(SearchResult(
        id: '${stationId}_${dataType}_${date.toIso8601String().split('T')[0]}',
        title: '$stationId $dataType Data',
        description: '$dataType data for station $stationId on ${date.toIso8601String().split('T')[0]}',
        date: date,
        dataType: dataType,
        stationId: stationId,
        fileSize: '2.${(i % 9) + 1} MB',
        format: _getFormatForDataType(dataType),
        downloadUrl: 'https://example.nasa.gov/data/${stationId}_${date.toIso8601String().split('T')[0]}.dat',
      ));
    }
    
    return results;
  }

  String _getFormatForDataType(String dataType) {
    switch (dataType) {
      case 'RINEX':
        return 'RINEX 3.04';
      case 'Orbit':
        return 'SP3';
      case 'Clock':
        return 'CLK';
      case 'Ephemeris':
        return 'NAV';
      case 'Ionosphere':
        return 'ION';
      default:
        return 'Binary';
    }
  }

  // Download methods
  Future<void> downloadFile(SearchResult result) async {
    if (!_isAuthenticated) {
      throw Exception('Not authenticated. Please login first.');
    }

    final downloadItem = DownloadItem(
      id: result.id,
      title: result.title,
      fileName: '${result.id}.dat',
      fileSize: result.fileSize,
      status: DownloadStatus.downloading,
      progress: 0.0,
      startTime: DateTime.now(),
      url: result.downloadUrl,
      dataType: result.dataType,
    );

    _downloads.insert(0, downloadItem);
    _isDownloading = true;
    notifyListeners();

    try {
      // Mock download progress
      for (int progress = 0; progress <= 100; progress += 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        
        final index = _downloads.indexWhere((d) => d.id == downloadItem.id);
        if (index >= 0) {
          _downloads[index] = _downloads[index].copyWith(
            progress: progress / 100.0,
            status: progress == 100 ? DownloadStatus.completed : DownloadStatus.downloading,
          );
          notifyListeners();
        }
      }

      // Save mock file
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${downloadItem.fileName}');
      await file.writeAsString(_generateMockFileContent(result));

      final index = _downloads.indexWhere((d) => d.id == downloadItem.id);
      if (index >= 0) {
        _downloads[index] = _downloads[index].copyWith(
          status: DownloadStatus.completed,
          filePath: file.path,
          endTime: DateTime.now(),
        );
      }
    } catch (e) {
      final index = _downloads.indexWhere((d) => d.id == downloadItem.id);
      if (index >= 0) {
        _downloads[index] = _downloads[index].copyWith(
          status: DownloadStatus.failed,
          error: e.toString(),
        );
      }
    } finally {
      _isDownloading = _downloads.any((d) => d.status == DownloadStatus.downloading);
      notifyListeners();
    }
  }

  String _generateMockFileContent(SearchResult result) {
    switch (result.dataType) {
      case 'RINEX':
        return '''RINEX VERSION / TYPE         3.04           OBSERVATION DATA    M
PGM / RUN BY / DATE         TEQC  2019Feb25 UNAVCO              
MARKER NAME                 ${result.stationId}                                
MARKER NUMBER               40104M001                           
OBSERVER / AGENCY           NASA            NASA                
REC # / TYPE / VERS         7400068-00      SEPT POLARX5        
ANT # / TYPE                CR620017101     TRM59800.00     NONE
APPROX POSITION XYZ         918129.3432  -4346071.3976   4561977.8676
ANTENNA: DELTA H/E/N        0.0000   0.0000   0.0000            
SYS / # / OBS TYPES    G   12 C1C L1C D1C S1C C2P L2P D2P S2P C2W L2W D2W S2W
SYS / # / OBS TYPES    R   12 C1C L1C D1C S1C C1P L1P D1P S1P C2P L2P D2P S2P
INTERVAL                     30.000                             
TIME OF FIRST OBS      2019  2 25  0  0  0.0000000     GPS         
END OF HEADER                                                   
> 2019  2 25  0  0  0.0000000  0 12      0.000000000000
G01  22123456.123  116345678.123     -1234.123        45.123
G02  23456789.456  123456789.456      2345.456        47.456
...''';
      
      case 'Orbit':
        return '''#aP2019  2 25  0  0  0.00000000    96 ORBIT IGS14 HLM  IGS
## 1950  7  1  0  0  0.00000000
+    32   G01G02G03G04G05G06G07G08G09G10G11G12G13G14G15G16
+          G17G18G19G20G21G22G23G24G25G26G27G28G29G30G31G32
++        32  5  5  5  5  5  5  5  5  5  5  5  5  5  5  5  5
++         5  5  5  5  5  5  5  5  5  5  5  5  5  5  5  5
%c G  cc GPS ccc cccc cccc cccc cccc ccccc ccccc ccccc ccccc
%c cc cc ccc ccc cccc cccc cccc cccc ccccc ccccc ccccc ccccc
%f  1.2500000  1.025000000  0.00000000000  0.000000000000000
%f  0.0000000  0.000000000  0.00000000000  0.000000000000000
%i    0    0    0    0      0      0      0      0         0
%i    0    0    0    0      0      0      0      0         0
/*
*  2019  2 25  0  0  0.00000000
PG01 -12345678.123456  -23456789.234567   12345678.345678    123.456789
PG02  12345678.123456   23456789.234567  -12345678.345678   -123.456789
...''';
      
      default:
        return '''NASA GNSS ${result.dataType} Data
Station: ${result.stationId}
Date: ${result.date.toIso8601String().split('T')[0]}
Format: ${result.format}

[Binary data would be here in a real file]

Data quality: Good
Processing center: NASA/JPL
Reference frame: IGS14
''';
    }
  }

  // Viewer methods
  Future<void> openFile(DownloadItem downloadItem) async {
    if (downloadItem.filePath == null) {
      throw Exception('File not available');
    }

    _selectedFile = downloadItem;
    
    try {
      final file = File(downloadItem.filePath!);
      if (await file.exists()) {
        _fileContent = await file.readAsString();
      } else {
        _fileContent = 'File not found';
      }
    } catch (e) {
      _fileContent = 'Error reading file: $e';
    }
    
    notifyListeners();
  }

  void closeFile() {
    _selectedFile = null;
    _fileContent = '';
    notifyListeners();
  }

  // Delete download
  void deleteDownload(String id) {
    _downloads.removeWhere((d) => d.id == id);
    if (_selectedFile?.id == id) {
      _selectedFile = null;
      _fileContent = '';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authService.dispose();
    super.dispose();
  }
}

class SearchResult {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String dataType;
  final String stationId;
  final String fileSize;
  final String format;
  final String downloadUrl;

  const SearchResult({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.dataType,
    required this.stationId,
    required this.fileSize,
    required this.format,
    required this.downloadUrl,
  });
}

class DownloadItem {
  final String id;
  final String title;
  final String fileName;
  final String fileSize;
  final DownloadStatus status;
  final double progress;
  final DateTime startTime;
  final DateTime? endTime;
  final String? filePath;
  final String? error;
  final String url;
  final String dataType;

  const DownloadItem({
    required this.id,
    required this.title,
    required this.fileName,
    required this.fileSize,
    required this.status,
    required this.progress,
    required this.startTime,
    this.endTime,
    this.filePath,
    this.error,
    required this.url,
    required this.dataType,
  });

  DownloadItem copyWith({
    String? id,
    String? title,
    String? fileName,
    String? fileSize,
    DownloadStatus? status,
    double? progress,
    DateTime? startTime,
    DateTime? endTime,
    String? filePath,
    String? error,
    String? url,
    String? dataType,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      filePath: filePath ?? this.filePath,
      error: error ?? this.error,
      url: url ?? this.url,
      dataType: dataType ?? this.dataType,
    );
  }
}

enum DownloadStatus {
  downloading,
  completed,
  failed,
}
