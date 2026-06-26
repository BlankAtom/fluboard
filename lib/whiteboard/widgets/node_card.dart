import 'package:flutter/material.dart';

import '../board_controller.dart';
import '../board_models.dart';

/// The **UI surface** of a node: a card. The image (when present) sits on the
/// left, the name is the bold required heading, with the summary and tags
/// beneath. Handles tap (focus border), double-tap (open properties),
/// right-click (context menu) and drag (move on the board).
class NodeCard extends StatefulWidget {
  const NodeCard({
    super.key,
    required this.node,
    required this.selected,
    required this.scale,
    required this.controller,
  });

  final Node node;
  final bool selected;
  final double scale;
  final BoardController controller;

  @override
  State<NodeCard> createState() => _NodeCardState();
}

class _NodeCardState extends State<NodeCard> {
  final GlobalKey _cardKey = GlobalKey();

  Node get _node => widget.node;
  BoardController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    // Once the card has been laid out we know its real size, so a node that
    // was created "centered" on a click point can be shifted accordingly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = _cardKey.currentContext?.size;
      if (size != null) _controller.centerIfPending(_node, size);
    });
  }

  Future<void> _showContextMenu(Offset globalPos) async {
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
    if (choice == 'properties') _controller.openProperties(_node.id);
  }

  @override
  Widget build(BuildContext context) {
    final card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.select(_node.id),
      onDoubleTap: () => _controller.openProperties(_node.id),
      onSecondaryTapDown: (d) => _showContextMenu(d.globalPosition),
      onPanUpdate: (d) => _controller.moveItem(_node, d.delta / widget.scale),
      child: _NodeCardBody(
        cardKey: _cardKey,
        model: _node.model,
        selected: widget.selected,
      ),
    );

    // While the centering position is still pending we offset the card by half
    // its own size, so it paints centered on the click point from the very
    // first frame. Once the real top-left position is applied the pixels are
    // identical, so there is no visible jump.
    if (_controller.isPendingCenter(_node.id)) {
      return FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: card,
      );
    }
    return card;
  }
}

/// The visual content of a node card, with no gesture handling. Split out so
/// the interactive [NodeCard] stays focused on behaviour.
class _NodeCardBody extends StatelessWidget {
  const _NodeCardBody({
    required this.cardKey,
    required this.model,
    required this.selected,
  });

  final Key cardKey;
  final NodeModel model;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final name = model.name.trim().isEmpty ? 'Untitled' : model.name;
    return Container(
      key: cardKey,
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
    );
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
