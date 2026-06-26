import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'board_controller.dart';
import 'board_models.dart';
import 'board_painters.dart';

/// Size of the underlying scrollable canvas. It is large enough to feel
/// "infinite" while keeping coordinates positive and finite.
const double _kCanvasSize = 100000;

/// How much a mouse-wheel notch changes the zoom. This is
/// [InteractiveViewer.scaleFactor]; the Flutter default is 200. A *larger*
/// value means a *smaller* zoom step per wheel notch.
const double _kWheelScaleFactor = 800;

/// Preset colors offered in the toolbar.
const List<Color> _kPalette = <Color>[
  Colors.black,
  Color(0xFFE53935), // red
  Color(0xFF1E88E5), // blue
  Color(0xFF43A047), // green
  Color(0xFFFB8C00), // orange
  Color(0xFF8E24AA), // purple
];

class WhiteboardPage extends StatefulWidget {
  const WhiteboardPage({super.key});

  @override
  State<WhiteboardPage> createState() => _WhiteboardPageState();
}

class _WhiteboardPageState extends State<WhiteboardPage> {
  final BoardController _controller = BoardController();
  final TransformationController _tc = TransformationController();

  StrokeItem? _activeStroke;
  bool _centered = false;

  @override
  void dispose() {
    _controller.dispose();
    _tc.dispose();
    super.dispose();
  }

  double get _scale => _tc.value.getMaxScaleOnAxis();

  /// Centers the view on the middle of the canvas once we know the viewport.
  void _centerOnce(Size viewport) {
    if (_centered) return;
    _centered = true;
    const c = _kCanvasSize / 2;
    _tc.value = Matrix4.identity()
      ..translateByDouble(viewport.width / 2 - c, viewport.height / 2 - c, 0, 1);
  }

  Rect _sceneViewport(Size size) {
    final tl = _tc.toScene(Offset.zero);
    final br = _tc.toScene(Offset(size.width, size.height));
    return Rect.fromPoints(tl, br);
  }

  // --- Pointer handling on the canvas ------------------------------------

  void _onPointerDown(PointerDownEvent e) {
    final tool = _controller.tool;
    if (tool == BoardTool.pen) {
      _activeStroke = _controller.beginStroke(e.localPosition);
    } else if (tool == BoardTool.eraser) {
      _eraseAt(e.localPosition);
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    final tool = _controller.tool;
    if (tool == BoardTool.pen && _activeStroke != null) {
      _controller.extendStroke(_activeStroke!, e.localPosition);
    } else if (tool == BoardTool.eraser) {
      _eraseAt(e.localPosition);
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    _activeStroke = null;
  }

  void _eraseAt(Offset scenePoint) {
    for (final item in _controller.items.reversed.toList()) {
      if (item is StrokeItem) {
        final threshold = item.strokeWidth / 2 + 10;
        if (item.points.any((p) => (p - scenePoint).distance < threshold)) {
          _controller.remove(item);
        }
      }
    }
  }

  void _onCanvasTap(TapUpDetails details) {
    switch (_controller.tool) {
      case BoardTool.node:
        _controller.addNode(details.localPosition);
        _controller.tool = BoardTool.select;
        break;
      case BoardTool.select:
        _controller.select(null);
        _controller.closeProperties();
        break;
      case BoardTool.pen:
      case BoardTool.eraser:
        break;
    }
  }

  /// Double-tapping the empty board background drops a new node there.
  void _onCanvasDoubleTap(TapDownDetails details) {
    if (_controller.tool == BoardTool.pen ||
        _controller.tool == BoardTool.eraser) {
      return;
    }
    _controller.addNode(details.localPosition, centered: true);
  }

  // --- Zoom controls ------------------------------------------------------

  void _zoom(double factor) {
    final size = (context.findRenderObject() as RenderBox?)?.size;
    if (size == null) return;
    final focal = _tc.toScene(size.center(Offset.zero));
    final m = _tc.value.clone()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(factor, factor, factor, 1)
      ..translateByDouble(-focal.dx, -focal.dy, 0, 1);
    final next = m.getMaxScaleOnAxis();
    if (next < 0.2 || next > 6) return;
    _tc.value = m;
  }

  void _resetView() {
    _centered = false;
    final size = (context.findRenderObject() as RenderBox?)?.size;
    if (size != null) _centerOnce(size);
  }

  // --- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: AnimatedBuilder(
          // Listen to the transformation controller too so the zoom-percentage
          // indicator updates immediately when the user zooms.
          animation: Listenable.merge([_controller, _tc]),
          builder: (context, _) {
            final panelOpen = _controller.propertiesNode != null;
            return Stack(
              children: <Widget>[
                _buildCanvas(),
                Positioned(left: 12, top: 12, child: _buildToolbar()),
                Positioned(
                  right: panelOpen ? 332 : 12,
                  bottom: 12,
                  child: _buildZoomControls(),
                ),
                if (panelOpen)
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: _PropertiesPanel(
                      key: ValueKey(_controller.propertiesNode!.id),
                      node: _controller.propertiesNode!,
                      controller: _controller,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        WidgetsBinding.instance.addPostFrameCallback((_) => _centerOnce(viewport));

        return AnimatedBuilder(
          animation: Listenable.merge([_controller, _tc]),
          builder: (context, _) {
            final interactive = _controller.tool == BoardTool.select;
            return Stack(
              children: [
                // Grid background, drawn in screen space but aligned to scene.
                Positioned.fill(
                  child: CustomPaint(
                    painter: GridPainter(viewport: _sceneViewport(viewport)),
                  ),
                ),
                InteractiveViewer(
                  transformationController: _tc,
                  constrained: false,
                  minScale: 0.2,
                  maxScale: 6,
                  scaleFactor: _kWheelScaleFactor,
                  panEnabled: interactive,
                  scaleEnabled: interactive,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  child: SizedBox(
                    width: _kCanvasSize,
                    height: _kCanvasSize,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapUp: _onCanvasTap,
                      onDoubleTapDown: _onCanvasDoubleTap,
                      child: Listener(
                        onPointerDown: _onPointerDown,
                        onPointerMove: _onPointerMove,
                        onPointerUp: _onPointerUp,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Freehand strokes.
                            Positioned.fill(
                              child: CustomPaint(
                                painter: StrokePainter(
                                  strokes: _controller.items
                                      .whereType<StrokeItem>()
                                      .toList(),
                                  repaint: _controller,
                                ),
                              ),
                            ),
                            // Nodes (text/image cards).
                            for (final item in _controller.items)
                              if (item is! StrokeItem) _buildItem(item),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildItem(BoardItem item) {
    final selected = _controller.selectedId == item.id;
    return Positioned(
      left: item.position.dx,
      top: item.position.dy,
      child: switch (item) {
        Node n => _NodeCard(
            key: ValueKey(n.id),
            node: n,
            selected: selected,
            controller: _controller,
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  // --- Toolbar ------------------------------------------------------------

  Widget _buildToolbar() {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _toolButton(BoardTool.select, Icons.pan_tool_alt_outlined, 'Move'),
            _toolButton(BoardTool.pen, Icons.edit_outlined, 'Pen'),
            _toolButton(BoardTool.eraser, Icons.cleaning_services_outlined, 'Eraser'),
            _toolButton(BoardTool.node, Icons.add_box_outlined, 'Add node'),
            const _Divider(),
            _buildColorPicker(),
            _buildWidthPicker(),
            const _Divider(),
            IconButton(
              tooltip: 'Clear board',
              icon: const Icon(Icons.delete_outline),
              onPressed: _controller.items.isEmpty ? null : _confirmClear,
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolButton(BoardTool tool, IconData icon, String tip) {
    final active = _controller.tool == tool;
    return IconButton(
      tooltip: tip,
      isSelected: active,
      style: IconButton.styleFrom(
        backgroundColor: active ? const Color(0xFFE8F0FE) : null,
        foregroundColor: active ? const Color(0xFF1E88E5) : null,
      ),
      icon: Icon(icon),
      onPressed: () => _controller.tool = tool,
    );
  }

  Widget _buildColorPicker() {
    return PopupMenuButton<Color>(
      tooltip: 'Color',
      onSelected: (c) => _controller.penColor = c,
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
                    _controller.penColor = c;
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _controller.penColor == c
                            ? const Color(0xFF1E88E5)
                            : Colors.black12,
                        width: _controller.penColor == c ? 3 : 1,
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
            color: _controller.penColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black26),
          ),
        ),
      ),
    );
  }

  Widget _buildWidthPicker() {
    return PopupMenuButton<double>(
      tooltip: 'Stroke width',
      icon: const Icon(Icons.line_weight),
      onSelected: (w) => _controller.penWidth = w,
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

  Widget _buildZoomControls() {
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
            onPressed: () => _zoom(1.2),
          ),
          Text('${(_scale * 100).round()}%',
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
          IconButton(
            tooltip: 'Zoom out',
            icon: const Icon(Icons.remove),
            onPressed: () => _zoom(1 / 1.2),
          ),
          IconButton(
            tooltip: 'Reset view',
            icon: const Icon(Icons.center_focus_strong_outlined),
            onPressed: _resetView,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear board?'),
        content: const Text('This removes every item from the whiteboard.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok ?? false) _controller.clear();
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

/// The **UI surface** of a node: a card. The image (when present) sits on the
/// left, the name is the bold required heading, with the summary and tags
/// beneath. Handles tap (focus border), double-tap (open properties),
/// right-click (context menu) and drag (move on the board).
class _NodeCard extends StatefulWidget {
  const _NodeCard({
    super.key,
    required this.node,
    required this.selected,
    required this.controller,
  });

  final Node node;
  final bool selected;
  final BoardController controller;

  @override
  State<_NodeCard> createState() => _NodeCardState();
}

class _NodeCardState extends State<_NodeCard> {
  final GlobalKey _cardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Once the card has been laid out we know its real size, so a node that
    // was created "centered" on a click point can be shifted accordingly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = _cardKey.currentContext?.size;
      if (size != null) {
        widget.controller.centerIfPending(widget.node, size);
      }
    });
  }

  Future<void> _showContextMenu(BuildContext context, Offset globalPos) async {
    final node = widget.node;
    final controller = widget.controller;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy,
        globalPos.dx,
        globalPos.dy,
      ),
      items: const [
        PopupMenuItem<String>(
          value: 'properties',
          child: Row(
            children: [
              Icon(Icons.tune, size: 18),
              SizedBox(width: 8),
              Text('Properties'),
            ],
          ),
        ),
      ],
    );
    if (choice == 'properties') controller.openProperties(node.id);
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final controller = widget.controller;
    final selected = widget.selected;
    final model = node.model;
    final name = model.name.trim().isEmpty ? 'Untitled' : model.name;
    final card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => controller.select(node.id),
      onDoubleTap: () => controller.openProperties(node.id),
      onSecondaryTapDown: (d) => _showContextMenu(context, d.globalPosition),
      // The gesture detector lives inside the InteractiveViewer's transformed
      // child, so `delta` is already in board (scene) coordinates. Use it
      // directly so the card tracks the cursor at any zoom level.
      onPanUpdate: (d) => controller.moveItem(node, d.delta),
      child: Container(
        key: _cardKey,
        constraints: const BoxConstraints(minWidth: 160, maxWidth: 280),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF1E88E5) : const Color(0xFFE0E3E8),
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),

        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (model.img != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  model.img!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1F2430),
                    ),
                  ),
                  if (model.summary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      model.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                  if (model.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final tag in model.tags) _TagChip(label: tag),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // While the centering position is still pending we offset the card by half
    // its own size, so it paints centered on the click point from the very
    // first frame. Once the real top-left position is applied the pixels are
    // identical, so there is no visible jump.
    if (controller.isPendingCenter(node.id)) {
      return FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: card,
      );
    }
    return card;
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF1FB),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF1E88E5)),
        ),
      );
}

/// Side panel docked to the right of the window for editing a node's model
/// surface: image, name (required), summary and tags.
class _PropertiesPanel extends StatefulWidget {
  const _PropertiesPanel({
    super.key,
    required this.node,
    required this.controller,
  });

  final Node node;
  final BoardController controller;

  @override
  State<_PropertiesPanel> createState() => _PropertiesPanelState();
}

class _PropertiesPanelState extends State<_PropertiesPanel> {
  late final TextEditingController _name =
      TextEditingController(text: widget.node.model.name);
  late final TextEditingController _summary =
      TextEditingController(text: widget.node.model.summary);
  final TextEditingController _tagInput = TextEditingController();

  Node get _node => widget.node;
  BoardController get _c => widget.controller;

  @override
  void dispose() {
    _name.dispose();
    _summary.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    _c.setNodeImage(_node, bytes);
  }

  void _submitTag() {
    _c.addTag(_node, _tagInput.text);
    _tagInput.clear();
  }

  @override
  Widget build(BuildContext context) {
    final model = _node.model;
    return Material(
      elevation: 8,
      color: Colors.white,
      child: SizedBox(
        width: 320,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE0E3E8))),
              ),
              child: Row(
                children: [
                  const Text(
                    'Properties',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Delete node',
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _c.remove(_node),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: _c.closeProperties,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _label('Image'),
                  const SizedBox(height: 6),
                  if (model.img != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        model.img!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: Text(model.img == null ? 'Add image' : 'Replace'),
                      ),
                      if (model.img != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => _c.setNodeImage(_node, null),
                          child: const Text('Remove'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  _label('Name *'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _name,
                    decoration: InputDecoration(
                      isDense: true,
                      border: const OutlineInputBorder(),
                      hintText: 'Required',
                      errorText: _name.text.trim().isEmpty
                          ? 'Name is required'
                          : null,
                    ),
                    onChanged: (v) => setState(() => _c.setNodeName(_node, v)),
                  ),
                  const SizedBox(height: 18),
                  _label('Summary'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _summary,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      hintText: 'Short description',
                    ),
                    onChanged: (v) => _c.setNodeSummary(_node, v),
                  ),
                  const SizedBox(height: 18),
                  _label('Tags'),
                  const SizedBox(height: 6),
                  if (model.tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in model.tags)
                          Chip(
                            label: Text(tag),
                            onDeleted: () => _c.removeTag(_node, tag),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tagInput,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            hintText: 'Add a tag',
                          ),
                          onSubmitted: (_) => _submitTag(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _submitTag,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: Colors.black87,
        ),
      );
}
