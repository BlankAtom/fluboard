import 'package:flutter/material.dart';

import 'whiteboard/whiteboard_page.dart';

void main() {
  runApp(const WhiteboardApp());
}

class WhiteboardApp extends StatelessWidget {
  const WhiteboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Whiteboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1E88E5),
      ),
      home: const WhiteboardPage(),
    );
  }
}
