import 'package:flutter/material.dart';

class FilterDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onApplyFilters;

  const FilterDialog({
    super.key,
    required this.onApplyFilters,
  });

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  bool _showOnlyInaccurate = false;
  String _sortBy = 'name';
  bool _sortAscending = true;
  double _accuracyThreshold = 5.0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter & Sort Options'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show only inaccurate stations
            SwitchListTile(
              title: const Text('Show Only Warning Stations'),
              subtitle: const Text('Display stations with accuracy issues'),
              value: _showOnlyInaccurate,
              onChanged: (value) {
                setState(() {
                  _showOnlyInaccurate = value;
                });
              },
            ),

            const SizedBox(height: 16),

            // Accuracy threshold
            Text(
              'Accuracy Threshold',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _accuracyThreshold,
                    min: 1.0,
                    max: 20.0,
                    divisions: 19,
                    label: '${_accuracyThreshold.toStringAsFixed(0)}m',
                    onChanged: (value) {
                      setState(() {
                        _accuracyThreshold = value;
                      });
                    },
                  ),
                ),
                Container(
                  width: 60,
                  alignment: Alignment.center,
                  child: Text(
                    '${_accuracyThreshold.toStringAsFixed(0)}m',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Stations with accuracy above this threshold will be marked as warnings',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 24),

            // Sort options
            Text(
              'Sort By',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            
            RadioListTile<String>(
              title: const Text('Station Name'),
              value: 'name',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
              },
            ),
            
            RadioListTile<String>(
              title: const Text('Accuracy'),
              value: 'accuracy',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
              },
            ),
            
            RadioListTile<String>(
              title: const Text('Last Updated'),
              value: 'updated_at',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
              },
            ),
            
            RadioListTile<String>(
              title: const Text('Latitude'),
              value: 'latitude',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
              },
            ),
            
            RadioListTile<String>(
              title: const Text('Longitude'),
              value: 'longitude',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
              },
            ),

            const SizedBox(height: 16),

            // Sort order
            SwitchListTile(
              title: const Text('Ascending Order'),
              subtitle: Text(_sortAscending ? 'A to Z, Low to High' : 'Z to A, High to Low'),
              value: _sortAscending,
              onChanged: (value) {
                setState(() {
                  _sortAscending = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _resetFilters(),
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => _applyFilters(),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  void _resetFilters() {
    setState(() {
      _showOnlyInaccurate = false;
      _sortBy = 'name';
      _sortAscending = true;
      _accuracyThreshold = 5.0;
    });
  }

  void _applyFilters() {
    final filters = {
      'showOnlyInaccurate': _showOnlyInaccurate,
      'sortBy': _sortBy,
      'sortAscending': _sortAscending,
      'accuracyThreshold': _accuracyThreshold,
    };
    
    widget.onApplyFilters(filters);
    Navigator.pop(context);
  }
}
