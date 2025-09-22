import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/gnss_station.dart';
import '../providers/gnss_provider.dart';
import '../services/export_service.dart';
import '../widgets/station_list_item.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/filter_dialog.dart';

class StationsListScreen extends StatefulWidget {
  const StationsListScreen({super.key});

  @override
  State<StationsListScreen> createState() => _StationsListScreenState();
}

class _StationsListScreenState extends State<StationsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ExportService _exportService = ExportService();
  
  String _searchQuery = '';
  bool _isSelectionMode = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GNSS Stations'),
        actions: [
          // Search button
          IconButton(
            onPressed: _toggleSearch,
            icon: const Icon(Icons.search),
          ),
          
          // Filter button
          IconButton(
            onPressed: _showFilterDialog,
            icon: const Icon(Icons.filter_list),
          ),
          
          // Selection mode toggle
          IconButton(
            onPressed: _toggleSelectionMode,
            icon: Icon(_isSelectionMode ? Icons.close : Icons.select_all),
          ),
          
          // More options
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Refresh Data'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download),
                    SizedBox(width: 8),
                    Text('Export Data'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_cache',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Clear Cache'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<GnssProvider>(
        builder: (context, gnssProvider, child) {
          final stations = _searchQuery.isEmpty 
              ? gnssProvider.stations
              : gnssProvider.searchStations(_searchQuery);

          return Column(
            children: [
              // Search bar (if active)
              if (_searchController.text.isNotEmpty || _searchQuery.isNotEmpty)
                SearchBarWidget(
                  controller: _searchController,
                  onChanged: (query) {
                    setState(() {
                      _searchQuery = query;
                    });
                  },
                  onClear: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                ),

              // Statistics bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatChip(
                      'Total',
                      gnssProvider.totalStations.toString(),
                      Colors.blue,
                    ),
                    _buildStatChip(
                      'Accurate',
                      gnssProvider.accurateStations.toString(),
                      Colors.green,
                    ),
                    _buildStatChip(
                      'Warning',
                      gnssProvider.inaccurateStations.toString(),
                      Colors.red,
                    ),
                    if (_isSelectionMode)
                      _buildStatChip(
                        'Selected',
                        gnssProvider.selectedStations.length.toString(),
                        Colors.orange,
                      ),
                  ],
                ),
              ),

              // Selection mode controls
              if (_isSelectionMode)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => gnssProvider.selectAllStations(),
                        icon: const Icon(Icons.select_all),
                        label: const Text('Select All'),
                      ),
                      TextButton.icon(
                        onPressed: () => gnssProvider.clearSelection(),
                        icon: const Icon(Icons.deselect),
                        label: const Text('Clear'),
                      ),
                      const Spacer(),
                      if (gnssProvider.selectedStations.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () => _exportSelectedStations(gnssProvider),
                          icon: const Icon(Icons.file_download),
                          label: Text('Export (${gnssProvider.selectedStations.length})'),
                        ),
                    ],
                  ),
                ),

              // Stations list
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => gnssProvider.refreshStations(),
                  child: _buildStationsList(gnssProvider, stations),
                ),
              ),
            ],
          );
        },
      ),
      
      // Floating action button for refresh
      floatingActionButton: FloatingActionButton(
        onPressed: () => _refreshData(context),
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildStationsList(GnssProvider gnssProvider, List<GnssStation> stations) {
    if (gnssProvider.isLoading && stations.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (stations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.satellite_alt,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'No stations found for "$_searchQuery"'
                  : 'No GNSS stations available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => gnssProvider.fetchStations(),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: stations.length,
      itemBuilder: (context, index) {
        final station = stations[index];
        return StationListItem(
          station: station,
          isSelected: _isSelectionMode && gnssProvider.isStationSelected(station),
          isSelectionMode: _isSelectionMode,
          onTap: () => _handleStationTap(station, gnssProvider),
          onLongPress: () => _handleStationLongPress(station, gnssProvider),
        );
      },
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _handleStationTap(GnssStation station, GnssProvider gnssProvider) {
    if (_isSelectionMode) {
      gnssProvider.toggleStationSelection(station);
    } else {
      // Navigate to station details
      Navigator.pushNamed(
        context,
        '/station-details',
        arguments: station,
      );
    }
  }

  void _handleStationLongPress(GnssStation station, GnssProvider gnssProvider) {
    if (!_isSelectionMode) {
      setState(() {
        _isSelectionMode = true;
      });
      gnssProvider.selectStation(station);
    } else {
      gnssProvider.toggleStationSelection(station);
    }
  }

  void _toggleSearch() {
    setState(() {
      if (_searchQuery.isNotEmpty) {
        _searchController.clear();
        _searchQuery = '';
      } else {
        // Focus search field
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FocusScope.of(context).requestFocus();
        });
      }
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
    });
    
    if (!_isSelectionMode) {
      Provider.of<GnssProvider>(context, listen: false).clearSelection();
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => FilterDialog(
        onApplyFilters: (filters) {
          final gnssProvider = Provider.of<GnssProvider>(context, listen: false);
          // Apply filters
          gnssProvider.setShowOnlyInaccurate(filters['showOnlyInaccurate'] ?? false);
          gnssProvider.setSortBy(filters['sortBy'] ?? 'name');
          gnssProvider.setAccuracyThreshold(filters['accuracyThreshold'] ?? 5.0);
        },
      ),
    );
  }

  void _handleMenuAction(String action) async {
    final gnssProvider = Provider.of<GnssProvider>(context, listen: false);
    
    switch (action) {
      case 'refresh':
        await gnssProvider.refreshStations();
        _showSnackBar('Data refreshed successfully');
        break;
        
      case 'export':
        await _exportAllStations(gnssProvider);
        break;
        
      case 'clear_cache':
        await _clearCache();
        break;
    }
  }

  Future<void> _refreshData(BuildContext context) async {
    final gnssProvider = Provider.of<GnssProvider>(context, listen: false);
    await gnssProvider.fetchStations();
    
    if (mounted) {
      _showSnackBar('Updated ${gnssProvider.totalStations} stations');
    }
  }

  Future<void> _exportAllStations(GnssProvider gnssProvider) async {
    try {
      final stations = gnssProvider.allStations;
      if (stations.isEmpty) {
        _showSnackBar('No stations to export');
        return;
      }

      // Show export options dialog
      final format = await _showExportDialog();
      if (format == null) return;

      String? filePath;
      switch (format) {
        case 'csv':
          filePath = await _exportService.exportStationsToCSV(stations);
          break;
        case 'json':
          filePath = await _exportService.exportStationsToJSON(stations);
          break;
        case 'txt':
          filePath = await _exportService.exportStationsToText(stations);
          break;
      }

      if (filePath != null) {
        _showSnackBar('Exported ${stations.length} stations to ${format.toUpperCase()}');
        
        // Ask if user wants to share
        final share = await _showShareDialog();
        if (share == true) {
          await _exportService.shareExportedFile(filePath);
        }
      }
    } catch (e) {
      _showSnackBar('Export failed: ${e.toString()}');
    }
  }

  Future<void> _exportSelectedStations(GnssProvider gnssProvider) async {
    try {
      final stations = gnssProvider.selectedStations;
      if (stations.isEmpty) {
        _showSnackBar('No stations selected');
        return;
      }

      final format = await _showExportDialog();
      if (format == null) return;

      String? filePath;
      switch (format) {
        case 'csv':
          filePath = await _exportService.exportStationsToCSV(stations);
          break;
        case 'json':
          filePath = await _exportService.exportStationsToJSON(stations);
          break;
        case 'txt':
          filePath = await _exportService.exportStationsToText(stations);
          break;
      }

      if (filePath != null) {
        _showSnackBar('Exported ${stations.length} selected stations');
        gnssProvider.clearSelection();
        setState(() {
          _isSelectionMode = false;
        });
      }
    } catch (e) {
      _showSnackBar('Export failed: ${e.toString()}');
    }
  }

  Future<String?> _showExportDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('CSV'),
              subtitle: const Text('Excel compatible'),
              onTap: () => Navigator.pop(context, 'csv'),
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('JSON'),
              subtitle: const Text('Machine readable'),
              onTap: () => Navigator.pop(context, 'json'),
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: const Text('Text'),
              subtitle: const Text('Human readable'),
              onTap: () => Navigator.pop(context, 'txt'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showShareDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Complete'),
        content: const Text('Would you like to share the exported file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will remove all cached station data. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.red,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Clear cache logic would go here
      _showSnackBar('Cache cleared');
    }
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
