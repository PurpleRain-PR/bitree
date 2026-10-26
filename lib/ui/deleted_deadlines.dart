import 'package:flutter/material.dart';

import '../agenda/controller.dart';
import '../agenda/model.dart';
import 'app_notice.dart';
import 'sheet_layout.dart';

Future<void> showDeletedDeadlines(
  BuildContext context,
  AgendaController controller,
) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (sheetContext) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final entries = controller.deletedDeadlines.toList()
        ..sort((a, b) => b.startsAt.compareTo(a.startsAt));

      Future<void> restore([AgendaEntry? entry]) async {
        final saved = entry == null
            ? await controller.restoreDeletedDeadlines()
            : await controller.restore(entry);
        if (!sheetContext.mounted) return;
        if (!saved) return;
        showAppNotice(
          context,
          entry == null ? '已恢复全部 DDL' : '已恢复“${entry.title}”',
        );
        if (controller.deletedDeadlines.isEmpty &&
            ModalRoute.of(sheetContext)?.isCurrent == true) {
          Navigator.pop(sheetContext);
        }
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
                    '已删除的 DDL',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text('没有已删除的 DDL'),
                ),
              for (final entry in entries)
                ListTile(
                  key: ValueKey(entry.id),
                  title: Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      [
                        entry.source?.label ?? '手动添加',
                        if (entry.course.isNotEmpty) entry.course,
                      ].join('  '),
                      '${agendaDateLabel(entry.startsAt)} ${entry.timeLabel}',
                    ].join('\n'),
                  ),
                  trailing: TextButton(
                    onPressed: controller.busy ? null : () => restore(entry),
                    child: const Text('恢复'),
                  ),
                ),
            ],
          ),
          actions: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: controller.busy || entries.isEmpty
                    ? null
                    : () => restore(),
                child: const Text('全部恢复'),
              ),
            ),
          ),
        ),
      );
    },
  ),
);
