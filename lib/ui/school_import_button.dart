import 'package:flutter/material.dart';

import '../app_controller.dart';
import 'school_screen.dart';

class SchoolImportButton extends StatelessWidget {
  const SchoolImportButton({
    super.key,
    required this.controller,
    this.includeSchedule = true,
  });
  final AppController controller;
  final bool includeSchedule;

  Future<void> _import(BuildContext context, SchoolAction action) async {
    final success = await openSchoolPage(context, controller, action: action);
    if (success == true &&
        action != SchoolAction.importSchedule &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action.source == null
                ? '已更新考试安排'
                : '已更新${action.source!.label} DDL',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = controller.busy || controller.schoolBusy;
    return MenuAnchor(
      menuChildren: [
        if (includeSchedule)
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
        const Divider(),
        for (final action in [
          SchoolAction.importLexueDeadlines,
          SchoolAction.importEclassDeadlines,
        ])
          MenuItemButton(
            leadingIcon: const Icon(Icons.flag_outlined),
            onPressed: busy || !controller.agenda.ready
                ? null
                : () => _import(context, action),
            child: Text(action.label),
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
