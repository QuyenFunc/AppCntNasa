import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/offline_provider.dart';

class OfflineViewerTab extends StatefulWidget {
  const OfflineViewerTab({super.key});

  @override
  State<OfflineViewerTab> createState() => _OfflineViewerTabState();
}

class _OfflineViewerTabState extends State<OfflineViewerTab> {
  final ScrollController _scrollController = ScrollController();
  bool _showLineNumbers = true;
  bool _wordWrap = false;
  double _fontSize = 12.0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineProvider>(
      builder: (context, provider, child) {
        if (provider.selectedFile == null) {
          return _buildNoFileSelectedState(provider);
        }

        return Column(
          children: [
            // File info header
            _buildFileInfoHeader(provider.selectedFile!, provider),
            
            // Viewer controls
            _buildViewerControls(),
            
            // File content viewer
            Expanded(
              child: _buildFileContentViewer(provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoFileSelectedState(OfflineProvider provider) {
    final completedDownloads = provider.downloads
        .where((d) => d.status == DownloadStatus.completed)
        .toList();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.visibility_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No File Selected',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            completedDownloads.isEmpty
                ? 'Download some files first to view them here'
                : 'Select a downloaded file to view its contents',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          
          if (completedDownloads.isNotEmpty) ...[
            Text(
              'Recent Downloads:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: completedDownloads.take(3).map((download) {
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getDataTypeColor(download.dataType),
                        child: _getDataTypeIcon(download.dataType),
                      ),
                      title: Text(
                        download.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(download.fileName),
                      trailing: const Icon(Icons.arrow_forward),
                      onTap: () => provider.openFile(download),
                    ),
                  );
                }).toList(),
              ),
            ),
          ] else
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to search tab
              },
              icon: const Icon(Icons.search),
              label: const Text('Search & Download'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileInfoHeader(DownloadItem file, OfflineProvider provider) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getDataTypeColor(file.dataType),
                  child: _getDataTypeIcon(file.dataType),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        file.fileName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => provider.closeFile(),
                  tooltip: 'Close file',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(Icons.storage, file.fileSize),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.category, file.dataType),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.access_time, _formatDateTime(file.startTime)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: Colors.green.withOpacity(0.1),
      labelStyle: const TextStyle(fontSize: 12),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildViewerControls() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Search bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search in file...',
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
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.content_copy),
                  onPressed: _copyToClipboard,
                  tooltip: 'Copy content',
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: _shareFile,
                  tooltip: 'Share file',
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Viewer options
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                // Line numbers toggle
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _showLineNumbers,
                      onChanged: (value) {
                        setState(() {
                          _showLineNumbers = value!;
                        });
                      },
                    ),
                    const Text('Line numbers'),
                  ],
                ),
                
                // Word wrap toggle
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _wordWrap,
                      onChanged: (value) {
                        setState(() {
                          _wordWrap = value!;
                        });
                      },
                    ),
                    const Text('Word wrap'),
                  ],
                ),
                
                // Font size controls
                const Text('Font size: '),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _fontSize > 8 ? () {
                    setState(() {
                      _fontSize -= 1;
                    });
                  } : null,
                ),
                Text('${_fontSize.toInt()}'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _fontSize < 24 ? () {
                    setState(() {
                      _fontSize += 1;
                    });
                  } : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileContentViewer(OfflineProvider provider) {
    final content = provider.fileContent;
    
    if (content.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final lines = content.split('\n');
    final filteredLines = _searchQuery.isEmpty 
        ? lines 
        : lines.where((line) => 
            line.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_searchQuery.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.yellow.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Found ${filteredLines.length} lines matching "$_searchQuery"',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                ...filteredLines.asMap().entries.map((entry) {
                  final lineIndex = entry.key;
                  final line = entry.value;
                  final originalLineNumber = _searchQuery.isEmpty 
                      ? lineIndex + 1 
                      : lines.indexOf(line) + 1;
                  
                  return _buildCodeLine(
                    originalLineNumber,
                    line,
                    _searchQuery,
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeLine(int lineNumber, String line, String searchQuery) {
    Widget lineContent;
    
    if (searchQuery.isNotEmpty && line.toLowerCase().contains(searchQuery.toLowerCase())) {
      // Highlight search matches
      final matches = RegExp(searchQuery, caseSensitive: false).allMatches(line);
      
      final spans = <TextSpan>[];
      int lastEnd = 0;
      
      for (final match in matches) {
        if (match.start > lastEnd) {
          spans.add(TextSpan(text: line.substring(lastEnd, match.start)));
        }
        spans.add(TextSpan(
          text: match.group(0),
          style: const TextStyle(
            backgroundColor: Colors.yellow,
            fontWeight: FontWeight.bold,
          ),
        ));
        lastEnd = match.end;
      }
      
      if (lastEnd < line.length) {
        spans.add(TextSpan(text: line.substring(lastEnd)));
      }
      
      lineContent = RichText(
        text: TextSpan(
          children: spans,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: _fontSize,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        softWrap: _wordWrap,
      );
    } else {
      lineContent = Text(
        line,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: _fontSize,
        ),
        softWrap: _wordWrap,
        overflow: _wordWrap ? TextOverflow.visible : TextOverflow.ellipsis,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_showLineNumbers) ...[
            SizedBox(
              width: 50,
              child: Text(
                lineNumber.toString(),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: _fontSize,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(child: lineContent),
        ],
      ),
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _copyToClipboard() {
    // TODO: Implement clipboard copy
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copy functionality coming soon')),
    );
  }

  void _shareFile() {
    // TODO: Implement file sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality coming soon')),
    );
  }
}
