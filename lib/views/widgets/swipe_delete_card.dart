import 'dart:async';

import 'package:flutter/material.dart';

class SwipeDeleteCard extends StatefulWidget {
  const SwipeDeleteCard({
    super.key,
    required this.child,
    required this.onDelete,
    required this.itemId,
  });

  final Widget child;
  final Future<void> Function() onDelete;
  final int itemId;

  @override
  State<SwipeDeleteCard> createState() => _SwipeDeleteCardState();
}

class _SwipeDeleteCardState extends State<SwipeDeleteCard> {
  double _dismissProgress = 0;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('swipeDelete-${widget.itemId}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.42},
      movementDuration: const Duration(milliseconds: 240),
      resizeDuration: const Duration(milliseconds: 220),
      background: const SizedBox.expand(),
      onUpdate: (details) {
        if (_dismissProgress == details.progress) return;
        setState(() => _dismissProgress = details.progress);
      },
      onDismissed: (_) => unawaited(widget.onDelete()),
      child: Opacity(
        opacity: (1 - (_dismissProgress * 1.15)).clamp(0, 1),
        child: widget.child,
      ),
    );
  }
}
