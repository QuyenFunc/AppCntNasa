import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';

class ThemeProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  
  bool _isDarkMode = false;
  Color _primaryColor = const Color(0xFF1976D2); // NASA blue
  
  bool get isDarkMode => _isDarkMode;
  Color get primaryColor => _primaryColor;

  // Initialize theme from saved preferences
  Future<void> initialize() async {
    await _loadThemePreferences();
  }

  // Load theme preferences from database
  Future<void> _loadThemePreferences() async {
    try {
      final isDarkModeString = await _databaseService.getPreference('dark_mode');
      if (isDarkModeString != null) {
        _isDarkMode = isDarkModeString.toLowerCase() == 'true';
      }

      final primaryColorString = await _databaseService.getPreference('primary_color');
      if (primaryColorString != null) {
        _primaryColor = Color(int.parse(primaryColorString));
      }

      _updateSystemUI();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme preferences: $e');
    }
  }

  // Toggle dark mode
  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    await _saveThemePreferences();
    _updateSystemUI();
    notifyListeners();
  }

  // Set dark mode
  Future<void> setDarkMode(bool isDarkMode) async {
    if (_isDarkMode != isDarkMode) {
      _isDarkMode = isDarkMode;
      await _saveThemePreferences();
      _updateSystemUI();
      notifyListeners();
    }
  }

  // Set primary color
  Future<void> setPrimaryColor(Color color) async {
    if (_primaryColor != color) {
      _primaryColor = color;
      await _saveThemePreferences();
      notifyListeners();
    }
  }

  // Save theme preferences to database
  Future<void> _saveThemePreferences() async {
    try {
      await _databaseService.savePreference('dark_mode', _isDarkMode.toString());
      await _databaseService.savePreference('primary_color', _primaryColor.value.toString());
    } catch (e) {
      debugPrint('Error saving theme preferences: $e');
    }
  }

  // Update system UI overlay style
  void _updateSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _isDarkMode ? Brightness.light : Brightness.dark,
        statusBarBrightness: _isDarkMode ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: _isDarkMode ? const Color(0xFF121212) : Colors.white,
        systemNavigationBarIconBrightness: _isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );
  }

  // Get light theme
  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  // Get dark theme
  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Color(0xFF1E1E1E),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
      ),
    );
  }

  // Get current theme
  ThemeData get currentTheme => _isDarkMode ? darkTheme : lightTheme;

  // Predefined color options for customization
  static const List<Color> colorOptions = [
    Color(0xFF1976D2), // NASA Blue
    Color(0xFFE53935), // Red
    Color(0xFF43A047), // Green
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFF00ACC1), // Cyan
    Color(0xFF5D4037), // Brown
    Color(0xFF607D8B), // Blue Grey
  ];

  // Get color name for UI display
  String getColorName(Color color) {
    switch (color.value) {
      case 0xFF1976D2:
        return 'NASA Blue';
      case 0xFFE53935:
        return 'Red';
      case 0xFF43A047:
        return 'Green';
      case 0xFFFF9800:
        return 'Orange';
      case 0xFF9C27B0:
        return 'Purple';
      case 0xFF00ACC1:
        return 'Cyan';
      case 0xFF5D4037:
        return 'Brown';
      case 0xFF607D8B:
        return 'Blue Grey';
      default:
        return 'Custom';
    }
  }

  // Reset to default theme
  Future<void> resetToDefault() async {
    _isDarkMode = false;
    _primaryColor = const Color(0xFF1976D2);
    await _saveThemePreferences();
    _updateSystemUI();
    notifyListeners();
  }
}
