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
  static const _actionWidth = 76.0;
  double _offset = 0;
  bool _dragging = false;

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragging = true;
      _offset = (_offset + details.delta.dx).clamp(-_actionWidth, 0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _dragging = false;
      _offset = _offset.abs() >= _actionWidth * 0.45 ? -_actionWidth : 0;
    });
  }

  Future<void> _delete() async {
    setState(() => _offset = 0);
    await widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: _actionWidth,
                color: const Color(0xFFE5484D),
                child: IconButton(
                  key: Key('swipeDelete-${widget.itemId}'),
                  onPressed: _delete,
                  tooltip: '일정 삭제',
                  color: Colors.white,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ),
            ),
          ),
          IgnorePointer(
            ignoring: !_dragging && _offset < 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: AnimatedContainer(
                duration: _dragging
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(_offset, 0, 0),
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
