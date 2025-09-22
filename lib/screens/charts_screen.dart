import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/gnss_station.dart';
import '../providers/gnss_provider.dart';
import '../widgets/station_selector.dart';
import '../widgets/chart_controls.dart';

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> with TickerProviderStateMixin {
  GnssStation? _selectedStation;
  List<AccuracyDataPoint> _chartData = [];
  ChartType _chartType = ChartType.accuracy;
  Duration _timeRange = const Duration(hours: 24);
  bool _isAutoRefresh = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _loadInitialData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final gnssProvider = Provider.of<GnssProvider>(context, listen: false);
    if (gnssProvider.stations.isNotEmpty) {
      _selectedStation = gnssProvider.stations.first;
      await _loadChartData();
    }
  }

  Future<void> _loadChartData() async {
    if (_selectedStation == null) return;

    final gnssProvider = Provider.of<GnssProvider>(context, listen: false);
    final endTime = DateTime.now();
    final startTime = endTime.subtract(_timeRange);
    
    await gnssProvider.loadAccuracyHistory(
      _selectedStation!.id,
      startTime: startTime,
      endTime: endTime,
    );
    
    setState(() {
      _chartData = gnssProvider.accuracyHistory;
    });
    
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GNSS Analytics'),
        actions: [
          IconButton(
            onPressed: _toggleAutoRefresh,
            icon: Icon(
              _isAutoRefresh ? Icons.pause : Icons.play_arrow,
              color: _isAutoRefresh ? Colors.green : null,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_chart',
                child: Row(
                  children: [
                    Icon(Icons.file_download),
                    SizedBox(width: 8),
                    Text('Export Chart Data'),
                  ],
                ),
              ),
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
            ],
          ),
        ],
      ),
      body: Consumer<GnssProvider>(
        builder: (context, gnssProvider, child) {
          return Column(
            children: [
              // Station selector
              StationSelector(
                stations: gnssProvider.stations,
                selectedStation: _selectedStation,
                onStationSelected: (station) async {
                  setState(() {
                    _selectedStation = station;
                  });
                  await _loadChartData();
                },
              ),

              // Chart controls
              ChartControls(
                chartType: _chartType,
                timeRange: _timeRange,
                onChartTypeChanged: (type) {
                  setState(() {
                    _chartType = type;
                  });
                },
                onTimeRangeChanged: (range) async {
                  setState(() {
                    _timeRange = range;
                  });
                  await _loadChartData();
                },
              ),

              // Chart area
              Expanded(
                child: Container(
                  width: double.infinity,
                  child: _buildChartSection(gnssProvider),
                ),
              ),

              // Statistics panel
              _buildStatisticsPanel(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChartSection(GnssProvider gnssProvider) {
    if (gnssProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_selectedStation == null) {
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
              'Select a station to view analytics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_chartData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timeline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No data available for selected time range',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadChartData,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _animationController,
            child: _buildChart(),
          );
        },
      ),
    );
  }

  Widget _buildChart() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: () {
        switch (_chartType) {
          case ChartType.accuracy:
            return _buildAccuracyChart();
          case ChartType.signalStrength:
            return _buildSignalStrengthChart();
          case ChartType.combined:
            return _buildCombinedChart();
        }
      }(),
    );
  }

  Widget _buildAccuracyChart() {
    final spots = _chartData.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.accuracy,
      );
    }).toList();

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 1,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return const FlLine(
              color: Color(0xffe7e8ec),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return const FlLine(
              color: Color(0xffe7e8ec),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: _getBottomTitles,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toStringAsFixed(1)}m',
                  style: const TextStyle(
                    color: Color(0xff68737d),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              },
              reservedSize: 42,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xff37434d)),
        ),
        minX: 0,
        maxX: _chartData.length.toDouble() - 1,
        minY: 0,
        maxY: _getMaxAccuracy(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(
              show: false,
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.3),
            ),
          ),
          // Accuracy threshold line
          LineChartBarData(
            spots: [
              FlSpot(0, 5.0),
              FlSpot(_chartData.length.toDouble() - 1, 5.0),
            ],
            isCurved: false,
            color: Colors.red,
            barWidth: 2,
            dashArray: [5, 5],
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSignalStrengthChart() {
    final spots = _chartData.where((data) => data.signalStrength != null)
        .toList().asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.signalStrength!,
      );
    }).toList();

    if (spots.isEmpty) {
      return const Center(
        child: Text('No signal strength data available'),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: LineChart(
        LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: _getBottomTitles,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toStringAsFixed(0)} dB',
                  style: const TextStyle(
                    color: Color(0xff68737d),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              },
              reservedSize: 42,
            ),
          ),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.orange,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.orange.withOpacity(0.3),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildCombinedChart() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6, // Fixed height
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: _buildAccuracyChart(),
          ),
          const SizedBox(height: 16),
          Expanded(
            flex: 2,
            child: _buildSignalStrengthChart(),
          ),
        ],
      ),
    );
  }

  Widget _getBottomTitles(double value, TitleMeta meta) {
    if (value.toInt() >= _chartData.length) return const Text('');
    
    final dataPoint = _chartData[value.toInt()];
    final time = dataPoint.timestamp;
    
    return Text(
      '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
      style: const TextStyle(
        color: Color(0xff68737d),
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }

  double _getMaxAccuracy() {
    if (_chartData.isEmpty) return 10.0;
    return _chartData.map((d) => d.accuracy).reduce((a, b) => a > b ? a : b) + 1;
  }

  Widget _buildStatisticsPanel() {
    if (_chartData.isEmpty) return const SizedBox.shrink();

    final accuracyValues = _chartData.map((d) => d.accuracy).toList();
    final avgAccuracy = accuracyValues.reduce((a, b) => a + b) / accuracyValues.length;
    final minAccuracy = accuracyValues.reduce((a, b) => a < b ? a : b);
    final maxAccuracy = accuracyValues.reduce((a, b) => a > b ? a : b);
    final warningCount = accuracyValues.where((a) => a > 5.0).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicWidth(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('Average', '${avgAccuracy.toStringAsFixed(2)}m', Colors.blue),
                const SizedBox(width: 16),
                _buildStatItem('Best', '${minAccuracy.toStringAsFixed(2)}m', Colors.green),
                const SizedBox(width: 16),
                _buildStatItem('Worst', '${maxAccuracy.toStringAsFixed(2)}m', Colors.red),
                const SizedBox(width: 16),
                _buildStatItem('Warnings', '$warningCount', Colors.orange),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
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

  void _toggleAutoRefresh() {
    setState(() {
      _isAutoRefresh = !_isAutoRefresh;
    });
    
    if (_isAutoRefresh) {
      // Start auto refresh timer
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Auto-refresh enabled'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Auto-refresh disabled'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'export_chart':
        // Export chart data logic
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export feature coming soon'),
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case 'refresh':
        _loadChartData();
        break;
    }
  }
}

enum ChartType {
  accuracy,
  signalStrength,
  combined,
}
