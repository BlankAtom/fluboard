import 'package:flutter/material.dart';

import 'board_controller.dart';
import 'board_models.dart';
import 'board_painters.dart';
import 'widgets/board_toolbar.dart';
import 'widgets/node_card.dart';
import 'widgets/properties_panel.dart';
import 'widgets/zoom_controls.dart';

/// Size of the underlying scrollable canvas. It is large enough to feel
/// "infinite" while keeping coordinates positive and finite.
const double _kCanvasSize = 100000;

/// How much a mouse-wheel notch changes the zoom. This is
/// [InteractiveViewer.scaleFactor]; the Flutter default is 200. A *larger*
/// value means a *smaller* zoom step per wheel notch.
const double _kWheelScaleFactor = 800;

/// Zoom limits shared by the [InteractiveViewer] and the manual zoom buttons.
const double _kMinScale = 0.2;
const double _kMaxScale = 6;

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
    return Rect.fromPoints(
      _tc.toScene(Offset.zero),
      _tc.toScene(Offset(size.width, size.height)),
    );
  }

  // --- Pointer handling on the canvas ------------------------------------

  void _onPointerDown(PointerDownEvent e) {
    switch (_controller.tool) {
      case BoardTool.pen:
        _activeStroke = _controller.beginStroke(e.localPosition);
      case BoardTool.eraser:
        _eraseAt(e.localPosition);
      case BoardTool.select:
      case BoardTool.node:
        break;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    switch (_controller.tool) {
      case BoardTool.pen:
        if (_activeStroke != null) {
          _controller.extendStroke(_activeStroke!, e.localPosition);
        }
      case BoardTool.eraser:
        _eraseAt(e.localPosition);
      case BoardTool.select:
      case BoardTool.node:
        break;
    }
  }

  void _onPointerUp(PointerUpEvent e) => _activeStroke = null;

  void _eraseAt(Offset scenePoint) {
    for (final item in _controller.items.reversed.toList()) {
      if (item is! StrokeItem) continue;
      final threshold = item.strokeWidth / 2 + 10;
      if (item.points.any((p) => (p - scenePoint).distance < threshold)) {
        _controller.remove(item);
      }
    }
  }

  void _onCanvasTap(TapUpDetails details) {
    switch (_controller.tool) {
      case BoardTool.node:
        _controller.addNode(details.localPosition);
        _controller.tool = BoardTool.select;
      case BoardTool.select:
        _controller.select(null);
        _controller.closeProperties();
      case BoardTool.pen:
      case BoardTool.eraser:
        break;
    }
  }

  /// Double-tapping the empty board background drops a new node there.
  void _onCanvasDoubleTap(TapDownDetails details) {
    final tool = _controller.tool;
    if (tool == BoardTool.pen || tool == BoardTool.eraser) return;
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
    if (next < _kMinScale || next > _kMaxScale) return;
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
                Positioned(
                  left: 12,
                  top: 12,
                  child: BoardToolbar(
                    controller: _controller,
                    onClear: _confirmClear,
                  ),
                ),
                Positioned(
                  right: panelOpen ? 332 : 12,
                  bottom: 12,
                  child: ZoomControls(
                    scale: _scale,
                    onZoomIn: () => _zoom(1.2),
                    onZoomOut: () => _zoom(1 / 1.2),
                    onReset: _resetView,
                  ),
                ),
                if (panelOpen)
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: PropertiesPanel(
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
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _centerOnce(viewport));

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
                  minScale: _kMinScale,
                  maxScale: _kMaxScale,
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
                              if (item is Node) _buildNode(item),
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

  Widget _buildNode(Node node) {
    return Positioned(
      left: node.position.dx,
      top: node.position.dy,
      child: NodeCard(
        key: ValueKey(node.id),
        node: node,
        selected: _controller.selectedId == node.id,
        controller: _controller,
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
