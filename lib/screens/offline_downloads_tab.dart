import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/offline_provider.dart';

class OfflineDownloadsTab extends StatefulWidget {
  const OfflineDownloadsTab({super.key});

  @override
  State<OfflineDownloadsTab> createState() => _OfflineDownloadsTabState();
}

class _OfflineDownloadsTabState extends State<OfflineDownloadsTab> {
  String _filterStatus = 'All';
  String _sortBy = 'Date';
  
  final List<String> _statusFilters = ['All', 'Completed', 'Downloading', 'Failed'];
  final List<String> _sortOptions = ['Date', 'Name', 'Size', 'Status'];

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineProvider>(
      builder: (context, provider, child) {
        final filteredDownloads = _getFilteredDownloads(provider.downloads);
        
        return Column(
          children: [
            // Filter and sort controls
            _buildControlsCard(provider),
            
            // Downloads list
            Expanded(
              child: filteredDownloads.isEmpty
                  ? _buildEmptyState(provider)
                  : _buildDownloadsList(filteredDownloads, provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlsCard(OfflineProvider provider) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Downloads',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (provider.downloads.isNotEmpty)
                  Chip(
                    label: Text('${provider.downloads.length} files'),
                    backgroundColor: Colors.green.withOpacity(0.1),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            Column(
              children: [
                // Status filter
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Filter by Status:'),
                    const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _filterStatus,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _statusFilters.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _getStatusIcon(status),
                                const SizedBox(width: 4),
                                Flexible(child: Text(status, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _filterStatus = value!;
                          });
                        },
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                
                // Sort option
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sort by:'),
                    const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _sortBy,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _sortOptions.map((option) {
                          return DropdownMenuItem(
                            value: option,
                            child: Text(option),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _sortBy = value!;
                          });
                        },
                      ),
                    ],
                  ),
              ],
            ),
            
            // Summary stats
            if (provider.downloads.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatChip(
                    'Completed',
                    provider.downloads.where((d) => d.status == DownloadStatus.completed).length,
                    Colors.green,
                  ),
                  _buildStatChip(
                    'Downloading',
                    provider.downloads.where((d) => d.status == DownloadStatus.downloading).length,
                    Colors.blue,
                  ),
                  _buildStatChip(
                    'Failed',
                    provider.downloads.where((d) => d.status == DownloadStatus.failed).length,
                    Colors.red,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadsList(List<DownloadItem> downloads, OfflineProvider provider) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: downloads.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final download = downloads[index];
        return _buildDownloadItem(download, provider);
      },
    );
  }

  Widget _buildDownloadItem(DownloadItem download, OfflineProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(download.status),
          child: _getStatusIcon(download.status.name),
        ),
        title: Text(
          download.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(download.fileName),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.storage, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  download.fileSize,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _formatTime(download.startTime),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            if (download.status == DownloadStatus.downloading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: download.progress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(download.progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
            if (download.status == DownloadStatus.failed && download.error != null) ...[
              const SizedBox(height: 4),
              Text(
                'Error: ${download.error}',
                style: const TextStyle(color: Colors.red, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: _buildDownloadActions(download, provider),
        onTap: download.status == DownloadStatus.completed
            ? () => _showDownloadDetails(download, provider)
            : null,
      ),
    );
  }

  Widget _buildDownloadActions(DownloadItem download, OfflineProvider provider) {
    switch (download.status) {
      case DownloadStatus.downloading:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        
      case DownloadStatus.completed:
        return PopupMenuButton<String>(
          onSelected: (action) => _handleDownloadAction(action, download, provider),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'open',
              child: ListTile(
                leading: Icon(Icons.visibility),
                title: Text('View'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: ListTile(
                leading: Icon(Icons.share),
                title: Text('Share'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        );
        
      case DownloadStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                // TODO: Retry download
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Retry functionality coming soon')),
                );
              },
              tooltip: 'Retry',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => provider.deleteDownload(download.id),
              tooltip: 'Delete',
            ),
          ],
        );
    }
  }

  Widget _buildEmptyState(OfflineProvider provider) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
          Icon(
            provider.isAuthenticated ? Icons.download_outlined : Icons.lock_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            provider.isAuthenticated ? 'No Downloads Yet' : 'Authentication Required',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            provider.isAuthenticated
                ? 'Search for GNSS data and download files to see them here'
                : 'Please authenticate to download GNSS data files',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to search tab or show auth panel
            },
            icon: Icon(provider.isAuthenticated ? Icons.search : Icons.key),
            label: Text(provider.isAuthenticated ? 'Search Data' : 'Add API Key'),
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

  List<DownloadItem> _getFilteredDownloads(List<DownloadItem> downloads) {
    var filtered = downloads;
    
    // Apply status filter
    if (_filterStatus != 'All') {
      filtered = filtered.where((d) {
        return d.status.name.toLowerCase() == _filterStatus.toLowerCase();
      }).toList();
    }
    
    // Apply sorting
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'Name':
          return a.title.compareTo(b.title);
        case 'Size':
          return a.fileSize.compareTo(b.fileSize);
        case 'Status':
          return a.status.index.compareTo(b.status.index);
        case 'Date':
        default:
          return b.startTime.compareTo(a.startTime); // Newest first
      }
    });
    
    return filtered;
  }

  Icon _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Icon(Icons.check_circle, color: Colors.white);
      case 'downloading':
        return const Icon(Icons.download, color: Colors.white);
      case 'failed':
        return const Icon(Icons.error, color: Colors.white);
      case 'all':
        return const Icon(Icons.list, color: Colors.white);
      default:
        return const Icon(Icons.description, color: Colors.white);
    }
  }

  Color _getStatusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.downloading:
        return Colors.blue;
      case DownloadStatus.failed:
        return Colors.red;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _handleDownloadAction(String action, DownloadItem download, OfflineProvider provider) {
    switch (action) {
      case 'open':
        provider.openFile(download);
        break;
      case 'share':
        // TODO: Implement share functionality
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Share functionality coming soon')),
        );
        break;
      case 'delete':
        _showDeleteConfirmation(download, provider);
        break;
    }
  }

  void _showDeleteConfirmation(DownloadItem download, OfflineProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Download'),
        content: Text('Are you sure you want to delete "${download.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              provider.deleteDownload(download.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download deleted')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDownloadDetails(DownloadItem download, OfflineProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(download.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('File Name', download.fileName),
              _buildDetailRow('File Size', download.fileSize),
              _buildDetailRow('Data Type', download.dataType),
              _buildDetailRow('Status', download.status.name),
              _buildDetailRow('Started', download.startTime.toString()),
              if (download.endTime != null)
                _buildDetailRow('Completed', download.endTime.toString()),
              if (download.filePath != null)
                _buildDetailRow('Location', download.filePath!),
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
              provider.openFile(download);
            },
            icon: const Icon(Icons.visibility),
            label: const Text('View File'),
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
