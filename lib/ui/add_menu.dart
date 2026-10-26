import 'package:flutter/material.dart';

import '../agenda/model.dart';
import '../app_controller.dart';
import '../schedule/selection.dart';
import 'agenda_editor.dart';
import 'course_editor.dart';

enum _AddAction { event, course, deadline }

Future<void> showAddMenu(
  BuildContext context,
  AppController controller,
  Offset position, {
  TimetableSelection? selection,
  DateTime? date,
}) async {
  final overlay =
      Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
  final local = overlay.globalToLocal(position);
  final selected = await showMenu<_AddAction>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(local.dx, local.dy, 1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      PopupMenuItem(
        value: _AddAction.event,
        enabled: controller.agenda.ready && !controller.agenda.busy,
        child: const Row(
          children: [
            Icon(Icons.event_outlined, size: 20),
            SizedBox(width: 12),
            Text('添加活动'),
          ],
        ),
      ),
      PopupMenuItem(
        value: _AddAction.course,
        enabled: !controller.busy,
        child: const Row(
          children: [
            Icon(Icons.school_outlined, size: 20),
            SizedBox(width: 12),
            Text('添加课程'),
          ],
        ),
      ),
      if (selection == null)
        PopupMenuItem(
          value: _AddAction.deadline,
          enabled: controller.agenda.ready && !controller.agenda.busy,
          child: const Row(
            children: [
              Icon(Icons.flag_outlined, size: 20),
              SizedBox(width: 12),
              Text('添加 DDL'),
            ],
          ),
        ),
    ],
  );
  if (!context.mounted || selected == null) return;
  if (selected == _AddAction.course) {
    await editCourse(context, controller, selection: selection);
  } else {
    await editAgenda(
      context,
      controller.agenda,
      selection: selection,
      date: date,
      term: controller.schedule?.term,
      kind: selected == _AddAction.deadline
          ? AgendaKind.deadline
          : AgendaKind.event,
    );
  }
}

class AddButton extends StatelessWidget {
  const AddButton({super.key, required this.controller, this.date});
  final AppController controller;
  final DateTime? date;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '添加',
    onPressed: controller.busy || controller.agenda.busy
        ? null
        : () {
            final box = context.findRenderObject()! as RenderBox;
            showAddMenu(
              context,
              controller,
              box.localToGlobal(Offset(0, box.size.height)),
              date: date,
            );
          },
    icon: const Icon(Icons.add_rounded),
  );
}
