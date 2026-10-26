import 'package:flutter/material.dart';

import '../app_controller.dart';
import 'school_screen.dart';

class SchoolImportButton extends StatelessWidget {
  const SchoolImportButton({super.key, required this.controller});
  final AppController controller;

  Future<void> _import(BuildContext context, SchoolAction action) async {
    final success = await openSchoolPage(context, controller, action: action);
    if (success == true &&
        action == SchoolAction.importExams &&
        context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已更新考试安排')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = controller.busy || controller.schoolBusy;
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.input_rounded),
          onPressed: busy
              ? null
              : () => _import(context, SchoolAction.importSchedule),
          child: const Text('导入课表'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.edit_note_rounded),
          onPressed: busy || !controller.agenda.ready
              ? null
              : () => _import(context, SchoolAction.importExams),
          child: const Text('获取考试安排'),
        ),
      ],
      builder: (context, menu, _) => IconButton(
        tooltip: '导入',
        onPressed: busy ? null : () => menu.isOpen ? menu.close() : menu.open(),
        icon: controller.schoolBusy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.input_rounded),
      ),
    );
  }
}
