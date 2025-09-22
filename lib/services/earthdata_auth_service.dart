import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'database_service.dart';

class EarthdataAuthService {
  static final EarthdataAuthService _instance = EarthdataAuthService._internal();
  factory EarthdataAuthService() => _instance;
  EarthdataAuthService._internal();

  final DatabaseService _databaseService = DatabaseService();
  
  // NASA Earthdata Login endpoints
  static const String baseUrl = 'https://urs.earthdata.nasa.gov';
  static const String tokenUrl = '$baseUrl/oauth/token';
  static const String authorizeUrl = '$baseUrl/oauth/authorize';
  static const String profileUrl = '$baseUrl/api/users/user';
  
  // Client credentials for NASA GNSS Client
  // Note: In production, these should be stored securely
  static const String clientId = 'your_nasa_client_id';
  static const String clientSecret = 'your_nasa_client_secret';
  static const String redirectUri = 'com.example.nasa_gnss_client://oauth';
  
  // Authentication state
  bool _isAuthenticated = false;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  Map<String, dynamic>? _userProfile;
  
  // Stream controller for auth state changes
  final StreamController<bool> _authStateController = 
      StreamController<bool>.broadcast();
  
  Stream<bool> get authStateChanges => _authStateController.stream;
  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get userProfile => _userProfile;
  
  // Initialize authentication service
  Future<void> initialize() async {
    await _loadStoredCredentials();
    if (_isAuthenticated && _isTokenValid()) {
      await _loadUserProfile();
    }
    debugPrint('Earthdata Auth Service initialized');
  }
  
  // Load stored credentials from database
  Future<void> _loadStoredCredentials() async {
    try {
      _accessToken = await _databaseService.getPreference('earthdata_access_token');
      _refreshToken = await _databaseService.getPreference('earthdata_refresh_token');
      
      final expiryString = await _databaseService.getPreference('earthdata_token_expiry');
      if (expiryString != null) {
        _tokenExpiry = DateTime.parse(expiryString);
      }
      
      _isAuthenticated = _accessToken != null && _isTokenValid();
      _authStateController.add(_isAuthenticated);
      
    } catch (e) {
      debugPrint('Error loading stored credentials: $e');
      _isAuthenticated = false;
    }
  }
  
  // Save credentials to database
  Future<void> _saveCredentials() async {
    try {
      if (_accessToken != null) {
        await _databaseService.savePreference('earthdata_access_token', _accessToken!);
      }
      if (_refreshToken != null) {
        await _databaseService.savePreference('earthdata_refresh_token', _refreshToken!);
      }
      if (_tokenExpiry != null) {
        await _databaseService.savePreference('earthdata_token_expiry', _tokenExpiry!.toIso8601String());
      }
    } catch (e) {
      debugPrint('Error saving credentials: $e');
    }
  }
  
  // Check if current token is valid
  bool _isTokenValid() {
    if (_accessToken == null || _tokenExpiry == null) return false;
    return DateTime.now().isBefore(_tokenExpiry!.subtract(const Duration(minutes: 5)));
  }
  
  // Login with existing JWT token
  Future<bool> loginWithJwt(String jwtToken) async {
    try {
      debugPrint('Attempting to login with JWT token...');
      
      // Parse JWT token to extract user information
      final parts = jwtToken.split('.');
      if (parts.length != 3) {
        throw Exception('Invalid JWT token format');
      }
      
      // Decode payload (second part of JWT)
      final payload = parts[1];
      // Add padding if needed for base64 decoding
      String normalizedPayload = payload;
      switch (payload.length % 4) {
        case 2:
          normalizedPayload += '==';
          break;
        case 3:
          normalizedPayload += '=';
          break;
      }
      
      final payloadBytes = base64.decode(normalizedPayload);
      final payloadJson = json.decode(utf8.decode(payloadBytes));
      
      debugPrint('JWT payload: $payloadJson');
      
      // Check if token is still valid
      final exp = payloadJson['exp'];
      if (exp != null) {
        final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        if (DateTime.now().isAfter(expiryDate)) {
          throw Exception('JWT token has expired');
        }
        _tokenExpiry = expiryDate;
      }
      
      // Extract user information
      final uid = payloadJson['uid'];
      if (uid == null) {
        throw Exception('JWT token does not contain user ID');
      }
      
      // Set authentication state
      _accessToken = jwtToken;
      _isAuthenticated = true;
      
      // Set user profile from JWT payload
      _userProfile = {
        'uid': uid,
        'first_name': payloadJson['first_name'] ?? uid,
        'last_name': payloadJson['last_name'] ?? 'User',
        'email': payloadJson['email'] ?? '$uid@earthdata.nasa.gov',
        'identity_provider': payloadJson['identity_provider'] ?? 'edl_ops',
      };
      
      // Save credentials
      await _saveCredentials();
      
      _authStateController.add(true);
      debugPrint('JWT login successful for user: $uid');
      debugPrint('Token expires: $_tokenExpiry');
      
      return true;
      
    } catch (e) {
      debugPrint('JWT login error: $e');
      return false;
    }
  }

  // Login with username and password
  Future<bool> login(String username, String password) async {
    try {
      debugPrint('Attempting to login to NASA Earthdata...');
      
      // For demo purposes, simulate successful login
      // Real implementation would use proper OAuth2 flow
      if (username.isNotEmpty && password.isNotEmpty) {
        // Simulate successful authentication
        _accessToken = 'demo_access_token_${DateTime.now().millisecondsSinceEpoch}';
        _refreshToken = 'demo_refresh_token_${DateTime.now().millisecondsSinceEpoch}';
        _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
        _isAuthenticated = true;
        
        // Set demo user profile
        _userProfile = {
          'uid': username,
          'first_name': 'Demo',
          'last_name': 'User',
          'email': '$username@demo.nasa.gov',
        };
        
        // Save credentials
        await _saveCredentials();
        
        _authStateController.add(true);
        debugPrint('Demo login successful for user: $username');
        
        return true;
      }
      
      // If empty credentials, attempt real API call
      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic ${base64.encode(utf8.encode('$clientId:$clientSecret'))}',
        },
        body: {
          'grant_type': 'password',
          'username': username,
          'password': password,
          'scope': 'read',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        
        // Calculate token expiry
        final expiresIn = data['expires_in'] ?? 3600; // Default 1 hour
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
        
        _isAuthenticated = true;
        
        // Save credentials
        await _saveCredentials();
        
        // Load user profile
        await _loadUserProfile();
        
        _authStateController.add(true);
        debugPrint('Successfully logged in to NASA Earthdata');
        
        return true;
        
      } else {
        // Handle error response
        debugPrint('Login failed with status ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        
        if (response.body.contains('Access denied')) {
          throw Exception('Access denied. Please check your NASA Earthdata credentials.');
        }
        
        try {
          final errorData = json.decode(response.body);
          debugPrint('Login failed: ${errorData['error_description'] ?? 'Unknown error'}');
        } catch (e) {
          debugPrint('Login failed: HTTP ${response.statusCode}');
        }
        return false;
      }
      
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }
  
  // Refresh access token using refresh token
  Future<bool> refreshToken() async {
    if (_refreshToken == null) return false;
    
    try {
      debugPrint('Refreshing NASA Earthdata token...');
      
      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic ${base64.encode(utf8.encode('$clientId:$clientSecret'))}',
        },
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': _refreshToken!,
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        _accessToken = data['access_token'];
        if (data['refresh_token'] != null) {
          _refreshToken = data['refresh_token'];
        }
        
        final expiresIn = data['expires_in'] ?? 3600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
        
        await _saveCredentials();
        debugPrint('Token refreshed successfully');
        return true;
        
      } else {
        debugPrint('Token refresh failed: ${response.statusCode}');
        await logout();
        return false;
      }
      
    } catch (e) {
      debugPrint('Token refresh error: $e');
      return false;
    }
  }
  
  // Load user profile from NASA Earthdata
  Future<void> _loadUserProfile() async {
    if (!_isAuthenticated || _accessToken == null) return;
    
    try {
      final response = await http.get(
        Uri.parse(profileUrl),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        _userProfile = json.decode(response.body);
        debugPrint('User profile loaded: ${_userProfile?['first_name']} ${_userProfile?['last_name']}');
      } else {
        debugPrint('Failed to load user profile: ${response.statusCode}');
      }
      
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }
  
  // Get valid access token (refresh if needed)
  Future<String?> getValidAccessToken() async {
    if (!_isAuthenticated) return null;
    
    if (!_isTokenValid()) {
      final refreshed = await refreshToken();
      if (!refreshed) return null;
    }
    
    return _accessToken;
  }
  
  // Get authentication headers for API requests
  Future<Map<String, String>?> getAuthHeaders() async {
    final token = await getValidAccessToken();
    if (token == null) return null;
    
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }
  
  // Get credentials for NTRIP authentication
  Future<Map<String, String>?> getNtripCredentials() async {
    if (!_isAuthenticated || _userProfile == null) return null;
    
    // For NTRIP, NASA typically uses the Earthdata username
    final username = _userProfile?['uid'];
    if (username == null) return null;
    
    // The access token can be used as password for NTRIP
    final token = await getValidAccessToken();
    if (token == null) return null;
    
    return {
      'username': username,
      'password': token,
    };
  }
  
  // Logout and clear stored credentials
  Future<void> logout() async {
    _isAuthenticated = false;
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;
    _userProfile = null;
    
    // Clear stored credentials
    await _databaseService.savePreference('earthdata_access_token', '');
    await _databaseService.savePreference('earthdata_refresh_token', '');
    await _databaseService.savePreference('earthdata_token_expiry', '');
    
    _authStateController.add(false);
    debugPrint('Logged out from NASA Earthdata');
  }
  
  // Check if user has required permissions for GNSS data
  Future<bool> hasGnssDataPermissions() async {
    // This would typically check user's permissions/subscriptions
    // For now, assume all authenticated users have access
    return _isAuthenticated;
  }
  
  // Get authentication status info
  Map<String, dynamic> getAuthInfo() {
    return {
      'isAuthenticated': _isAuthenticated,
      'hasValidToken': _isTokenValid(),
      'tokenExpiry': _tokenExpiry?.toIso8601String(),
      'username': _userProfile?['uid'],
      'displayName': _userProfile != null 
          ? '${_userProfile!['first_name']} ${_userProfile!['last_name']}'
          : null,
    };
  }
  
  // Dispose resources
  void dispose() {
    _authStateController.close();
  }
}
