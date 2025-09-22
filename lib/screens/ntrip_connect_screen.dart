import 'package:flutter/material.dart';
import '../services/ntrip_client.dart';

class NtripConnectScreen extends StatefulWidget {
  const NtripConnectScreen({super.key});
  
  @override
  State<NtripConnectScreen> createState() => _NtripConnectScreenState();
}

class _NtripConnectScreenState extends State<NtripConnectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _host = TextEditingController(text: 'products.igs-ip.net');
  final _port = TextEditingController(text: '2101');
  final _mount = TextEditingController(text: 'BCEP00BKG0');
  final _user = TextEditingController();
  final _pass = TextEditingController();
  
  bool _tls = false;
  bool _isConnecting = false;
  NtripClient? _client;
  String _status = 'Disconnected';
  int _frames = 0;
  double _kbps = 0;
  String _messageStats = '';
  String _sourcetable = '';

  @override
  void dispose() {
    _client?.close();
    _host.dispose();
    _port.dispose();
    _mount.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _getSourcetable() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isConnecting = true;
      _status = 'Getting sourcetable...';
    });

    try {
      final sourcetable = await NtripClient.getSourcetable(
        host: _host.text.trim(),
        port: int.parse(_port.text.trim()),
        username: _user.text.trim(),
        password: _pass.text,
        useTls: _tls,
      );
      
      setState(() {
        _sourcetable = sourcetable;
        _status = 'Sourcetable received';
      });
      
      _showSourcetableDialog();
    } catch (e) {
      setState(() {
        _status = 'Sourcetable error: $e';
      });
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void _showSourcetableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('NTRIP Sourcetable'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Text(
              _sourcetable,
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

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isConnecting = true;
      _status = 'Connecting...';
      _frames = 0;
      _kbps = 0;
      _messageStats = '';
    });

    try {
      _client = NtripClient(
        host: _host.text.trim(),
        port: int.parse(_port.text.trim()),
        mountPoint: _mount.text.trim(),
        username: _user.text.trim(),
        password: _pass.text,
        useTls: _tls,
      );
      
      await _client!.connect();
      
      _client!.statsStream.listen((stats) {
        setState(() {
          _frames = stats.frames;
          _kbps = double.parse(stats.bitrateKbps.toStringAsFixed(2));
          _status = 'Streaming';
          _messageStats = stats.summary;
        });
      });
      
    } catch (e) {
      setState(() {
        _status = 'Connection error: $e';
      });
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _disconnect() async {
    await _client?.close();
    _client = null;
    setState(() {
      _status = 'Disconnected';
      _frames = 0;
      _kbps = 0;
      _messageStats = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NTRIP Connect'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Connection Settings Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connection Settings',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _host,
                        decoration: const InputDecoration(
                          labelText: 'Host',
                          prefixIcon: Icon(Icons.dns),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.trim().isEmpty == true ? 'Host required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _port,
                        decoration: const InputDecoration(
                          labelText: 'Port',
                          prefixIcon: Icon(Icons.settings_ethernet),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value?.trim().isEmpty == true) return 'Port required';
                          if (int.tryParse(value!) == null) return 'Invalid port number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _mount,
                        decoration: const InputDecoration(
                          labelText: 'Mountpoint',
                          prefixIcon: Icon(Icons.satellite_alt),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.trim().isEmpty == true ? 'Mountpoint required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _user,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.trim().isEmpty == true ? 'Username required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _pass,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) => value?.isEmpty == true ? 'Password required' : null,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Use TLS (443)'),
                        subtitle: Text(_tls ? 'Secure connection' : 'Standard connection'),
                        value: _tls,
                        onChanged: (v) => setState(() => _tls = v),
                        secondary: Icon(_tls ? Icons.security : Icons.security_outlined),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isConnecting ? null : _getSourcetable,
                      icon: const Icon(Icons.list_alt),
                      label: const Text('Get Sourcetable'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isConnecting || _client?.isConnected == true ? null : _connect,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Connect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _client?.isConnected == true ? _disconnect : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Disconnect'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Status Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connection Status',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildStatusRow('Status', _status, _getStatusColor()),
                      const Divider(),
                      _buildStatusRow('Frames Received', '$_frames', Colors.blue),
                      const Divider(),
                      _buildStatusRow('Throughput', '$_kbps kbps', Colors.green),
                      if (_messageStats.isNotEmpty) ...[
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'RTCM Message Statistics:',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _messageStats,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Help Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Test Commands',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Test credentials with cURL before using the app:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TCP (port 2101):',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'curl -v --user USER:PASS "http://products.igs-ip.net:2101/BCEP00BKG0"',
                              style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'TLS (port 443):',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'curl -v --user USER:PASS "https://products.igs-ip.net/BCEP00BKG0"',
                              style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    if (_status.contains('Streaming')) return Colors.green;
    if (_status.contains('Connecting') || _status.contains('Getting')) return Colors.orange;
    if (_status.contains('error') || _status.contains('Error') || _status.contains('failed')) return Colors.red;
    return Colors.grey;
  }
}
