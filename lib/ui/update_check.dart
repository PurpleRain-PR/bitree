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
    final releases = await availableAppReleases(
      installed,
      builtAt: appBuildTime,
    );
    if (!context.mounted) return;

    if (releases.isEmpty) {
      if (!silent) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已是最新版本')));
      }
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        constraints: const BoxConstraints(maxWidth: 480),
        title: const Text('发现可用更新'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, release) in releases.indexed) ...[
                  if (index > 0) const Divider(height: 24),
                  Text(
                    '${release.isDevelopment ? '测试版' : '正式版'} ${release.version}',
                    style: Theme.of(dialogContext).textTheme.titleMedium,
                  ),
                  if (release.notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(release.notes),
                  ],
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('稍后'),
          ),
          for (final release in releases)
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
              child: Text(release.isDevelopment ? '下载测试版' : '下载正式版'),
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
