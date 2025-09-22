import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/realtime_provider.dart';
import '../widgets/gnss_map_widget.dart';

class RealtimeMapTab extends StatefulWidget {
  const RealtimeMapTab({super.key});

  @override
  State<RealtimeMapTab> createState() => _RealtimeMapTabState();
}

class _RealtimeMapTabState extends State<RealtimeMapTab> {
  GnssStationMarker? _selectedStation;

  @override
  Widget build(BuildContext context) {
    return Consumer<RealtimeProvider>(
      builder: (context, provider, child) {
        if (!provider.isConnected) {
          return _buildEmptyState();
        }

        if (provider.stations.isEmpty) {
          return _buildWaitingState();
        }

        return Stack(
          children: [
            GnssMapWidget(
              stations: provider.stations,
              onStationTap: (station) {
                setState(() {
                  _selectedStation = station;
                });
              },
            ),
            
            // Station info popup
            if (_selectedStation != null)
              Positioned(
                top: 16,
                right: 16,
                child: StationInfoPopup(
                  station: _selectedStation!,
                  onClose: () {
                    setState(() {
                      _selectedStation = null;
                    });
                  },
                ),
              ),
              
            // Connection overlay
            Positioned(
              top: 16,
              left: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Live Stream',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (provider.streamStats.isNotEmpty) ...[
                        Text(
                          '${provider.streamStats['bitrateKbps']} kbps',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '${provider.streamStats['frames']} frames',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.satellite_alt_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'Not Connected to NTRIP',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to an NTRIP caster to see real-time station positions',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // This will expand the connection panel
                // You could use a callback or state management here
              },
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('Configure Connection'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Waiting for Station Data...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Receiving RTCM stream and parsing station positions',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
