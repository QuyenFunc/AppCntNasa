import 'package:flutter/material.dart';
import '../models/gnss_station.dart';

class StationListItem extends StatelessWidget {
  final GnssStation station;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const StationListItem({
    super.key,
    required this.station,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: isSelected ? 4 : 1,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isSelected 
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: Row(
            children: [
              // Selection checkbox (if in selection mode)
              if (isSelectionMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onTap,
                ),
                const SizedBox(width: 8),
              ],

              // Station icon with status
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: station.isAccurate 
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: station.isAccurate ? Colors.green : Colors.red,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.satellite_alt,
                  color: station.isAccurate ? Colors.green : Colors.red,
                  size: 24,
                ),
              ),

              const SizedBox(width: 16),

              // Station information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Station name and ID
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            station.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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

                    const SizedBox(height: 4),

                    // Station ID
                    Text(
                      'ID: ${station.id}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Key metrics row
                    Row(
                      children: [
                        // Accuracy
                        _buildMetric(
                          context,
                          Icons.gps_fixed,
                          station.accuracyString,
                          station.isAccurate ? Colors.green : Colors.red,
                        ),

                        const SizedBox(width: 16),

                        // Coordinates
                        _buildMetric(
                          context,
                          Icons.location_on,
                          station.coordinatesString,
                          Colors.blue,
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Additional information row
                    Row(
                      children: [
                        // Last updated
                        _buildMetric(
                          context,
                          Icons.access_time,
                          _formatDateTime(station.updatedAt),
                          Colors.grey,
                        ),

                        const SizedBox(width: 16),

                        // Satellites (if available)
                        if (station.satelliteCount != null)
                          _buildMetric(
                            context,
                            Icons.satellite_alt,
                            '${station.satelliteCount}',
                            Colors.orange,
                          ),

                        // Signal strength (if available)
                        if (station.signalStrength != null) ...[
                          const SizedBox(width: 16),
                          _buildMetric(
                            context,
                            Icons.signal_cellular_4_bar,
                            '${station.signalStrength!.toStringAsFixed(1)} dB',
                            _getSignalColor(station.signalStrength!),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron or status icon
              if (!isSelectionMode)
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(BuildContext context, IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
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

  Color _getSignalColor(double signalStrength) {
    if (signalStrength >= 40) return Colors.green;
    if (signalStrength >= 30) return Colors.orange;
    return Colors.red;
  }
}
