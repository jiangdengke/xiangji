import 'package:flutter/material.dart';

import 'controller/xiangji_session_controller.dart';
import 'ui/stream_dashboard_page.dart';

class XiangjiApp extends StatefulWidget {
  const XiangjiApp({super.key, required this.controller});

  final XiangjiSessionController controller;

  @override
  State<XiangjiApp> createState() => _XiangjiAppState();
}

class _XiangjiAppState extends State<XiangjiApp> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '巡摄',
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F9F9),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      ),
      home: StreamDashboardPage(controller: widget.controller),
    );
  }
}
