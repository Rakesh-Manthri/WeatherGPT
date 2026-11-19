import 'package:flutter/material.dart';

class WeatherShareCard extends StatelessWidget {
  final Map<String, dynamic> weatherData;
  final String locationName;
  final double lat;
  final double lon;

  const WeatherShareCard({
    super.key,
    required this.weatherData,
    required this.locationName,
    required this.lat,
    required this.lon,
  });

  Color _getAqiColor(int aqi) {
    if (aqi <= 50) return const Color(0xFF00E676);
    if (aqi <= 100) return const Color(0xFFFFD600);
    if (aqi <= 150) return const Color(0xFFFF9100);
    if (aqi <= 200) return const Color(0xFFFF1744);
    return const Color(0xFFD500F9);
  }

  String _getAqiCategory(int aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Sensitive';
    if (aqi <= 200) return 'Unhealthy';
    return 'Hazardous';
  }

  @override
  Widget build(BuildContext context) {
    final temp = (weatherData['temperature'] as num?)?.round() ?? 24;
    final feelsLike = (weatherData['apparent_temperature'] as num?)?.round() ?? temp;
    final cond = (weatherData['condition'] ?? 'Partly Cloudy').toString();
    final high = (weatherData['temp_max'] as num?)?.round() ?? (temp + 3);
    final low = (weatherData['temp_min'] as num?)?.round() ?? (temp - 6);
    final hum = (weatherData['humidity'] as num?)?.toInt() ?? 60;
    final wind = (weatherData['wind_speed'] as num?)?.round() ?? 12;
    final rain = (weatherData['rain_chance'] as num?)?.toInt() ?? 10;
    final aqi = (weatherData['aqi'] as num?)?.toInt() ?? 65;
    final aqiColor = _getAqiColor(aqi);
    final aqiCategory = _getAqiCategory(aqi);

    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateStr = '${now.day} ${_monthName(now.month)} ${now.year}';

    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
            Color(0xFF0F2642),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Branding Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Center(
                      child: Icon(Icons.cloud_rounded, size: 15, color: Color(0xFF0F172A)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Weather GPT',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, size: 11, color: Color(0xFF00E676)),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2. Location & Date
          Text(
            locationName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${lat.toStringAsFixed(4)}°N, ${lon.toStringAsFixed(4)}°E • $dateStr',
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),

          const SizedBox(height: 14),

          // 3. Hero Temperature & Condition
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$temp',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      '°C',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      cond,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'High $high° / Low $low°',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.70),
                      ),
                    ),
                    Text(
                      'Feels like $feelsLike°C',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
          const SizedBox(height: 12),

          // 4. Key Metrics Grid (Expanded to fit perfectly without overflow)
          Row(
            children: [
              Expanded(
                child: _buildMetric(Icons.water_drop_rounded, const Color(0xFF38BDF8), '$hum%', 'Humidity'),
              ),
              Expanded(
                child: _buildMetric(Icons.air_rounded, const Color(0xFF34D399), '$wind km/h', 'Wind'),
              ),
              Expanded(
                child: _buildMetric(Icons.umbrella_rounded, const Color(0xFF818CF8), '$rain%', 'Rain Chance'),
              ),
              Expanded(
                child: _buildAqiMetric(aqi, aqiCategory, aqiColor),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 5. Radar & Downscaling Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                const Icon(Icons.radar_rounded, size: 13, color: Color(0xFF00E676)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'GIS Radar Active • 1km Downscaled Physics Model',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 6. Footer
          Center(
            child: Text(
              'Generated with On-Device AI • weathergpt.local',
              style: TextStyle(
                fontSize: 9,
                color: Colors.white.withValues(alpha: 0.45),
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(IconData icon, Color color, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  Widget _buildAqiMetric(int aqi, String category, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$aqi',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          category,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          'AQI Index',
          style: TextStyle(
            fontSize: 9.5,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[(month - 1).clamp(0, 11)];
  }
}
