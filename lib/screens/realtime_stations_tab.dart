import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/realtime_provider.dart';

class RealtimeStationsTab extends StatefulWidget {
  const RealtimeStationsTab({super.key});

  @override
  State<RealtimeStationsTab> createState() => _RealtimeStationsTabState();
}

class _RealtimeStationsTabState extends State<RealtimeStationsTab> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Available mountpoints from EarthScope NTRIP caster
  final List<MountpointInfo> _availableMountpoints = [
    MountpointInfo(
      id: '7ODM_RTCM3P3',
      name: 'Seven Oaks Dam - California',
      location: 'California, USA (34.12°N, -117.09°W)',
      dataTypes: ['GPS', 'GLO', 'BDS', 'GAL', 'SBAS', 'QZS'],
      format: 'RTCM 3.3',
      isPublic: false,
      latitude: 34.12,
      longitude: -117.09,
    ),
    MountpointInfo(
      id: 'AB07_RTCM3P3',
      name: 'Aleutian Bridge 07 - Alaska',
      location: 'Alaska, USA (55.35°N, -160.48°W)',
      dataTypes: ['GPS', 'GLO', 'BDS', 'GAL', 'SBAS', 'QZS'],
      format: 'RTCM 3.3',
      isPublic: false,
      latitude: 55.35,
      longitude: -160.48,
    ),
    MountpointInfo(
      id: 'AB11_RTCM3P3',
      name: 'Aleutian Bridge 11 - Alaska',
      location: 'Alaska, USA (64.56°N, -165.37°W)',
      dataTypes: ['GPS', 'GLO', 'BDS', 'GAL', 'SBAS', 'QZS'],
      format: 'RTCM 3.3',
      isPublic: false,
      latitude: 64.56,
      longitude: -165.37,
    ),
    MountpointInfo(
      id: 'AB17_RTCM3P3',
      name: 'Aleutian Bridge 17 - Alaska',
      location: 'Alaska, USA (63.89°N, -160.69°W)',
      dataTypes: ['GPS', 'GLO', 'BDS', 'GAL', 'SBAS', 'QZS'],
      format: 'RTCM 3.3',
      isPublic: false,
      latitude: 63.89,
      longitude: -160.69,
    ),
    MountpointInfo(
      id: 'AB18_RTCM3P3',
      name: 'Aleutian Bridge 18 - Alaska',
      location: 'Alaska, USA (66.86°N, -162.61°W)',
      dataTypes: ['GPS', 'GLO', 'BDS', 'GAL', 'SBAS', 'QZS'],
      format: 'RTCM 3.3',
      isPublic: false,
      latitude: 66.86,
      longitude: -162.61,
    ),
    MountpointInfo(
      id: 'AB43_RTCM3P3',
      name: 'Aleutian Bridge 43 - Alaska',
      location: 'Alaska, USA (58.20°N, -136.64°W)',
      dataTypes: ['GPS', 'GLO', 'BDS', 'GAL', 'SBAS', 'QZS'],
      format: 'RTCM 3.3',
      isPublic: false,
      latitude: 58.20,
      longitude: -136.64,
    ),
    MountpointInfo(
      id: 'AB44_RTCM3P3',
      name: 'Aleutian Bridge 44 - Alaska',
      location: 'Alaska, USA (59.53°N, -135.23°W)',
      dataTypes: ['GPS'],
      format: 'RTCM 3.3',
      isPublic: false,
      latitude: 59.53,
      longitude: -135.23,
    ),
    MountpointInfo(
      id: 'ACHO_RTCM3P3',
      name: 'Achotal - Panama',
      location: 'Panama (7.41°N, -80.17°W)',
      dataTypes: ['GPS', 'GLO', 'BDS', 'GAL', 'SBAS', 'QZS'],
      format: 'RTCM 3.3',
      isPublic: false,
      latitude: 7.41,
      longitude: -80.17,
    ),
    MountpointInfo(
      id: 'ACSB_RTCM3P3',
      name: 'ACCSB - California',
      location: 'California, USA (33.27°N, -117.44°W)',
      dataTypes: ['GPS', 'GLO', 'BDS', 'GAL', 'SBAS', 'QZS'],
      format: 'RTCM 3.3',
      isPublic: false,
      latitude: 33.27,
      longitude: -117.44,
    ),
    MountpointInfo(
      id: 'ACSO_RTCM3P3',
      name: 'ACSO - Ohio',
      location: 'Ohio, USA (40.23°N, -82.98°W)',
      dataTypes: ['GPS', 'GLO', 'BDS', 'GAL', 'SBAS', 'QZS'],
      format: 'RTCM 3.3',
      isPublic: false,
      latitude: 40.23,
      longitude: -82.98,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MountpointInfo> get _filteredMountpoints {
    if (_searchQuery.isEmpty) return _availableMountpoints;
    
    return _availableMountpoints.where((mp) {
      return mp.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             mp.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             mp.location.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             mp.dataTypes.any((type) => type.toLowerCase().contains(_searchQuery.toLowerCase()));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RealtimeProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search mountpoints...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            
            // Filter chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Public'),
                    selected: true,
                    onSelected: (selected) {
                      // TODO: Implement filter
                    },
                  ),
                  FilterChip(
                    label: const Text('Multi-GNSS'),
                    selected: false,
                    onSelected: (selected) {
                      // TODO: Implement filter
                    },
                  ),
                  FilterChip(
                    label: const Text('Real-time'),
                    selected: false,
                    onSelected: (selected) {
                      // TODO: Implement filter
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Mountpoint list
            Expanded(
              child: _filteredMountpoints.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: _filteredMountpoints.length,
                      itemBuilder: (context, index) {
                        final mountpoint = _filteredMountpoints[index];
                        return _buildMountpointCard(mountpoint, provider);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMountpointCard(MountpointInfo mountpoint, RealtimeProvider provider) {
    final isCurrentlyConnected = provider.isConnected && 
        provider.stations.any((s) => s.id == mountpoint.id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCurrentlyConnected ? Colors.green : Colors.blue,
          child: Icon(
            isCurrentlyConnected ? Icons.radio_button_checked : Icons.satellite_alt,
            color: Colors.white,
          ),
        ),
        title: Text(
          mountpoint.id,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mountpoint.name),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    mountpoint.location,
                    style: TextStyle(color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.data_usage, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  mountpoint.format,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: mountpoint.dataTypes.map((type) {
                return Chip(
                  label: Text(type),
                  labelStyle: const TextStyle(fontSize: 10),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ),
        trailing: isCurrentlyConnected
            ? const Icon(Icons.check_circle, color: Colors.green)
            : IconButton(
                icon: const Icon(Icons.connect_without_contact),
                onPressed: () {
                  _showConnectDialog(mountpoint);
                },
              ),
        onTap: () {
          _showMountpointDetails(mountpoint);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Mountpoints Found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search terms or filters',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Future<void> _connectToMountpoint(MountpointInfo mountpoint, RealtimeProvider provider) async {
    try {
      // Show connecting message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connecting to ${mountpoint.id}...'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );

      // Connect using EarthScope credentials
      await provider.connect(
        host: 'ntrip.earthscope.org',
        port: 2101,
        mountpoint: mountpoint.id,
        username: 'dazzling_stallman',
        password: 'YP8Ae9Bb45cV0yOf',
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${mountpoint.name}!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
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

  void _showConnectDialog(MountpointInfo mountpoint) {
    showDialog(
      context: context,
      builder: (context) => Consumer<RealtimeProvider>(
        builder: (context, provider, child) => AlertDialog(
          title: Text('Connect to ${mountpoint.id}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Do you want to connect to this mountpoint?'),
              const SizedBox(height: 16),
              Text('Name: ${mountpoint.name}'),
              Text('Location: ${mountpoint.location}'),
              Text('Format: ${mountpoint.format}'),
              Text('Data Types: ${mountpoint.dataTypes.join(', ')}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _connectToMountpoint(mountpoint, provider);
              },
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMountpointDetails(MountpointInfo mountpoint) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(mountpoint.id),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Name', mountpoint.name),
              _buildDetailRow('Location', mountpoint.location),
              _buildDetailRow('Format', mountpoint.format),
              _buildDetailRow('Access', mountpoint.isPublic ? 'Public' : 'Restricted'),
              const SizedBox(height: 16),
              const Text(
                'Supported Data Types:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: mountpoint.dataTypes.map((type) {
                  return Chip(label: Text(type));
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showConnectDialog(mountpoint);
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class MountpointInfo {
  final String id;
  final String name;
  final String location;
  final List<String> dataTypes;
  final String format;
  final bool isPublic;
  final double latitude;
  final double longitude;

  const MountpointInfo({
    required this.id,
    required this.name,
    required this.location,
    required this.dataTypes,
    required this.format,
    required this.isPublic,
    required this.latitude,
    required this.longitude,
  });
}
