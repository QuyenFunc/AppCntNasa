import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ntrip_client.dart';
import '../providers/realtime_provider.dart';

class NtripConnectionPanel extends StatefulWidget {
  const NtripConnectionPanel({super.key});

  @override
  State<NtripConnectionPanel> createState() => _NtripConnectionPanelState();
}

class _NtripConnectionPanelState extends State<NtripConnectionPanel> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _mountpointController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isExpanded = false;
  String _selectedCaster = 'RTK2GO (Public)';
  
  // Common mountpoints for testing - these are typical patterns
  final List<String> _commonMountpoints = [
    'RTCM3_NEAR',
    'RTCM3',
    'RTCM32',
    'MSM5',
    'MSM4',
    'CMR',
    'CMR+',
    'DGPS',
    'RAW',
  ];
  
  // Predefined casters for quick testing
  final Map<String, Map<String, dynamic>> _casters = {
    'EarthScope': {
      'host': 'ntrip.earthscope.org',
      'port': 2101,
      'username': 'dazzling_stallman',
      'password': 'YP8Ae9Bb45cV0yOf',
      'mountpoints': ['P041_RTCM3', 'P042_RTCM3', 'P043_RTCM3', 'P044_RTCM3', 'P045_RTCM3'],
    },
    'RTK2GO (Public)': {
      'host': 'rtk2go.com',
      'port': 2101,
      'username': '',  // No auth required for receiving
      'password': '',
      'mountpoints': ['VTEC_Raspi', 'PNTS1', 'UBLOX_CASTER', 'NEYSTB', 'P1_RTCM3', 'TNSGPS', 'AZU1'],
    },
    'EUREF (Public Test)': {
      'host': 'www.euref-ip.net',
      'port': 2101,
      'username': '',
      'password': '',
      'mountpoints': ['EUREF-IP', 'DLF1', 'BKG1'],
    },
    'BKG Germany': {
      'host': 'igs-ip.net',
      'port': 2101,
      'username': '',
      'password': '',
      'mountpoints': ['FFMJ1', 'BRUX0', 'ONSA0', 'WTZR0'],
    },
  };

  @override
  void initState() {
    super.initState();
    // Initialize with default caster configuration
    _initializeDefaultCaster();
  }

  void _initializeDefaultCaster() {
    final config = _casters[_selectedCaster]!;
    _hostController.text = config['host'];
    _portController.text = config['port'].toString();
    _usernameController.text = config['username'];
    _passwordController.text = config['password'];
    // Set first mountpoint as default
    if ((config['mountpoints'] as List).isNotEmpty) {
      _mountpointController.text = config['mountpoints'][0];
    }
    print('🔧 Initialized with caster: $_selectedCaster, mountpoint: ${_mountpointController.text}');
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
    return Consumer<RealtimeProvider>(
      builder: (context, provider, child) {
        return Card(
          margin: const EdgeInsets.all(8.0),
          elevation: 2,
          child: Column(
            children: [
              // Compact status bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Connection status indicator
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: provider.isConnected ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Status text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.connectionStatus,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (provider.isConnected && provider.streamStats.isNotEmpty)
                            Text(
                              '${provider.streamStats['bitrateKbps']} kbps • ${provider.streamStats['frames']} frames',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    
                    // Connect/Disconnect button
                    if (provider.isConnecting)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      ElevatedButton(
                        onPressed: provider.isConnected
                            ? () {
                                print('🔴 Disconnect button pressed');
                                _disconnect(provider);
                              }
                            : () {
                                print('🟢 Connect button pressed');
                                _connect(provider);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: provider.isConnected ? Colors.red : Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(70, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(
                          provider.isConnected ? 'Disconnect' : 'Connect',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    
                    // Expand/Collapse button
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      icon: Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Expandable configuration form
              if (_isExpanded)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: const Border(
                      top: BorderSide(color: Colors.grey, width: 0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Quick caster selection
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.dns, color: Colors.blue[700], size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Quick Setup',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedCaster,
                              decoration: const InputDecoration(
                                labelText: 'Select NTRIP Caster',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: _casters.keys.map((name) {
                                return DropdownMenuItem(
                                  value: name,
                                  child: Text(name),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  print('🔄 Switching to caster: $value');
                                  setState(() {
                                    _selectedCaster = value;
                                    final config = _casters[value]!;
                                    _hostController.text = config['host'];
                                    _portController.text = config['port'].toString();
                                    _usernameController.text = config['username'];
                                    _passwordController.text = config['password'];
                                    // Set first mountpoint as default
                                    if ((config['mountpoints'] as List).isNotEmpty) {
                                      _mountpointController.text = config['mountpoints'][0];
                                    }
                                  });
                                  print('📍 Updated config - Host: ${_hostController.text}, Port: ${_portController.text}, Mountpoint: ${_mountpointController.text}');
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Host and Port row
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _hostController,
                              decoration: const InputDecoration(
                                labelText: 'Host',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _portController,
                              decoration: const InputDecoration(
                                labelText: 'Port',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Mountpoint with dropdown
                      TextFormField(
                        controller: _mountpointController,
                        decoration: InputDecoration(
                          labelText: 'Mountpoint',
                          isDense: true,
                          border: const OutlineInputBorder(),
                          hintText: 'Enter mountpoint or select from list',
                          suffixIcon: PopupMenuButton<String>(
                            icon: const Icon(Icons.arrow_drop_down),
                            onSelected: (value) {
                              _mountpointController.text = value;
                            },
                            itemBuilder: (context) {
                              final config = _casters[_selectedCaster];
                              final mountpoints = config?['mountpoints'] as List<String>? ?? _commonMountpoints;
                              return mountpoints
                                  .map((mp) => PopupMenuItem(
                                        value: mp,
                                        child: Text(mp),
                                      ))
                                  .toList();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Username and Password row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _usernameController,
                              decoration: const InputDecoration(
                                labelText: 'Username',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _passwordController,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              obscureText: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Action buttons
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: provider.isConnecting ? null : _getSourcetable,
                            icon: const Icon(Icons.list, size: 16),
                            label: const Text('Sourcetable', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: provider.isConnected ? _exportLog : null,
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('Export Log', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _connect(RealtimeProvider provider) async {
    print('🚀 Connect button pressed! Current status: ${provider.connectionStatus}');
    
    // Validate required fields
    final host = _hostController.text.trim();
    final portStr = _portController.text.trim();
    final mountpoint = _mountpointController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    
    print('📋 Connection params: $host:$portStr/$mountpoint (user: ${username.isEmpty ? 'none' : 'provided'})');
    
    if (host.isEmpty) {
      _showError('Host is required');
      return;
    }
    
    if (mountpoint.isEmpty) {
      _showError('Mountpoint is required');
      return;
    }
    
    // Only require credentials if the caster needs them
    // Some public casters don't require authentication
    if (_selectedCaster == 'EarthScope' && (username.isEmpty || password.isEmpty)) {
      _showError('Username and password are required for EarthScope NTRIP caster');
      return;
    }
    
    final port = int.tryParse(portStr);
    if (port == null) {
      _showError('Invalid port number');
      return;
    }
    
    try {
      // Validate mountpoint exists for EarthScope
      if (_selectedCaster == 'EarthScope') {
        print('🔍 Validating mountpoint $mountpoint on EarthScope...');
        final isValidMountpoint = await _validateMountpoint(host, port, username, password, mountpoint);
        if (!isValidMountpoint) {
          _showError('Mountpoint "$mountpoint" not found on EarthScope.\nPlease use "Get Sourcetable" to see available mountpoints.');
          return;
        }
        print('✅ Mountpoint $mountpoint is valid on EarthScope');
      }
      
      // Show connecting message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connecting to $host:$port/$mountpoint...'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      await provider.connect(
        host: host,
        port: port,
        mountpoint: mountpoint,
        username: username,
        password: password,
      );
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Connected successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('💥 Connection exception in UI: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
  
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _disconnect(RealtimeProvider provider) async {
    print('🔴 Disconnecting from NTRIP...');
    await provider.disconnect();
    print('✅ Disconnected successfully');
  }

  Future<void> _getSourcetable() async {
    // Validate required fields
    final host = _hostController.text.trim();
    final portStr = _portController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    
    if (host.isEmpty) {
      _showError('Host is required');
      return;
    }
    
    // Only require credentials if the caster needs them
    if (_selectedCaster == 'EarthScope' && (username.isEmpty || password.isEmpty)) {
      _showError('Username and password are required for EarthScope NTRIP caster');
      return;
    }
    
    final port = int.tryParse(portStr);
    if (port == null) {
      _showError('Invalid port number');
      return;
    }
    
    try {
      final sourcetable = await NtripClient.getSourcetable(
        host: host,
        port: port,
        username: username,
        password: password,
        useTls: port == 443,
      );
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('NTRIP Sourcetable'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: SingleChildScrollView(
                child: Text(
                  sourcetable,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get sourcetable: $e')),
        );
      }
    }
  }

  Future<bool> _validateMountpoint(String host, int port, String username, String password, String mountpoint) async {
    try {
      final sourcetable = await NtripClient.getSourcetable(
        host: host,
        port: port,
        username: username,
        password: password,
        useTls: port == 443,
      );
      
      // Check if mountpoint exists in sourcetable
      final lines = sourcetable.split('\n');
      for (final line in lines) {
        if (line.startsWith('STR;') && line.contains(';$mountpoint;')) {
          return true;
        }
      }
      return false;
    } catch (e) {
      print('⚠️ Could not validate mountpoint: $e');
      // If we can't get sourcetable, allow connection attempt
      return true;
    }
  }

  Future<void> _exportLog() async {
    final provider = context.read<RealtimeProvider>();
    try {
      await provider.exportLog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log exported successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }
}
