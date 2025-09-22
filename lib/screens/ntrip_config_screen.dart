import 'package:flutter/material.dart';
import '../services/ntrip_client_service.dart';
import '../services/earthdata_auth_service.dart';

class NtripConfigScreen extends StatefulWidget {
  const NtripConfigScreen({super.key});

  @override
  State<NtripConfigScreen> createState() => _NtripConfigScreenState();
}

class _NtripConfigScreenState extends State<NtripConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController(text: 'caster.cddis.eosdis.nasa.gov');
  final _portController = TextEditingController(text: '443');
  final _mountpointController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isConnecting = false;
  bool _isConnected = false;
  String _connectionStatus = 'Disconnected';
  String _lastError = '';

  // Real-time data values
  double? _latitude;
  double? _longitude;
  double? _altitude;
  int? _satelliteCount;
  DateTime? _lastUpdate;

  final NtripClientService _ntripService = NtripClientService();
  final EarthdataAuthService _authService = EarthdataAuthService();

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _loadSavedCredentials();
  }

  void _setupListeners() {
    // Listen to connection status
    _ntripService.connectionStatus.listen((status) {
      if (mounted) {
        setState(() {
          _connectionStatus = status;
          _isConnected = _ntripService.isConnected;
          _isConnecting = false;
          
          if (!_isConnected && status.contains('error')) {
            _lastError = status;
          } else {
            _lastError = '';
          }
        });
      }
    });

    // Listen to station updates for real-time data
    _ntripService.stationUpdates.listen((station) {
      if (mounted) {
        setState(() {
          _latitude = station.latitude;
          _longitude = station.longitude;
          _altitude = station.elevation;
          _satelliteCount = station.satelliteCount;
          _lastUpdate = station.updatedAt;
        });
      }
    });
  }

  Future<void> _loadSavedCredentials() async {
    // Load credentials from auth service if authenticated
    if (_authService.isAuthenticated) {
      final credentials = await _authService.getNtripCredentials();
      if (credentials != null) {
        setState(() {
          _mountpointController.text = 'SSRA00BKG1'; // NASA orbit corrections
          _usernameController.text = credentials['username'] ?? '';
          _passwordController.text = credentials['password'] ?? '';
        });
        return;
      }
    }
    
    // Load default values if not authenticated
    setState(() {
      _mountpointController.text = 'RTCM3EPH'; // Most accessible stream
      _usernameController.text = '';
      _passwordController.text = '';
    });
  }

  Future<void> _toggleConnection() async {
    if (_isConnected) {
      // Disconnect
      _ntripService.disconnect();
      setState(() {
        _isConnected = false;
        _connectionStatus = 'Disconnected';
        _latitude = null;
        _longitude = null;
        _altitude = null;
        _satelliteCount = null;
        _lastUpdate = null;
      });
    } else {
      // Connect
      if (!_formKey.currentState!.validate()) return;

      setState(() {
        _isConnecting = true;
        _connectionStatus = 'Connecting...';
        _lastError = '';
      });

      // Pass endpoint to service
      final host = _hostController.text.trim();
      final port = int.tryParse(_portController.text.trim()) ?? 443;
      _ntripService.setEndpoint(host: host, port: port);

      final success = await _ntripService.connect(
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        mountPoint: _mountpointController.text.trim(),
      );

      if (!success) {
        setState(() {
          _isConnecting = false;
          _connectionStatus = 'Connection failed';
          _lastError = 'Failed to connect to NTRIP caster';
        });
      }
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _mountpointController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('NTRIP Configuration'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withOpacity(0.1),
              theme.colorScheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // NASA CDDIS Info Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.satellite_alt,
                              color: theme.colorScheme.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'NASA CDDIS Real-Time GNSS',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Connect to NASA\'s Crustal Dynamics Data Information System (CDDIS) for real-time GNSS data via NTRIP protocol.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),

                // Configuration Form
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NTRIP Server Configuration',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Host
                          TextFormField(
                            controller: _hostController,
                            decoration: InputDecoration(
                              labelText: 'Host',
                              hintText: 'caster.cddis.eosdis.nasa.gov',
                              prefixIcon: const Icon(Icons.dns),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a host';
                              }
                              return null;
                            },
                            enabled: !_isConnected,
                          ),
                          const SizedBox(height: 12),
                          
                          // Port
                          TextFormField(
                            controller: _portController,
                            decoration: InputDecoration(
                              labelText: 'Port',
                              hintText: '443',
                              prefixIcon: const Icon(Icons.settings_ethernet),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a port';
                              }
                              final port = int.tryParse(value);
                              if (port == null || port <= 0 || port > 65535) {
                                return 'Please enter a valid port (1-65535)';
                              }
                              return null;
                            },
                            enabled: !_isConnected,
                          ),
                          const SizedBox(height: 12),
                          
                          // Mountpoint
                          TextFormField(
                            controller: _mountpointController,
                            decoration: InputDecoration(
                              labelText: 'Mountpoint',
                              hintText: 'RTCM3EPH',
                              prefixIcon: const Icon(Icons.router),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a mountpoint';
                              }
                              return null;
                            },
                            enabled: !_isConnected,
                          ),
                          const SizedBox(height: 12),
                          
                          // Username
                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              hintText: 'NASA Earthdata username',
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your username';
                              }
                              return null;
                            },
                            enabled: !_isConnected,
                          ),
                          const SizedBox(height: 12),
                          
                          // Password
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'NASA Earthdata password',
                              prefixIcon: const Icon(Icons.lock),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                            enabled: !_isConnected,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),

                // Connect Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isConnecting ? null : _toggleConnection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isConnected 
                        ? theme.colorScheme.error 
                        : theme.colorScheme.primary,
                      foregroundColor: _isConnected 
                        ? theme.colorScheme.onError 
                        : theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: _isConnecting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : Icon(_isConnected ? Icons.stop : Icons.play_arrow),
                    label: Text(
                      _isConnecting 
                        ? 'Connecting...' 
                        : _isConnected 
                          ? 'Disconnect' 
                          : 'Connect',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),

                // Connection Status
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isConnected 
                                ? Icons.check_circle 
                                : _lastError.isNotEmpty 
                                  ? Icons.error 
                                  : Icons.radio_button_unchecked,
                              color: _isConnected 
                                ? Colors.green 
                                : _lastError.isNotEmpty 
                                  ? Colors.red 
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Connection Status',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _connectionStatus,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _isConnected 
                              ? Colors.green 
                              : _lastError.isNotEmpty 
                                ? Colors.red 
                                : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_lastError.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _lastError,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),

                // Real-time Data Display
                if (_isConnected) ...[
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.sensors,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Real-time GNSS Data',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          _buildDataRow('Latitude', 
                            _latitude != null ? '${_latitude!.toStringAsFixed(6)}°' : 'No data'),
                          _buildDataRow('Longitude', 
                            _longitude != null ? '${_longitude!.toStringAsFixed(6)}°' : 'No data'),
                          _buildDataRow('Altitude', 
                            _altitude != null ? '${_altitude!.toStringAsFixed(2)} m' : 'No data'),
                          _buildDataRow('Satellites', 
                            _satelliteCount != null ? '$_satelliteCount' : 'No data'),
                          
                          if (_lastUpdate != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Last update: ${_formatTime(_lastUpdate!)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
           '${time.minute.toString().padLeft(2, '0')}:'
           '${time.second.toString().padLeft(2, '0')}';
  }
}
