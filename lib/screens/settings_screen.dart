import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/gnss_provider.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/ntrip_client_service.dart';
import '../services/earthdata_auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();
  final NtripClientService _ntripService = NtripClientService();
  final EarthdataAuthService _authService = EarthdataAuthService();
  
  bool _notificationsEnabled = true;
  double _accuracyThreshold = 5.0;
  bool _isNtripConnected = false;
  String _ntripStatus = 'Disconnected';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _setupNtripListener();
  }

  Future<void> _loadSettings() async {
    final enabled = await _notificationService.areNotificationsEnabled();
    setState(() {
      _notificationsEnabled = enabled;
      _isNtripConnected = _ntripService.isConnected;
    });
  }

  void _setupNtripListener() {
    _ntripService.connectionStatus.listen((status) {
      if (mounted) {
        setState(() {
          _ntripStatus = status;
          _isNtripConnected = _ntripService.isConnected;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer2<ThemeProvider, GnssProvider>(
        builder: (context, themeProvider, gnssProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // App Settings Section
              _buildSectionHeader('App Settings'),
              _buildSettingsCard([
                SwitchListTile(
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Toggle dark/light theme'),
                  value: themeProvider.isDarkMode,
                  onChanged: (value) => themeProvider.setDarkMode(value),
                  secondary: Icon(
                    themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  ),
                ),
                ListTile(
                  title: const Text('Theme Color'),
                  subtitle: Text('Current: ${themeProvider.getColorName(themeProvider.primaryColor)}'),
                  leading: Icon(
                    Icons.palette,
                    color: themeProvider.primaryColor,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showColorPicker(themeProvider),
                ),
              ]),

              const SizedBox(height: 20),

              // GNSS Settings Section
              _buildSectionHeader('GNSS Settings'),
              _buildSettingsCard([
                ListTile(
                  title: const Text('Accuracy Threshold'),
                  subtitle: Text('${_accuracyThreshold.toStringAsFixed(1)}m - Warning above this value'),
                  leading: const Icon(Icons.gps_fixed),
                  trailing: SizedBox(
                    width: 100,
                    child: Slider(
                      value: _accuracyThreshold,
                      min: 1.0,
                      max: 20.0,
                      divisions: 19,
                      onChanged: (value) {
                        setState(() {
                          _accuracyThreshold = value;
                        });
                        gnssProvider.setAccuracyThreshold(value);
                      },
                    ),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Auto Refresh'),
                  subtitle: const Text('Automatically update station data'),
                  value: false, // Would be connected to a setting
                  onChanged: (value) {
                    // Implement auto refresh toggle
                    _showSnackBar('Auto refresh ${value ? 'enabled' : 'disabled'}');
                  },
                  secondary: const Icon(Icons.refresh),
                ),
              ]),

              const SizedBox(height: 20),

              // Real-time Data Connection Section
              _buildSectionHeader('Real-time Data'),
              _buildSettingsCard([
                ListTile(
                  title: const Text('NASA CDDIS Connection'),
                  subtitle: Text(_ntripStatus),
                  leading: Icon(
                    Icons.satellite_alt,
                    color: _isNtripConnected ? Colors.green : Colors.grey,
                  ),
                  trailing: ElevatedButton(
                    onPressed: _isNtripConnected ? _disconnectNtrip : _connectNtrip,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isNtripConnected ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(80, 36),
                    ),
                    child: Text(_isNtripConnected ? 'Disconnect' : 'Connect'),
                  ),
                ),
                if (_authService.isAuthenticated)
                  ListTile(
                    title: const Text('Authentication Status'),
                    subtitle: Text('Logged in as ${_authService.userProfile?['uid'] ?? 'Unknown'}'),
                    leading: const Icon(Icons.verified_user, color: Colors.green),
                  ),
                ListTile(
                  title: const Text('NTRIP Configuration'),
                  subtitle: const Text('Configure connection settings'),
                  leading: const Icon(Icons.settings),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(context, '/ntrip_config'),
                ),
              ]),

              const SizedBox(height: 20),

              // Notification Settings Section
              _buildSectionHeader('Notifications'),
              _buildSettingsCard([
                SwitchListTile(
                  title: const Text('Enable Notifications'),
                  subtitle: const Text('Receive accuracy warnings'),
                  value: _notificationsEnabled,
                  onChanged: (value) async {
                    if (value) {
                      final granted = await _notificationService.requestNotificationPermission();
                      setState(() {
                        _notificationsEnabled = granted;
                      });
                      if (!granted) {
                        _showPermissionDialog();
                      }
                    } else {
                      setState(() {
                        _notificationsEnabled = false;
                      });
                    }
                  },
                  secondary: const Icon(Icons.notifications),
                ),
                if (_notificationsEnabled)
                  ListTile(
                    title: const Text('Notification Settings'),
                    subtitle: const Text('Configure system notification preferences'),
                    leading: const Icon(Icons.settings_applications),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _notificationService.openNotificationSettings(),
                  ),
              ]),

              const SizedBox(height: 20),

              // Real-time Data Section
              _buildSectionHeader('Real-time Data'),
              _buildSettingsCard([
                ListTile(
                  title: const Text('NTRIP Configuration'),
                  subtitle: const Text('Configure NASA CDDIS connection'),
                  leading: const Icon(Icons.satellite_alt),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(context, '/ntrip-config'),
                ),
              ]),

              const SizedBox(height: 20),

              // Data Management Section
              _buildSectionHeader('Data Management'),
              _buildSettingsCard([
                ListTile(
                  title: const Text('Export All Data'),
                  subtitle: const Text('Export stations to CSV/JSON'),
                  leading: const Icon(Icons.file_download),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportAllData(gnssProvider),
                ),
                ListTile(
                  title: const Text('Database Statistics'),
                  subtitle: const Text('View storage usage'),
                  leading: const Icon(Icons.storage),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showDatabaseStats(),
                ),
                ListTile(
                  title: const Text('Clear Cache'),
                  subtitle: const Text('Remove all cached data'),
                  leading: const Icon(Icons.clear_all),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _confirmClearCache(),
                ),
              ]),

              const SizedBox(height: 20),

              // About Section
              _buildSectionHeader('About'),
              _buildSettingsCard([
                const ListTile(
                  title: Text('NASA GNSS Client'),
                  subtitle: Text('Version 1.0.0'),
                  leading: Icon(Icons.info),
                ),
                ListTile(
                  title: const Text('Privacy Policy'),
                  leading: const Icon(Icons.privacy_tip),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showPrivacyPolicy(),
                ),
                ListTile(
                  title: const Text('Open Source Licenses'),
                  leading: const Icon(Icons.code),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showLicenses(),
                ),
              ]),

              const SizedBox(height: 40),

              // Reset button
              Center(
                child: TextButton.icon(
                  onPressed: () => _confirmResetSettings(themeProvider),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset All Settings'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      child: Column(
        children: children.map((child) {
          final isLast = child == children.last;
          return Column(
            children: [
              child,
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Future<void> _connectNtrip() async {
    if (!_authService.isAuthenticated) {
      _showSnackBar('❌ Please login with JWT token first to access NASA CDDIS real data');
      return;
    }

    try {
      final credentials = await _authService.getNtripCredentials();
      if (credentials == null) {
        _showSnackBar('Could not get NTRIP credentials');
        return;
      }

      final connected = await _ntripService.connect(
        username: credentials['username']!,
        password: credentials['password']!,
        mountPoint: 'RTCM3EPH', // Broadly accessible
      );

      if (connected) {
        _showSnackBar('✅ Connected to NASA CDDIS - Real RTCM data stream active');
      } else {
        _showSnackBar('❌ Failed to connect to NASA CDDIS - Check credentials');
      }
    } catch (e) {
      _showSnackBar('Connection error: $e');
    }
  }

  void _disconnectNtrip() {
    _ntripService.disconnect();
    _showSnackBar('Disconnected from NASA CDDIS');
  }

  void _showColorPicker(ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme Color'),
        content: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: ThemeProvider.colorOptions.map((color) {
            final isSelected = color == themeProvider.primaryColor;
            return GestureDetector(
              onTap: () {
                themeProvider.setPrimaryColor(color);
                Navigator.pop(context);
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected 
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Permission'),
        content: const Text(
          'To receive accuracy warnings, please enable notifications in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _notificationService.openNotificationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAllData(GnssProvider gnssProvider) async {
    // This would open the export dialog
    _showSnackBar('Export feature available in Stations tab');
  }

  Future<void> _showDatabaseStats() async {
    try {
      final stats = await _databaseService.getDatabaseStats();
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Database Statistics'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatRow('Stations', '${stats['stations']}'),
              _buildStatRow('Accuracy Points', '${stats['accuracy_points']}'),
              _buildStatRow('Cache Stations', '${stats['hive_stations']}'),
              _buildStatRow('Cache Points', '${stats['hive_accuracy']}'),
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
    } catch (e) {
      _showSnackBar('Error loading database stats: $e');
    }
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

  void _confirmClearCache() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will remove all cached station data. The app will need to fetch fresh real-time data from NASA CDDIS and IGS Global Network.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _databaseService.clearAllData();
              _showSnackBar('Cache cleared successfully');
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.red,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _confirmResetSettings(ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'This will reset all app settings to their default values.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await themeProvider.resetToDefault();
              setState(() {
                _accuracyThreshold = 5.0;
                _notificationsEnabled = true;
              });
              _showSnackBar('Settings reset to defaults');
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.red,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'NASA GNSS Client Privacy Policy\n\n'
            'This app collects and processes GNSS station data from NASA\'s public APIs. '
            'No personal information is collected or stored. All data is used solely for '
            'displaying satellite positioning information.\n\n'
            'The app may store data locally on your device for offline access and performance. '
            'This data can be cleared at any time through the app settings.\n\n'
            'For more information about NASA\'s data policies, please visit nasa.gov.',
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

  void _showLicenses() {
    showLicensePage(
      context: context,
      applicationName: 'NASA GNSS Client',
      applicationVersion: '1.0.0',
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
