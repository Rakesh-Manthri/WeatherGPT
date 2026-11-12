import 'package:flutter/material.dart';

class NewsScreen extends StatelessWidget {
  final VoidCallback? onBack;

  const NewsScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  _NewsCircularIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: () {
                      if (onBack != null) {
                        onBack!();
                      } else if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                  ),

                  // Pill Styled Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'News',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),

                  // Balancer
                  const SizedBox(width: 44, height: 44),
                ],
              ),
            ),

            // Empty Interface Body
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.article_outlined,
                          size: 40,
                          color: Color(0xFF555555),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Weather news is coming soon',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Live weather headlines and regional alerts are not available yet. You can still ask WeatherGPT about current conditions and forecasts in chat.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF777777),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsCircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _NewsCircularIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onPressed,
          child: Center(
            child: Icon(icon, size: 20, color: const Color(0xFF1C1C1E)),
          ),
        ),
      ),
    );
  }
}
