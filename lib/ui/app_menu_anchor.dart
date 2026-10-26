import 'package:flutter/material.dart';

class AppMenuAnchor extends StatelessWidget {
  const AppMenuAnchor({
    super.key,
    required this.menuChildren,
    this.controller,
    this.style,
    this.onClose,
    this.builder,
    this.child,
  });

  final List<Widget> menuChildren;
  final MenuController? controller;
  final MenuStyle? style;
  final VoidCallback? onClose;
  final MenuAnchorChildBuilder? builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    controller: controller,
    style: style,
    onClose: onClose,
    animated: !MediaQuery.disableAnimationsOf(context),
    menuChildren: menuChildren,
    builder: builder,
    child: child,
  );
}
