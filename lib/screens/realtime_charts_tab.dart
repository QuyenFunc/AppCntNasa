import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/realtime_provider.dart';
import 'dart:async';

class RealtimeChartsTab extends StatefulWidget {
  const RealtimeChartsTab({super.key});

  @override
  State<RealtimeChartsTab> createState() => _RealtimeChartsTabState();
}

class _RealtimeChartsTabState extends State<RealtimeChartsTab> {
  bool _autoRefresh = true;
  int _refreshInterval = 2; // seconds
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    if (_autoRefresh) {
      _refreshTimer = Timer.periodic(
        Duration(seconds: _refreshInterval),
        (timer) {
          if (mounted) {
            setState(() {
              // Trigger rebuild to update charts
            });
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RealtimeProvider>(
      builder: (context, provider, child) {
        if (!provider.isConnected) {
          return _buildEmptyState();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Controls
              _buildControlsCard(),
              const SizedBox(height: 16),
              
              // Bitrate chart
              _buildBitrateChart(provider),
              const SizedBox(height: 16),
              
              // Frame count chart
              _buildFrameChart(provider),
              const SizedBox(height: 16),
              
              // Message types chart
              _buildMessageTypesChart(provider),
              const SizedBox(height: 16),
              
              // Statistics summary
              _buildStatsSummary(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chart Controls',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    title: const Text('Auto Refresh'),
                    subtitle: const Text('Update charts automatically'),
                    value: _autoRefresh,
                    onChanged: (value) {
                      setState(() {
                        _autoRefresh = value;
                        _startAutoRefresh();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Refresh Interval',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      DropdownButton<int>(
                        value: _refreshInterval,
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1 second')),
                          DropdownMenuItem(value: 2, child: Text('2 seconds')),
                          DropdownMenuItem(value: 5, child: Text('5 seconds')),
                          DropdownMenuItem(value: 10, child: Text('10 seconds')),
                        ],
                        onChanged: _autoRefresh ? (value) {
                          setState(() {
                            _refreshInterval = value!;
                            _startAutoRefresh();
                          });
                        } : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBitrateChart(RealtimeProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bitrate (kbps)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: provider.bitrateHistory.isEmpty
                  ? const Center(child: Text('No data available'))
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(show: true),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < provider.bitrateHistory.length) {
                                  final time = provider.bitrateHistory[index].timestamp;
                                  return Text(
                                    '${time.minute}:${time.second.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 10),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots: provider.bitrateHistory.asMap().entries.map((e) {
                              return FlSpot(e.key.toDouble(), e.value.value);
                            }).toList(),
                            isCurved: true,
                            color: Theme.of(context).primaryColor,
                            barWidth: 2,
                            belowBarData: BarAreaData(
                              show: true,
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrameChart(RealtimeProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Frame Count',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: provider.frameHistory.isEmpty
                  ? const Center(child: Text('No data available'))
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(show: true),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < provider.frameHistory.length) {
                                  final time = provider.frameHistory[index].timestamp;
                                  return Text(
                                    '${time.minute}:${time.second.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 10),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots: provider.frameHistory.asMap().entries.map((e) {
                              return FlSpot(e.key.toDouble(), e.value.value);
                            }).toList(),
                            isCurved: true,
                            color: Colors.orange,
                            barWidth: 2,
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.orange.withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageTypesChart(RealtimeProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RTCM Message Types',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: provider.messageTypeStats.isEmpty
                  ? const Center(child: Text('No data available'))
                  : PieChart(
                      PieChartData(
                        sections: provider.messageTypeStats.entries.map((entry) {
                          final colors = [
                            Colors.blue,
                            Colors.red,
                            Colors.green,
                            Colors.orange,
                            Colors.purple,
                            Colors.teal,
                          ];
                          final colorIndex = entry.key % colors.length;
                          
                          return PieChartSectionData(
                            value: entry.value.toDouble(),
                            title: '${entry.key}',
                            color: colors[colorIndex],
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
            ),
            if (provider.messageTypeStats.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: provider.messageTypeStats.entries.map((entry) {
                    final colors = [
                      Colors.blue,
                      Colors.red,
                      Colors.green,
                      Colors.orange,
                      Colors.purple,
                      Colors.teal,
                    ];
                    final colorIndex = entry.key % colors.length;
                    
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: colors[colorIndex],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text('${entry.key}: ${entry.value}'),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSummary(RealtimeProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection Statistics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (provider.streamStats.isNotEmpty) ...[
              _buildStatRow('Total Frames', provider.streamStats['frames']?.toString() ?? '0'),
              _buildStatRow('Total Bytes', provider.streamStats['bytes']?.toString() ?? '0'),
              _buildStatRow('Current Bitrate', '${provider.streamStats['bitrateKbps'] ?? '0'} kbps'),
              _buildStatRow('Message Types', provider.streamStats['messageCount']?.toString() ?? '0'),
            ] else
              const Text('No statistics available'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Chart Data Available',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect to an NTRIP stream to see real-time charts and statistics',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
