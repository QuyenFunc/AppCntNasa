import 'package:flutter/material.dart';
import '../models/gnss_station.dart';

class StationInfoPopup extends StatelessWidget {
  final GnssStation station;
  final VoidCallback onClose;
  final VoidCallback onViewDetails;
  final VoidCallback onCenterOnStation;

  const StationInfoPopup({
    super.key,
    required this.station,
    required this.onClose,
    required this.onViewDetails,
    required this.onCenterOnStation,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    station.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Station ID
            _buildInfoRow(
              icon: Icons.tag,
              label: 'Station ID',
              value: station.id,
            ),
            
            const SizedBox(height: 8),
            
            // Coordinates
            _buildInfoRow(
              icon: Icons.location_on,
              label: 'Coordinates',
              value: station.coordinatesString,
            ),
            
            const SizedBox(height: 8),
            
            // Accuracy with status indicator
            Row(
              children: [
                Icon(
                  Icons.gps_fixed,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  'Accuracy: ',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                Text(
                  station.accuracyString,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: station.isAccurate ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: station.isAccurate 
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    station.isAccurate ? 'OK' : 'WARNING',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: station.isAccurate ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Last updated
            _buildInfoRow(
              icon: Icons.access_time,
              label: 'Last Updated',
              value: _formatDateTime(station.updatedAt),
            ),
            
            // Additional info if available
            if (station.elevation != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                icon: Icons.terrain,
                label: 'Elevation',
                value: '${station.elevation!.toStringAsFixed(0)}m',
              ),
            ],
            
            if (station.satelliteCount != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                icon: Icons.satellite_alt,
                label: 'Satellites',
                value: '${station.satelliteCount}',
              ),
            ],
            
            if (station.signalStrength != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                icon: Icons.signal_cellular_4_bar,
                label: 'Signal',
                value: '${station.signalStrength!.toStringAsFixed(1)} dB',
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCenterOnStation,
                    icon: const Icon(Icons.center_focus_strong, size: 18),
                    label: const Text('Center'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onViewDetails,
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Details'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
