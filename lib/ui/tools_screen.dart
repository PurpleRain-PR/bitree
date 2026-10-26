import 'package:flutter/material.dart';

import '../app_controller.dart';
import 'app_page.dart';
import 'classroom_screen.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => AppPage(
    title: const Text('工具'),
    child: ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.meeting_room_outlined),
          title: const Text('空教室查询'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => ClassroomScreen(controller: controller),
            ),
          ),
        ),
      ],
    ),
  );
}
