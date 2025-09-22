import 'package:flutter/material.dart';
import '../models/gnss_station.dart';

class StationSelector extends StatelessWidget {
  final List<GnssStation> stations;
  final GnssStation? selectedStation;
  final Function(GnssStation) onStationSelected;

  const StationSelector({
    super.key,
    required this.stations,
    required this.selectedStation,
    required this.onStationSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (stations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Text('No stations available'),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Station',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<GnssStation>(
            value: selectedStation,
            decoration: InputDecoration(
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            items: stations.map((station) {
              return DropdownMenuItem<GnssStation>(
                value: station,
                child: SizedBox(
                  width: double.infinity,
                  child: Row(
                    children: [
                      // Status indicator
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: station.isAccurate ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Station name and ID
                      Expanded(
                        child: Text(
                          '${station.name} (${station.id})',
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Accuracy indicator
                      Text(
                        station.accuracyString,
                        style: TextStyle(
                          fontSize: 10,
                          color: station.isAccurate ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: (station) {
              if (station != null) {
                onStationSelected(station);
              }
            },
            hint: const Text('Choose a station to analyze'),
          ),
          if (selectedStation != null) ...[
            const SizedBox(height: 8),
            _buildSelectedStationInfo(),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedStationInfo() {
    if (selectedStation == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: selectedStation!.isAccurate 
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selectedStation!.isAccurate 
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: selectedStation!.isAccurate ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  selectedStation!.coordinatesString,
                  style: const TextStyle(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                selectedStation!.accuracyString,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selectedStation!.isAccurate ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          if (selectedStation!.satelliteCount != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Sats: ${selectedStation!.satelliteCount}',
                  style: const TextStyle(fontSize: 10),
                ),
                if (selectedStation!.signalStrength != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Signal: ${selectedStation!.signalStrength!.toStringAsFixed(1)}dB',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
