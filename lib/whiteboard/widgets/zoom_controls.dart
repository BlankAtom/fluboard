import 'package:flutter/material.dart';

/// Floating zoom controls: zoom in/out buttons, the current zoom percentage and
/// a reset-view action.
class ZoomControls extends StatelessWidget {
  const ZoomControls({
    super.key,
    required this.scale,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  /// Current view scale, where 1.0 == 100%.
  final double scale;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Zoom in',
            icon: const Icon(Icons.add),
            onPressed: onZoomIn,
          ),
          Text(
            '${(scale * 100).round()}%',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          IconButton(
            tooltip: 'Zoom out',
            icon: const Icon(Icons.remove),
            onPressed: onZoomOut,
          ),
          IconButton(
            tooltip: 'Reset view',
            icon: const Icon(Icons.center_focus_strong_outlined),
            onPressed: onReset,
          ),
        ],
      ),
    );
  }
}
