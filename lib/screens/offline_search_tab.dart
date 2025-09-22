import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/offline_provider.dart';

class OfflineSearchTab extends StatefulWidget {
  const OfflineSearchTab({super.key});

  @override
  State<OfflineSearchTab> createState() => _OfflineSearchTabState();
}

class _OfflineSearchTabState extends State<OfflineSearchTab> {
  final _formKey = GlobalKey<FormState>();
  final _stationIdController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  
  String _selectedDataType = 'RINEX';
  
  final List<String> _dataTypes = [
    'RINEX',
    'Orbit',
    'Clock',
    'Ephemeris',
    'Ionosphere',
  ];

  final List<String> _popularStations = [
    'ALGO', 'GODE', 'USNO', 'ZIMM', 'WTZR',
    'BRUX', 'HERS', 'JPLM', 'KIRU', 'LHAZ',
    'MAW1', 'NKLG', 'ONSA', 'PERT', 'QAQ1',
    'REYK', 'SFER', 'THTI', 'UNSA', 'VILL',
  ];

  @override
  void dispose() {
    _stationIdController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineProvider>(
      builder: (context, provider, child) {
        if (!provider.isAuthenticated) {
          return _buildNotAuthenticatedState();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search parameters card
                _buildSearchParametersCard(provider),
                const SizedBox(height: 16),
                
                // Quick station selection
                _buildQuickStationCard(),
                const SizedBox(height: 16),
                
                // Search results
                if (provider.searchResults.isNotEmpty)
                  _buildSearchResultsCard(provider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotAuthenticatedState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
          Icon(
            Icons.lock_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Authentication Required',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please authenticate with NASA Earthdata to search for GNSS data',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // This should expand the auth panel
            },
            icon: const Icon(Icons.key),
            label: const Text('Add API Key'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildSearchParametersCard(OfflineProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search Parameters',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            // Station ID
            TextFormField(
              controller: _stationIdController,
              decoration: const InputDecoration(
                labelText: 'Station ID',
                hintText: 'e.g., ALGO, GODE, USNO',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a station ID';
                }
                if (value.length != 4) {
                  return 'Station ID must be 4 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Date range
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startDateController,
                    decoration: const InputDecoration(
                      labelText: 'Start Date',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () => _selectDate(_startDateController, 'start date'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Select start date';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _endDateController,
                    decoration: const InputDecoration(
                      labelText: 'End Date',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () => _selectDate(_endDateController, 'end date'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Select end date';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Data type
            DropdownButtonFormField<String>(
              value: _selectedDataType,
              decoration: const InputDecoration(
                labelText: 'Data Type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.data_usage),
              ),
              items: _dataTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      _getDataTypeIcon(type),
                      const SizedBox(width: 8),
                      Text(type),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDataType = value!;
                });
              },
            ),
            const SizedBox(height: 24),
            
            // Search button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: provider.isSearching ? null : () => _performSearch(provider),
                icon: provider.isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(provider.isSearching ? 'Searching...' : 'Search'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Popular Stations',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _popularStations.map((station) {
                return ActionChip(
                  label: Text(station),
                  onPressed: () {
                    _stationIdController.text = station;
                  },
                  backgroundColor: Colors.green.withOpacity(0.1),
                  side: BorderSide(color: Colors.green.withOpacity(0.3)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsCard(OfflineProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Search Results',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Chip(
                  label: Text('${provider.searchResults.length} files'),
                  backgroundColor: Colors.green.withOpacity(0.1),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Query: ${provider.searchQuery}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.searchResults.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final result = provider.searchResults[index];
                return _buildSearchResultItem(result, provider);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultItem(SearchResult result, OfflineProvider provider) {
    final isDownloaded = provider.downloads.any((d) => d.id == result.id);
    final isDownloading = provider.downloads
        .any((d) => d.id == result.id && d.status == DownloadStatus.downloading);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getDataTypeColor(result.dataType),
        child: _getDataTypeIcon(result.dataType),
      ),
      title: Text(result.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(result.description),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    result.date.toIso8601String().split('T')[0],
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storage, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    result.fileSize,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    result.format,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      trailing: isDownloading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isDownloaded
              ? const Icon(Icons.check_circle, color: Colors.green)
              : IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => provider.downloadFile(result),
                  tooltip: 'Download',
                ),
      onTap: () => _showResultDetails(result),
    );
  }

  Icon _getDataTypeIcon(String dataType) {
    switch (dataType) {
      case 'RINEX':
        return const Icon(Icons.radio, color: Colors.white);
      case 'Orbit':
        return const Icon(Icons.track_changes, color: Colors.white);
      case 'Clock':
        return const Icon(Icons.access_time, color: Colors.white);
      case 'Ephemeris':
        return const Icon(Icons.satellite_alt, color: Colors.white);
      case 'Ionosphere':
        return const Icon(Icons.layers, color: Colors.white);
      default:
        return const Icon(Icons.description, color: Colors.white);
    }
  }

  Color _getDataTypeColor(String dataType) {
    switch (dataType) {
      case 'RINEX':
        return Colors.blue;
      case 'Orbit':
        return Colors.green;
      case 'Clock':
        return Colors.orange;
      case 'Ephemeris':
        return Colors.purple;
      case 'Ionosphere':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Future<void> _selectDate(TextEditingController controller, String label) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 7)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Select $label',
    );
    if (picked != null) {
      controller.text = picked.toIso8601String().split('T')[0];
    }
  }

  Future<void> _performSearch(OfflineProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await provider.search(
        stationId: _stationIdController.text.trim().toUpperCase(),
        startDate: DateTime.parse(_startDateController.text),
        endDate: DateTime.parse(_endDateController.text),
        dataType: _selectedDataType,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  void _showResultDetails(SearchResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Station ID', result.stationId),
              _buildDetailRow('Data Type', result.dataType),
              _buildDetailRow('Date', result.date.toIso8601String().split('T')[0]),
              _buildDetailRow('File Size', result.fileSize),
              _buildDetailRow('Format', result.format),
              const SizedBox(height: 16),
              Text(
                'Description:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(result.description),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.read<OfflineProvider>().downloadFile(result);
            },
            icon: const Icon(Icons.download),
            label: const Text('Download'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
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
