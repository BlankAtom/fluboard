import 'package:flutter/material.dart';

import '../board_controller.dart';
import '../board_models.dart';

/// Preset colors offered in the toolbar.
const List<Color> _kPalette = <Color>[
  Colors.black,
  Color(0xFFE53935), // red
  Color(0xFF1E88E5), // blue
  Color(0xFF43A047), // green
  Color(0xFFFB8C00), // orange
  Color(0xFF8E24AA), // purple
];

/// Floating toolbar with tool selection, pen color/width pickers and a clear
/// action. Reads its state from [controller] and is rebuilt by the parent when
/// the controller notifies.
class BoardToolbar extends StatelessWidget {
  const BoardToolbar({
    super.key,
    required this.controller,
    required this.onClear,
  });

  final BoardController controller;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolButton(controller, BoardTool.select,
                Icons.pan_tool_alt_outlined, 'Move'),
            _ToolButton(controller, BoardTool.pen, Icons.edit_outlined, 'Pen'),
            _ToolButton(controller, BoardTool.eraser,
                Icons.cleaning_services_outlined, 'Eraser'),
            _ToolButton(controller, BoardTool.node, Icons.add_box_outlined,
                'Add node'),
            const _Divider(),
            _ColorPicker(controller),
            _WidthPicker(controller),
            const _Divider(),
            IconButton(
              tooltip: 'Clear board',
              icon: const Icon(Icons.delete_outline),
              onPressed: controller.items.isEmpty ? null : onClear,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton(this.controller, this.tool, this.icon, this.tip);

  final BoardController controller;
  final BoardTool tool;
  final IconData icon;
  final String tip;

  @override
  Widget build(BuildContext context) {
    final active = controller.tool == tool;
    return IconButton(
      tooltip: tip,
      isSelected: active,
      style: IconButton.styleFrom(
        backgroundColor: active ? const Color(0xFFE8F0FE) : null,
        foregroundColor: active ? const Color(0xFF1E88E5) : null,
      ),
      icon: Icon(icon),
      onPressed: () => controller.tool = tool,
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker(this.controller);

  final BoardController controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Color>(
      tooltip: 'Color',
      onSelected: (c) => controller.penColor = c,
      itemBuilder: (context) => [
        PopupMenuItem<Color>(
          enabled: false,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _kPalette)
                GestureDetector(
                  onTap: () {
                    controller.penColor = c;
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: controller.penColor == c
                            ? const Color(0xFF1E88E5)
                            : Colors.black12,
                        width: controller.penColor == c ? 3 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: controller.penColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black26),
          ),
        ),
      ),
    );
  }
}

class _WidthPicker extends StatelessWidget {
  const _WidthPicker(this.controller);

  final BoardController controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: 'Stroke width',
      icon: const Icon(Icons.line_weight),
      onSelected: (w) => controller.penWidth = w,
      itemBuilder: (context) => [
        for (final w in const [2.0, 4.0, 8.0, 14.0])
          PopupMenuItem<double>(
            value: w,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: w,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(w),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${w.toInt()} px'),
              ],
            ),
          ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: Colors.black12,
      );
}
