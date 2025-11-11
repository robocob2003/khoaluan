// lib/widgets/typing_indicator.dart

import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  final List<String> users;

  const TypingIndicator({Key? key, required this.users}) : super(key: key);

  @override
  _TypingIndicatorState createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    final double begin = index * 0.2;
    final double end = begin + 0.4;
    return FadeTransition(
      opacity: Tween(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(begin, end, curve: Curves.easeInOut),
        ),
      ),
      child: Container(
        width: 8,
        height: 8,
        margin: EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.grey,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  String _getTypingText() {
    if (widget.users.length == 1) return "${widget.users.first} is typing...";
    if (widget.users.length == 2)
      return "${widget.users.join(' and ')} are typing...";
    return "Several people are typing...";
  }

  @override
  Widget build(BuildContext context) {
    if (widget.users.isEmpty) return SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Text(_getTypingText(),
              style:
                  TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          SizedBox(width: 8),
          _buildDot(0),
          _buildDot(1),
          _buildDot(2),
        ],
      ),
    );
  }
}
