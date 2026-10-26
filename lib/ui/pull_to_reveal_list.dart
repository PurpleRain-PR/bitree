import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PullToRevealList extends StatefulWidget {
  const PullToRevealList({
    super.key,
    required this.hiddenChildren,
    required this.revealLabel,
    required this.children,
  });

  final List<Widget> children;
  final List<Widget> hiddenChildren;
  final String revealLabel;

  @override
  State<PullToRevealList> createState() => _PullToRevealListState();
}

class _PullToRevealListState extends State<PullToRevealList> {
  static const _threshold = 64.0;
  final _scroll = ScrollController();
  bool _revealed = false;
  bool _dragging = false;
  double _pull = 0;

  bool get _canReveal => !_revealed && widget.hiddenChildren.isNotEmpty;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (!_canReveal || notification.depth != 0) return false;
    final userDrag = switch (notification) {
      ScrollUpdateNotification(:final dragDetails) => dragDetails != null,
      OverscrollNotification(:final dragDetails) => dragDetails != null,
      _ => false,
    };
    if (userDrag) _dragging = true;
    if (!userDrag && _pull == 0) return false;

    final pull = math.max(
      0.0,
      notification.metrics.pixels - notification.metrics.maxScrollExtent,
    );
    if (userDrag && pull >= _threshold && _pull < _threshold) {
      HapticFeedback.selectionClick();
    }
    if (pull != _pull) setState(() => _pull = pull);
    return false;
  }

  void _release() {
    final reveal = _dragging && _pull >= _threshold;
    _dragging = false;
    if (reveal) _reveal();
  }

  void _reveal() {
    final offset = _scroll.offset;
    setState(() {
      _revealed = true;
      _pull = 0;
    });
    // The stretched edge becomes real content without resetting the viewport.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scroll.jumpTo(
        offset.clamp(
          _scroll.position.minScrollExtent,
          _scroll.position.maxScrollExtent,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Listener(
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _dragging = false,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomScrollView(
                  controller: _scroll,
                  physics: _canReveal
                      ? const _BottomPullPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        )
                      : const ClampingScrollPhysics(),
                  slivers: [
                    SliverList.list(children: widget.children),
                    if (_canReveal)
                      SliverToBoxAdapter(
                        child: Center(
                          child: TextButton(
                            onPressed: _reveal,
                            child: Text(
                              '上滑${widget.revealLabel}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    if (_revealed)
                      SliverList.list(children: widget.hiddenChildren),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                  ],
                ),
                if (_canReveal && _pull > 0)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: math.min(_pull, 96),
                    child: IgnorePointer(
                      child: Center(
                        child: Text(
                          _pull >= _threshold ? '松开显示' : '继续上滑',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bounces only at the bottom while the extra items are hidden.
class _BottomPullPhysics extends BouncingScrollPhysics {
  const _BottomPullPhysics({super.parent});

  @override
  _BottomPullPhysics applyTo(ScrollPhysics? ancestor) =>
      _BottomPullPhysics(parent: buildParent(ancestor));

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value < position.pixels &&
        position.pixels <= position.minScrollExtent) {
      return value - position.pixels;
    }
    if (value < position.minScrollExtent &&
        position.pixels > position.minScrollExtent) {
      return value - position.minScrollExtent;
    }
    return 0;
  }
}
