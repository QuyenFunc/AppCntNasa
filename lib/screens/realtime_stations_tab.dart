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

  // Available mountpoints from different casters
  final List<MountpointInfo> _availableMountpoints = [
    MountpointInfo(
      id: 'BCEP00BKG0',
      name: 'BKG Broadcast Ephemeris',
      location: 'Germany',
      dataTypes: ['GPS', 'GLO', 'GAL', 'BDS', 'QZS', 'SBAS'],
      format: 'RTCM 3.3',
      isPublic: true,
    ),
    MountpointInfo(
      id: 'BCEP00GMV0',
      name: 'GMV Broadcast Ephemeris',
      location: 'Spain',
      dataTypes: ['GPS', 'GLO', 'GAL', 'BDS'],
      format: 'RTCM 3.3',
      isPublic: true,
    ),
    MountpointInfo(
      id: 'BCEP01BKG0',
      name: 'BKG GPS Only',
      location: 'Germany',
      dataTypes: ['GPS'],
      format: 'RTCM 3.1',
      isPublic: true,
    ),
    MountpointInfo(
      id: 'BCEP01JPL0',
      name: 'JPL Multi-GNSS',
      location: 'USA (California)',
      dataTypes: ['GPS', 'GLO', 'GAL'],
      format: 'RTCM 3.3',
      isPublic: true,
    ),
    MountpointInfo(
      id: 'BCEP02BKG0',
      name: 'BKG GLONASS Only',
      location: 'Germany',
      dataTypes: ['GLO'],
      format: 'RTCM 3.1',
      isPublic: true,
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

  void _showConnectDialog(MountpointInfo mountpoint) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              // TODO: Implement connection with this mountpoint
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Connecting to ${mountpoint.id}...'),
                ),
              );
            },
            child: const Text('Connect'),
          ),
        ],
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

  const MountpointInfo({
    required this.id,
    required this.name,
    required this.location,
    required this.dataTypes,
    required this.format,
    required this.isPublic,
  });
}
