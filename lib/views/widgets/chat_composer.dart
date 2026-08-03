import 'package:flutter/material.dart';

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.isSending,
    required this.onSend,
    required this.onChanged,
    required this.clearRevision,
  });

  final bool isSending;
  final ValueChanged<String> onSend;
  final ValueChanged<String> onChanged;
  final int clearRevision;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clearRevision != widget.clearRevision) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isSending) return;
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('chatComposer'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE9E9ED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x190F172A),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        key: const Key('chatInput'),
        controller: _controller,
        enabled: !widget.isSending,
        maxLines: 3,
        minLines: 1,
        textInputAction: TextInputAction.send,
        onChanged: widget.onChanged,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          hintText: '일정을 자연어로 입력하세요',
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        ),
      ),
    );
  }
}

class AnimatedOkButton extends StatefulWidget {
  const AnimatedOkButton({
    super.key,
    required this.onPressed,
    this.isBusy = false,
  });

  final VoidCallback onPressed;
  final bool isBusy;

  @override
  State<AnimatedOkButton> createState() => _AnimatedOkButtonState();
}

class _AnimatedOkButtonState extends State<AnimatedOkButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<Color?> _startColor;
  late final Animation<Color?> _endColor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0.9), weight: 12),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.9,
          end: 1.07,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 18,
      ),
      TweenSequenceItem(tween: Tween<double>(begin: 1.07, end: 1), weight: 14),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 56),
    ]).animate(_controller);
    _startColor = ColorTween(
      begin: const Color(0xFF20B783),
      end: const Color(0xFF3AA5C9),
    ).animate(_controller);
    _endColor = ColorTween(
      begin: const Color(0xFF7187E8),
      end: const Color(0xFF8A70D6),
    ).animate(_controller);
    if (!widget.isBusy) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant AnimatedOkButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isBusy && !widget.isBusy) {
      _controller.repeat(reverse: true);
    } else if (!oldWidget.isBusy && widget.isBusy) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      key: const Key('confirmPreviewButton'),
      scale: _scale,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Container(
          width: 54,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.isBusy
                  ? const [Color(0xFF9DBCB1), Color(0xFFA7ADC5)]
                  : [_startColor.value!, _endColor.value!],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3320A77A),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.isBusy ? null : widget.onPressed,
              borderRadius: BorderRadius.circular(22),
              child: Center(
                child: widget.isBusy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'OK!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
