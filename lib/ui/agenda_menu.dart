import 'package:flutter/material.dart';

import '../agenda/model.dart';
import '../app_controller.dart';
import 'agenda_editor.dart';
import 'agenda_operations.dart';
import 'external_link.dart';

class AgendaMenu extends StatelessWidget {
  const AgendaMenu({super.key, required this.controller, required this.entry});

  final AppController controller;
  final AgendaEntry entry;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: [
      if (entry.isDeadline)
        MenuItemButton(
          leadingIcon: Icon(
            entry.done ? Icons.undo_rounded : Icons.check_rounded,
          ),
          onPressed: () => toggleAgendaDone(context, controller.agenda, entry),
          child: Text(entry.done ? '标为未完成' : '标记完成'),
        ),
      MenuItemButton(
        leadingIcon: const Icon(Icons.edit_outlined),
        onPressed: () => editAgenda(context, controller, entry: entry),
        child: const Text('编辑'),
      ),
      if (entry.url case final url?)
        MenuItemButton(
          leadingIcon: const Icon(Icons.open_in_new_rounded),
          onPressed: () =>
              openExternalLink(context, url, failureTitle: '无法打开作业'),
          child: const Text('打开作业'),
        ),
      const Divider(),
      MenuItemButton(
        leadingIcon: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.error,
        ),
        onPressed: () => deleteAgendaEntry(context, controller, entry),
        child: Text(
          '删除',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    ],
    builder: (context, menu, _) => IconButton(
      tooltip: '${entry.kind.label}操作',
      onPressed: controller.agenda.busy
          ? null
          : () => menu.isOpen ? menu.close() : menu.open(),
      icon: const Icon(Icons.more_horiz_rounded, size: 20),
    ),
  );
}
