import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'board_models.dart';

/// Holds the whiteboard state: the list of items, the active tool, the current
/// pen settings, the selection and which node (if any) has its properties panel
/// open. Widgets listen to this to rebuild on change.
class BoardController extends ChangeNotifier {
  final List<BoardItem> items = <BoardItem>[];

  BoardTool _tool = BoardTool.select;
  BoardTool get tool => _tool;
  set tool(BoardTool value) {
    if (_tool == value) return;
    _tool = value;
    _selectedId = null;
    _propertiesNodeId = null;
    notifyListeners();
  }

  Color _penColor = Colors.black;
  Color get penColor => _penColor;
  set penColor(Color value) {
    if (_penColor == value) return;
    _penColor = value;
    notifyListeners();
  }

  double _penWidth = 4;
  double get penWidth => _penWidth;
  set penWidth(double value) {
    if (_penWidth == value) return;
    _penWidth = value;
    notifyListeners();
  }

  String? _selectedId;
  String? get selectedId => _selectedId;
  void select(String? id) {
    if (_selectedId == id) return;
    _selectedId = id;
    notifyListeners();
  }

  /// The node whose properties side panel is currently visible, if any.
  String? _propertiesNodeId;
  String? get propertiesNodeId => _propertiesNodeId;
  Node? get propertiesNode => nodeById(_propertiesNodeId);

  void openProperties(String id) {
    _selectedId = id;
    _propertiesNodeId = id;
    notifyListeners();
  }

  void closeProperties() {
    if (_propertiesNodeId == null) return;
    _propertiesNodeId = null;
    notifyListeners();
  }

  Node? nodeById(String? id) {
    if (id == null) return null;
    for (final item in items) {
      if (item is Node && item.id == id) return item;
    }
    return null;
  }

  int _idCounter = 0;
  String _nextId() => 'item_${_idCounter++}_${DateTime.now().microsecondsSinceEpoch}';

  int _nodeCount = 0;

  /// Nodes that should be re-positioned so the given board point becomes their
  /// center, once their rendered size is known. Keyed by node id.
  final Map<String, Offset> _pendingCenter = <String, Offset>{};

  /// Whether [id] is still waiting to be centered on its creation point. While
  /// true the card paints centered (via a fractional translation) so there is
  /// no visible jump when the real position is applied.
  bool isPendingCenter(String id) => _pendingCenter.containsKey(id);

  // --- Node mutations ----------------------------------------------------

  Node addNode(Offset position, {bool centered = false}) {
    _nodeCount++;
    final node = Node(
      id: _nextId(),
      position: position,
      model: NodeModel(name: 'Node $_nodeCount'),
    );
    if (centered) _pendingCenter[node.id] = position;
    items.add(node);
    _selectedId = node.id;
    notifyListeners();
    return node;
  }

  /// Called by a node's card once its [size] is measured. If the node was
  /// created "centered", shifts it so [size] is centered on the click point.
  void centerIfPending(Node node, Size size) {
    final center = _pendingCenter.remove(node.id);
    if (center == null) return;
    
    node.position = center - Offset(size.width / 2, size.height / 2);
    notifyListeners();
  }

  void setNodeName(Node node, String name) {
    node.model.name = name;
    notifyListeners();
  }

  void setNodeSummary(Node node, String summary) {
    node.model.summary = summary;
    notifyListeners();
  }

  void setNodeImage(Node node, Uint8List? bytes) {
    node.model.img = bytes;
    notifyListeners();
  }

  void addTag(Node node, String tag) {
    final value = tag.trim();
    if (value.isEmpty || node.model.tags.contains(value)) return;
    node.model.tags.add(value);
    notifyListeners();
  }

  void removeTag(Node node, String tag) {
    node.model.tags.remove(tag);
    notifyListeners();
  }

  // --- Stroke / generic mutations ---------------------------------------

  StrokeItem beginStroke(Offset point) {
    final stroke = StrokeItem(
      id: _nextId(),
      points: <Offset>[point],
      color: _penColor,
      strokeWidth: _penWidth,
    );
    items.add(stroke);
    notifyListeners();
    return stroke;
  }

  void extendStroke(StrokeItem stroke, Offset point) {
    stroke.points.add(point);
    notifyListeners();
  }

  void moveItem(BoardItem item, Offset delta) {
    item.position += delta;
    notifyListeners();
  }

  void remove(BoardItem item) {
    items.remove(item);
    if (_selectedId == item.id) _selectedId = null;
    if (_propertiesNodeId == item.id) _propertiesNodeId = null;
    notifyListeners();
  }

  void clear() {
    items.clear();
    _selectedId = null;
    _propertiesNodeId = null;
    notifyListeners();
  }
}
