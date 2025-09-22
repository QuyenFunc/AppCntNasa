import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/gnss_station.dart';
import '../providers/gnss_provider.dart';

class StationDetailsScreen extends StatefulWidget {
  final GnssStation station;

  const StationDetailsScreen({
    super.key,
    required this.station,
  });

  @override
  State<StationDetailsScreen> createState() => _StationDetailsScreenState();
}

class _StationDetailsScreenState extends State<StationDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.station.name),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<GnssProvider>(
        builder: (context, gnssProvider, child) {
          // Find updated station data
          final currentStation = gnssProvider.stations
              .where((s) => s.id == widget.station.id)
              .firstOrNull ?? widget.station;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Station Info Card
                _buildStationInfoCard(currentStation),
                
                const SizedBox(height: 16),
                
                // Location Info Card
                _buildLocationCard(currentStation),
                
                const SizedBox(height: 16),
                
                // Accuracy Info Card
                _buildAccuracyCard(currentStation),
                
                const SizedBox(height: 16),
                
                // Technical Details Card
                _buildTechnicalCard(currentStation),
                
                const SizedBox(height: 16),
                
                // History Section
                _buildHistorySection(gnssProvider, currentStation),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStationInfoCard(GnssStation station) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.satellite_alt,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Station Information',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Station ID', station.id),
            _buildInfoRow('Station Name', station.name),
            _buildInfoRow('Status', station.statusDisplay),
            _buildInfoRow('Last Updated', _formatUpdateTime(station.updatedAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(GnssStation station) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Location Details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Coordinates', station.coordinatesString),
            _buildInfoRow('Latitude', '${station.latitude.toStringAsFixed(6)}°'),
            _buildInfoRow('Longitude', '${station.longitude.toStringAsFixed(6)}°'),
            if (station.elevation != null)
              _buildInfoRow('Elevation', '${station.elevation!.toStringAsFixed(2)} m'),
          ],
        ),
      ),
    );
  }

  Widget _buildAccuracyCard(GnssStation station) {
    final isAccurate = station.isAccurate;
    final accuracyColor = isAccurate ? Colors.green : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAccurate ? Icons.check_circle : Icons.warning,
                  color: accuracyColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Accuracy Information',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              'Current Accuracy',
              station.accuracyString,
              valueColor: accuracyColor,
            ),
            _buildInfoRow(
              'Accuracy Status',
              isAccurate ? 'Good (≤ 5.0m)' : 'Poor (> 5.0m)',
              valueColor: accuracyColor,
            ),
            if (station.signalStrength != null)
              _buildInfoRow(
                'Signal Strength',
                '${station.signalStrength!.toStringAsFixed(1)} dB',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicalCard(GnssStation station) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Technical Details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (station.satelliteCount != null)
              _buildInfoRow('Satellites in View', '${station.satelliteCount}'),
            _buildInfoRow('Data Source', 'NASA CDDIS Real-time'),
            _buildInfoRow('Update Frequency', 'Every 1-5 seconds'),
            _buildInfoRow('Coordinate System', 'WGS84'),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(GnssProvider gnssProvider, GnssStation station) {
    final history = gnssProvider.accuracyHistory
        .where((h) => h.stationId == station.id)
        .take(10)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent History',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (history.isEmpty)
              const Text('No history data available')
            else
              ...history.map((h) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${h.timestamp.hour.toString().padLeft(2, '0')}:${h.timestamp.minute.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '${h.accuracy.toStringAsFixed(2)}m',
                      style: TextStyle(
                        color: h.accuracy <= 5.0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: valueColor,
                fontWeight: valueColor != null ? FontWeight.w500 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatUpdateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
