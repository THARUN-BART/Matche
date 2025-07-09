import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  final Color? color;
  final double size;

  const TypingIndicator({
    super.key,
    this.color,
    this.size = 20.0,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller1;
  late AnimationController _controller2;
  late AnimationController _controller3;

  late Animation<double> _animation1;
  late Animation<double> _animation2;
  late Animation<double> _animation3;

  @override
  void initState() {
    super.initState();

    _controller1 = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _controller2 = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _controller3 = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _animation1 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller1, curve: Curves.easeInOut),
    );
    _animation2 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller2, curve: Curves.easeInOut),
    );
    _animation3 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller3, curve: Curves.easeInOut),
    );

    _startAnimation();
  }

  void _startAnimation() {
    _controller1.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _controller2.repeat(reverse: true);
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _controller3.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _animation1,
          builder: (context, child) {
            return Container(
              width: widget.size * 0.3,
              height: widget.size * 0.3,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: widget.color ?? Colors.grey[600],
                shape: BoxShape.circle,
              ),
              child: Transform.scale(
                scale: 0.5 + (_animation1.value * 0.5),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.color ?? Colors.grey[600],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        ),
        AnimatedBuilder(
          animation: _animation2,
          builder: (context, child) {
            return Container(
              width: widget.size * 0.3,
              height: widget.size * 0.3,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: widget.color ?? Colors.grey[600],
                shape: BoxShape.circle,
              ),
              child: Transform.scale(
                scale: 0.5 + (_animation2.value * 0.5),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.color ?? Colors.grey[600],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        ),
        AnimatedBuilder(
          animation: _animation3,
          builder: (context, child) {
            return Container(
              width: widget.size * 0.3,
              height: widget.size * 0.3,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: widget.color ?? Colors.grey[600],
                shape: BoxShape.circle,
              ),
              child: Transform.scale(
                scale: 0.5 + (_animation3.value * 0.5),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.color ?? Colors.grey[600],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
} 