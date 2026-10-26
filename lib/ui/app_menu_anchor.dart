import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppMenuAnchor extends StatelessWidget {
  const AppMenuAnchor({
    super.key,
    required this.menuChildren,
    this.controller,
    this.childFocusNode,
    this.menuWidth,
    this.style,
    this.onOpen,
    this.onClose,
    this.builder,
    this.child,
  });

  final List<Widget> menuChildren;
  final MenuController? controller;
  final FocusNode? childFocusNode;
  final double? menuWidth;
  final MenuStyle? style;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;
  final MenuAnchorChildBuilder? builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    controller: controller,
    childFocusNode: childFocusNode,
    style: MenuStyle(
      minimumSize: menuWidth == null
          ? null
          : WidgetStatePropertyAll(Size(menuWidth!, 0)),
      maximumSize: WidgetStatePropertyAll(
        Size(
          menuWidth ?? double.infinity,
          math.min(320, MediaQuery.sizeOf(context).height * 0.4),
        ),
      ),
    ).merge(style),
    onOpen: onOpen,
    onClose: onClose,
    animated: !MediaQuery.disableAnimationsOf(context),
    menuChildren: menuChildren,
    builder: builder,
    child: child,
  );
}
