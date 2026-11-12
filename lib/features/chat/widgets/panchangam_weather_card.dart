import 'package:flutter/material.dart';

class PanchangamWeatherCard extends StatelessWidget {
  final Map<String, dynamic> panchangamData;

  const PanchangamWeatherCard({
    super.key,
    required this.panchangamData,
  });

  Color _scoreBgColor(int score) {
    if (score >= 75) return const Color(0xFFE8F5E9);
    if (score >= 55) return const Color(0xFFFEF3C7);
    return const Color(0xFFFFEBEE);
  }

  Color _scoreTextColor(int score) {
    if (score >= 75) return const Color(0xFF2E7D32);
    if (score >= 55) return const Color(0xFFB45309);
    return const Color(0xFFC62828);
  }

  @override
  Widget build(BuildContext context) {
    final masa = (panchangamData['masa'] ?? 'Kartika').toString();
    final ritu = (panchangamData['ritu'] ?? '').toString();
    final dateStr = (panchangamData['date'] ?? '').toString();
    final vara = (panchangamData['vara'] ?? '').toString();
    final karana = (panchangamData['karana'] ?? '').toString();
    final suryaNak = (panchangamData['surya_nakshatra'] ?? '').toString();
    final moonIllum = (panchangamData['moon_illumination_pct'] ?? 0).toString();
    final sunrise = (panchangamData['sunrise'] ?? '--:--').toString();
    final sunset = (panchangamData['sunset'] ?? '--:--').toString();
    final specialEvent = panchangamData['special_event']?.toString();
    final compositeScore =
        (panchangamData['composite_score'] as num?)?.toInt() ?? 75;
    final verdict =
        (panchangamData['fusion_verdict'] ?? 'Panchangam + Weather Alignment')
            .toString();
    final advisory = (panchangamData['fused_advisory'] ?? '').toString();

    final tithi =
        (panchangamData['tithi'] as Map<String, dynamic>?) ?? const {};
    final nakshatra =
        (panchangamData['nakshatra'] as Map<String, dynamic>?) ?? const {};
    final yoga =
        (panchangamData['yoga'] as Map<String, dynamic>?) ?? const {};
    final muhurtham =
        (panchangamData['muhurtham_windows'] as Map<String, dynamic>?) ??
            const {};
    final upcoming =
        (panchangamData['upcoming_windows'] as List<dynamic>?) ?? const [];

    final tithiName = (tithi['name'] ?? '').toString();
    final tithiEnds = (tithi['ends_at'] ?? '--:--').toString();
    final nakName = (nakshatra['name'] ?? '').toString();
    final nakPada = (nakshatra['pada'] ?? 1).toString();
    final nakEnds = (nakshatra['ends_at'] ?? '--:--').toString();
    final yogaName = (yoga['name'] ?? '').toString();
    final yogaRating = (yoga['rating'] ?? '').toString();
    final abhijit =
        (muhurtham['abhijit_muhurtham'] ?? '--:--').toString();
    final rahuKaal = (muhurtham['rahu_kaal'] ?? '--:--').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEBEBEB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 4),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Vedic Masa / Ritu & Composite Score Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.brightness_4_rounded,
                  size: 16,
                  color: Color(0xFF1C1C1E),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$masa Masa${ritu.isNotEmpty ? ' • $ritu' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _scoreBgColor(compositeScore),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$compositeScore/100 Fusion',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: _scoreTextColor(compositeScore),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF2F2F2)),

          // Special Lunisolar Festival / Vrata Callout
          if (specialEvent != null && specialEvent.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 13, color: Color(0xFFFBBF24)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        specialEvent,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Panchangam 5-Limb Grid
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildLimbTile(
                        label: 'TITHI ($dateStr)',
                        value: tithiName,
                        subvalue: 'Ends $tithiEnds',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildLimbTile(
                        label: 'NAKSHATRA',
                        value: '$nakName (P$nakPada)',
                        subvalue: 'Ends $nakEnds • Sun: $suryaNak',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildLimbTile(
                        label: 'YOGA & KARANA',
                        value: '$yogaName ($yogaRating)',
                        subvalue: 'Karana: $karana • $vara',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildLimbTile(
                        label: 'SOLAR & LUNAR',
                        value: '$sunrise – $sunset',
                        subvalue: 'Moon Illumination $moonIllum%',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Muhurtham Windows (Abhijit vs Rahu Kaal)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: _buildWindowChip(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Abhijit Muhurtham',
                    timeText: abhijit,
                    bgColor: const Color(0xFFE8F5E9),
                    fgColor: const Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildWindowChip(
                    icon: Icons.schedule_rounded,
                    title: 'Rahu Kaal (Avoid)',
                    timeText: rahuKaal,
                    bgColor: const Color(0xFFFEF3C7),
                    fgColor: const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),

          // Fused Verdict & Advisory Note
          if (advisory.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      verdict,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      advisory,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: Color(0xFF444444),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const SizedBox(height: 12),

          // Multi-day Top Windows (if user asked for best upcoming week days)
          if (upcoming.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: SizedBox(
                height: 54,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: upcoming.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = upcoming[index] as Map<String, dynamic>;
                    final d = (item['date'] ?? '').toString();
                    final t = (item['tithi'] ?? '').toString();
                    final s = (item['composite_score'] ?? 0).toString();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: index == 0
                            ? const Color(0xFF1C1C1E)
                            : const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$d • $s/100',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: index == 0
                                  ? Colors.white
                                  : const Color(0xFF1C1C1E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t,
                            style: TextStyle(
                              fontSize: 10,
                              color: index == 0
                                  ? Colors.white70
                                  : const Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLimbTile({
    required String label,
    required String value,
    required String subvalue,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: Color(0xFF777777),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subvalue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowChip({
    required IconData icon,
    required String title,
    required String timeText,
    required Color bgColor,
    required Color fgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: fgColor),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: fgColor,
                  ),
                ),
                Text(
                  timeText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: fgColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
