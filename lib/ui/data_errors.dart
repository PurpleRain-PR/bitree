import 'package:flutter/material.dart';

import '../app_controller.dart';

class DataErrors extends StatelessWidget {
  const DataErrors({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (controller.error != null)
        MaterialBanner(
          content: Text(controller.error!),
          actions: [
            TextButton(
              onPressed: controller.dismissError,
              child: const Text('关闭'),
            ),
          ],
        ),
      if (controller.agenda.error != null)
        ListTile(
          title: Text(
            controller.agenda.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          trailing: !controller.agenda.ready
              ? TextButton(
                  onPressed: controller.agenda.busy
                      ? null
                      : controller.agenda.load,
                  child: const Text('重试'),
                )
              : null,
        ),
    ],
  );
}
