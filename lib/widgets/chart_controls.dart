import 'package:flutter/material.dart';
import '../screens/charts_screen.dart';

class ChartControls extends StatelessWidget {
  final ChartType chartType;
  final Duration timeRange;
  final Function(ChartType) onChartTypeChanged;
  final Function(Duration) onTimeRangeChanged;

  const ChartControls({
    super.key,
    required this.chartType,
    required this.timeRange,
    required this.onChartTypeChanged,
    required this.onTimeRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart Type Selector
          Row(
            children: [
              Text(
                'Chart Type:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildChartTypeChip(
                        context,
                        'Accuracy',
                        ChartType.accuracy,
                        Icons.gps_fixed,
                      ),
                      const SizedBox(width: 8),
                      _buildChartTypeChip(
                        context,
                        'Signal',
                        ChartType.signalStrength,
                        Icons.signal_cellular_4_bar,
                      ),
                      const SizedBox(width: 8),
                      _buildChartTypeChip(
                        context,
                        'Combined',
                        ChartType.combined,
                        Icons.analytics,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Time Range Selector
          Row(
            children: [
              Text(
                'Time Range:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTimeRangeChip(
                        context,
                        '1H',
                        const Duration(hours: 1),
                      ),
                      const SizedBox(width: 8),
                      _buildTimeRangeChip(
                        context,
                        '6H',
                        const Duration(hours: 6),
                      ),
                      const SizedBox(width: 8),
                      _buildTimeRangeChip(
                        context,
                        '24H',
                        const Duration(hours: 24),
                      ),
                      const SizedBox(width: 8),
                      _buildTimeRangeChip(
                        context,
                        '3D',
                        const Duration(days: 3),
                      ),
                      const SizedBox(width: 8),
                      _buildTimeRangeChip(
                        context,
                        '1W',
                        const Duration(days: 7),
                      ),
                      const SizedBox(width: 8),
                      _buildTimeRangeChip(
                        context,
                        '1M',
                        const Duration(days: 30),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartTypeChip(
    BuildContext context,
    String label,
    ChartType type,
    IconData icon,
  ) {
    final isSelected = chartType == type;
    
    return GestureDetector(
      onTap: () => onChartTypeChanged(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected 
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected 
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeChip(
    BuildContext context,
    String label,
    Duration duration,
  ) {
    final isSelected = timeRange == duration;
    
    return GestureDetector(
      onTap: () => onTimeRangeChanged(duration),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.secondary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected 
                ? Theme.of(context).colorScheme.onSecondary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
