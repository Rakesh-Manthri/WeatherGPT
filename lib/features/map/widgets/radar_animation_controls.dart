import 'package:flutter/material.dart';
import '../services/rainviewer_service.dart';

class RadarAnimationControls extends StatelessWidget {
  final List<RadarFrame> frames;
  final int currentIndex;
  final bool isPlaying;
  final VoidCallback onTogglePlay;
  final ValueChanged<int> onSelectFrame;
  final int rainChance;

  const RadarAnimationControls({
    super.key,
    required this.frames,
    required this.currentIndex,
    required this.isPlaying,
    required this.onTogglePlay,
    required this.onSelectFrame,
    this.rainChance = 35,
  });

  @override
  Widget build(BuildContext context) {
    if (frames.isEmpty) return const SizedBox.shrink();

    final activeFrame = currentIndex >= 0 && currentIndex < frames.length
        ? frames[currentIndex]
        : frames.last;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Play/Pause button + Active Time label + Intensity dBZ Pill
          Row(
            children: [
              // Play/Pause Action Button
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFF00E676),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: const Color(0xFF0F172A),
                    size: 22,
                  ),
                  tooltip: isPlaying ? 'Pause Radar' : 'Play Radar Animation',
                  onPressed: onTogglePlay,
                ),
              ),
              const SizedBox(width: 10),

              // Title and Current Frame Timestamp
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Rainfall Radar Sweep',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: activeFrame.label == 'NOW'
                                ? const Color(0xFF00E676).withValues(alpha: 0.20)
                                : Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: activeFrame.label == 'NOW'
                                  ? const Color(0xFF00E676)
                                  : Colors.transparent,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            activeFrame.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: activeFrame.label == 'NOW'
                                  ? const Color(0xFF00E676)
                                  : Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Precipitation probability: $rainChance% • 500ms step',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),

              // Mini dBZ Intensity Bar
              _buildDbzLegend(),
            ],
          ),

          const SizedBox(height: 10),

          // Frame Scrubber Pills Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(frames.length, (idx) {
              final frame = frames[idx];
              final isCurrent = idx == currentIndex;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onSelectFrame(idx),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? const Color(0xFF00E676)
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrent
                            ? const Color(0xFF00E676)
                            : Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        frame.label,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                          color: isCurrent ? const Color(0xFF0F172A) : Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDbzLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'dBZ ',
            style: TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.bold),
          ),
          Container(
            width: 44,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF00E676), // Light
                  Color(0xFFFFD600), // Moderate
                  Color(0xFFFF9100), // Heavy
                  Color(0xFFD500F9), // Severe
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
