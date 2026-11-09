import 'package:flutter/material.dart';

enum SlideDirection {
  leftToRight,
  rightToLeft,
}

class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final SlideDirection direction;

  SlidePageRoute({
    required this.page,
    required this.direction,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final begin = direction == SlideDirection.leftToRight
                ? const Offset(-1.0, 0.0)
                : const Offset(1.0, 0.0);
            const end = Offset.zero;
            final curve = Curves.easeInOutCubic;
            final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 320),
        );
}
