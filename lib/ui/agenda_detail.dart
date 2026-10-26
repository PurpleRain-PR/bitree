import 'package:flutter/material.dart';

import '../agenda/model.dart';
import '../app_controller.dart';
import '../schedule/model.dart';
import 'agenda_editor.dart';
import 'agenda_operations.dart';
import 'completion_text.dart';
import 'external_link.dart';
import 'sheet_layout.dart';

Future<void> showAgendaEntry(
  BuildContext pageContext,
  AppController controller,
  AgendaEntry entry,
) => showModalBottomSheet<void>(
  context: pageContext,
  useSafeArea: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (sheetContext) => ListenableBuilder(
    listenable: controller.agenda,
    builder: (context, _) {
      // Keep the closing sheet readable after its entry has been deleted.
      final current =
          controller.agenda.entries
              .where((value) => value.id == entry.id)
              .firstOrNull ??
          entry;
      final theme = Theme.of(context);
      final pastDeadline =
          current.isDeadline && current.dueAt.isBefore(campusNow());
      void edit() {
        Navigator.pop(sheetContext);
        editAgenda(pageContext, controller, entry: current);
      }

      return SafeArea(
        top: false,
        child: SheetLayout(
          header: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    current.kind.label,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: '删除',
                  onPressed: controller.agenda.busy
                      ? null
                      : () async {
                          if (await deleteAgendaEntry(
                                context,
                                controller,
                                current,
                              ) &&
                              sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        },
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CompletionText(
                    current.title,
                    completed: current.done,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  CompletionText(
                    '${agendaDateLabel(current.startsAt)}\n'
                    '${current.timeLabel}${pastDeadline ? '  已截止' : ''}',
                    completed: current.done,
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (current.location.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    CompletionText(current.location, completed: current.done),
                  ],
                  if (current.source != null || current.course.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    CompletionText(
                      [
                        if (current.source != null) current.source!.label,
                        if (current.course.isNotEmpty) current.course,
                      ].join('  '),
                      completed: current.done,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  if (current.url case final url?)
                    TextButton.icon(
                      onPressed: () => openExternalLink(
                        context,
                        url,
                        failureTitle: '无法打开作业',
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('打开作业'),
                    ),
                  if (current.notes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    CompletionText(
                      current.notes,
                      completed: current.done,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (current.isDeadline) ...[
                    Expanded(
                      child: FilledButton(
                        onPressed: controller.agenda.busy
                            ? null
                            : () =>
                                  toggleAgendaDone(controller.agenda, current),
                        child: Text(
                          current.done ? '标为未完成' : '标记完成',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: controller.agenda.busy ? null : edit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('编辑'),
                      ),
                    ),
                  ] else
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: controller.agenda.busy ? null : edit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('编辑'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  ),
);
