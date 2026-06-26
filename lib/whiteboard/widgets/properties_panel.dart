import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../board_controller.dart';
import '../board_models.dart';

/// Side panel docked to the right of the window for editing a node's model
/// surface: image, name (required), summary and tags.
class PropertiesPanel extends StatefulWidget {
  const PropertiesPanel({
    super.key,
    required this.node,
    required this.controller,
  });

  final Node node;
  final BoardController controller;

  @override
  State<PropertiesPanel> createState() => _PropertiesPanelState();
}

class _PropertiesPanelState extends State<PropertiesPanel> {
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
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
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
    return Material(
      elevation: 8,
      color: Colors.white,
      child: SizedBox(
        width: 320,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(onDelete: () => _c.remove(_node), onClose: _c.closeProperties),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _label('Image'),
                  const SizedBox(height: 6),
                  _ImageField(
                    model: _node.model,
                    onPick: _pickImage,
                    onRemove: () => _c.setNodeImage(_node, null),
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
                      errorText:
                          _name.text.trim().isEmpty ? 'Name is required' : null,
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
                  _TagsField(
                    model: _node.model,
                    tagInput: _tagInput,
                    onSubmit: _submitTag,
                    onDelete: (tag) => _c.removeTag(_node, tag),
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

class _Header extends StatelessWidget {
  const _Header({required this.onDelete, required this.onClose});

  final VoidCallback onDelete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            onPressed: onDelete,
          ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _ImageField extends StatelessWidget {
  const _ImageField({
    required this.model,
    required this.onPick,
    required this.onRemove,
  });

  final NodeModel model;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
              onPressed: onPick,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text(model.img == null ? 'Add image' : 'Replace'),
            ),
            if (model.img != null) ...[
              const SizedBox(width: 8),
              TextButton(onPressed: onRemove, child: const Text('Remove')),
            ],
          ],
        ),
      ],
    );
  }
}

class _TagsField extends StatelessWidget {
  const _TagsField({
    required this.model,
    required this.tagInput,
    required this.onSubmit,
    required this.onDelete,
  });

  final NodeModel model;
  final TextEditingController tagInput;
  final VoidCallback onSubmit;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (model.tags.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in model.tags)
                Chip(
                  label: Text(tag),
                  onDeleted: () => onDelete(tag),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: tagInput,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  hintText: 'Add a tag',
                ),
                onSubmitted: (_) => onSubmit(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: onSubmit, icon: const Icon(Icons.add)),
          ],
        ),
      ],
    );
  }
}
