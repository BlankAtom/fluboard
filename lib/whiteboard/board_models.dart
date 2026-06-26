import 'dart:typed_data';

import 'package:flutter/material.dart';

/// The tool currently selected on the whiteboard toolbar.
enum BoardTool { select, pen, eraser, node }

/// Base class for anything that lives on the infinite board.
///
/// [position] is expressed in *board* (scene) coordinates, not screen pixels.
sealed class BoardItem {
  BoardItem({required this.id, required this.position});

  final String id;
  Offset position;
}

/// The **model surface** of a node: its editable data, with no UI concerns.
class NodeModel {
  NodeModel({
    required this.name,
    this.summary = '',
    this.img,
    List<String>? tags,
  }) : tags = tags ?? <String>[];

  /// Required, bold heading of the card. Always has a default on creation.
  String name;

  /// Optional longer description shown beneath the name.
  String summary;

  /// Optional image, rendered on the left of the card when present.
  Uint8List? img;

  /// Free-form labels shown as chips.
  List<String> tags;
}

/// A board node. Combines a [model] (the *model surface*) with a board
/// [position]; the *UI surface* is the card widget that renders this node.
class Node extends BoardItem {
  Node({required super.id, required super.position, required this.model});

  final NodeModel model;
}

/// A freehand stroke. Points are stored directly in board coordinates, so the
/// stroke's [position] is always the origin.
class StrokeItem extends BoardItem {
  StrokeItem({
    required super.id,
    required this.points,
    required this.color,
    required this.strokeWidth,
  }) : super(position: Offset.zero);

  final List<Offset> points;
  final Color color;
  final double strokeWidth;
}
