import 'package:flutter/material.dart';

class MapControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onCenterOnUser;
  final VoidCallback onToggleAccuracyCircles;
  final VoidCallback onToggleInaccurateOnly;
  final bool showAccuracyCircles;
  final bool showOnlyInaccurate;

  const MapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onCenterOnUser,
    required this.onToggleAccuracyCircles,
    required this.onToggleInaccurateOnly,
    required this.showAccuracyCircles,
    required this.showOnlyInaccurate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Zoom controls
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildControlButton(
                icon: Icons.add,
                onPressed: onZoomIn,
                tooltip: 'Zoom In',
              ),
              Container(
                height: 1,
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
              _buildControlButton(
                icon: Icons.remove,
                onPressed: onZoomOut,
                tooltip: 'Zoom Out',
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Location button
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _buildControlButton(
            icon: Icons.my_location,
            onPressed: onCenterOnUser,
            tooltip: 'Center on Location',
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Toggle controls
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToggleButton(
                context,
                icon: Icons.radio_button_unchecked,
                activeIcon: Icons.radio_button_checked,
                isActive: showAccuracyCircles,
                onPressed: onToggleAccuracyCircles,
                tooltip: 'Toggle Accuracy Circles',
              ),
              Container(
                height: 1,
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
              _buildToggleButton(
                context,
                icon: Icons.warning_outlined,
                activeIcon: Icons.warning,
                isActive: showOnlyInaccurate,
                onPressed: onToggleInaccurateOnly,
                tooltip: 'Show Only Inaccurate Stations',
                activeColor: Colors.red,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    Color? iconColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required bool isActive,
    required VoidCallback onPressed,
    required String tooltip,
    Color? activeColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Icon(
              isActive ? activeIcon : icon,
              size: 20,
              color: isActive 
                  ? (activeColor ?? Theme.of(context).colorScheme.primary)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
