import 'dart:io';

import 'package:flutter/material.dart';

import '../app_version.dart';
import '../data/app_release.dart';
import 'external_link.dart';

Future<void> checkForUpdates(
  BuildContext context, {
  bool silent = false,
}) async {
  try {
    final installed = await appVersion();
    final release = await latestAppRelease();
    if (!context.mounted) return;

    if (release == null || !release.isNewerThan(installed)) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(release == null ? '还没有正式发布的版本' : '已是最新版本')),
        );
      }
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        constraints: const BoxConstraints(maxWidth: 480),
        title: Text('发现新版本 v${release.version}'),
        content: release.notes.isEmpty
            ? null
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: SingleChildScrollView(child: Text(release.notes)),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () async {
              final opened = await openExternalLink(
                dialogContext,
                release.url,
                failureTitle: '无法打开下载页面',
              );
              if (opened && dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('前往下载'),
          ),
        ],
      ),
    );
  } catch (error) {
    if (silent || !context.mounted) return;

    final message = error is HttpException ? error.message : '检查更新失败，请检查网络后重试。';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
