import 'dart:async';

import 'package:flutter/material.dart';

OverlayEntry? _notice;
Timer? _dismissTimer;

/// The root overlay keeps feedback visible above course detail sheets.
void showAppNotice(BuildContext context, String message) {
  _dismissNotice();
  final overlay = Overlay.of(context, rootOverlay: true);
  _notice = OverlayEntry(
    builder: (context) {
      final theme = Theme.of(context);
      return Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: SafeArea(
            bottom: false,
            minimum: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Material(
                  color: theme.colorScheme.inverseSurface,
                  borderRadius: BorderRadius.circular(4),
                  elevation: 6,
                  child: Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(
                        message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onInverseSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  overlay.insert(_notice!);
  _dismissTimer = Timer(const Duration(seconds: 4), _dismissNotice);
}

void _dismissNotice() {
  _dismissTimer?.cancel();
  _dismissTimer = null;
  _notice?.remove();
  _notice?.dispose();
  _notice = null;
}
