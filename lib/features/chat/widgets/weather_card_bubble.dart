import 'package:flutter/material.dart';

class WeatherCardBubble extends StatefulWidget {
  final Map<String, dynamic> weatherData;
  final void Function(double lat, double lon)? onViewMap;

  const WeatherCardBubble({
    super.key,
    required this.weatherData,
    this.onViewMap,
  });

  @override
  State<WeatherCardBubble> createState() => _WeatherCardBubbleState();
}

class _WeatherCardBubbleState extends State<WeatherCardBubble> {
  int _selectedMetricTab = 0; // 0 = Temperature, 1 = Precipitation, 2 = Wind

  IconData _getWeatherIcon(int code, bool isDay) {
    switch (code) {
      case 0:
        return isDay ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded;
      case 1:
      case 2:
        return isDay ? Icons.wb_cloudy_rounded : Icons.cloud_queue_rounded;
      case 3:
        return Icons.cloud_rounded;
      case 45:
      case 48:
        return Icons.foggy;
      case 51:
      case 53:
      case 55:
      case 61:
      case 63:
      case 65:
      case 80:
      case 81:
      case 82:
        return Icons.water_drop_rounded;
      case 71:
      case 73:
      case 75:
        return Icons.ac_unit_rounded;
      case 95:
      case 96:
      case 99:
        return Icons.thunderstorm_rounded;
      default:
        return isDay ? Icons.wb_cloudy_rounded : Icons.cloud_queue_rounded;
    }
  }

  Color _getAqiColor(int aqi) {
    if (aqi <= 50) return const Color(0xFF34A853);
    if (aqi <= 100) return const Color(0xFFFBBC04);
    if (aqi <= 150) return const Color(0xFFFA7B17);
    if (aqi <= 200) return const Color(0xFFEA4335);
    return const Color(0xFF8E24AA);
  }

  String _getAqiLabel(int aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Sensitive';
    if (aqi <= 200) return 'Unhealthy';
    return 'Hazardous';
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.weatherData;
    final locationName = (data['location_name'] ?? 'Local Weather').toString();
    final temp = (data['temperature'] ?? 25).toString();
    final apparentTemp = (data['apparent_temperature'] ?? temp).toString();
    final condition = (data['condition'] ?? 'Partly Cloudy').toString();
    final tempMax = (data['temp_max'] ?? 30).toString();
    final tempMin = (data['temp_min'] ?? 20).toString();
    final humidity = (data['humidity'] ?? 60).toString();
    final windSpeed = (data['wind_speed'] ?? 10).toString();
    final rainChance = (data['rain_chance'] ?? 0).toString();
    final code = (data['weather_code'] as num?)?.toInt() ?? 1;
    final isDay = (data['is_day'] as bool?) ?? true;
    final aqi = (data['aqi'] as num?)?.toInt() ?? 65;
    final lat = (data['latitude'] as num?)?.toDouble() ?? 28.6139;
    final lon = (data['longitude'] as num?)?.toDouble() ?? 77.2090;

    final hourlyList = (data['hourly'] as List<dynamic>?) ?? [];
    final spatialDownscaling =
        data['spatial_downscaling'] as Map<String, dynamic>?;

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
          // Header: Location & Live Tag
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF1A73E8)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          locationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1C1C1E),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_manual_record, size: 7, color: Color(0xFF2E7D32)),
                      SizedBox(width: 4),
                      Text(
                        'Live Telemetry',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF2F2F2)),

          // Hero Temp & Condition Row
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$temp°',
                          style: const TextStyle(
                            fontFamily: 'serif',
                            fontSize: 48,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1C1C1E),
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'C',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      condition,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Feels like $apparentTemp° • H: $tempMax° L: $tempMin°',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF777777),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getWeatherIcon(code, isDay),
                    size: 34,
                    color: isDay ? const Color(0xFFF59E0B) : const Color(0xFF3F51B5),
                  ),
                ),
              ],
            ),
          ),

          // Hourly Scrubber Section with Segmented Metric Switcher
          if (hourlyList.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Hourly Outlook',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF555555),
                    ),
                  ),
                  // Tab toggle pills (Temp, Precip, Wind)
                  Row(
                    children: [
                      _buildMetricTab('Temp', 0),
                      const SizedBox(width: 4),
                      _buildMetricTab('Rain %', 1),
                      const SizedBox(width: 4),
                      _buildMetricTab('Wind', 2),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Horizontal Hourly Scrubber List
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                itemCount: hourlyList.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = hourlyList[index] as Map<String, dynamic>;
                  final timeLabel = (item['time'] ?? '').toString();
                  final hCode = (item['weather_code'] as num?)?.toInt() ?? 0;
                  final hTemp = (item['temp'] ?? 25).toString();
                  final hRain = (item['rain_chance'] ?? 0).toString();
                  final hWind = (item['wind_speed'] ?? 10).toString();

                  String displayValue;
                  if (_selectedMetricTab == 0) {
                    displayValue = '$hTemp°';
                  } else if (_selectedMetricTab == 1) {
                    displayValue = '$hRain%';
                  } else {
                    displayValue = '$hWind k';
                  }

                  final isNow = index == 0;

                  return Container(
                    width: 54,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isNow ? const Color(0xFF1C1C1E) : const Color(0xFFF7F8F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isNow ? FontWeight.bold : FontWeight.w500,
                            color: isNow ? Colors.white : const Color(0xFF777777),
                          ),
                        ),
                        Icon(
                          _getWeatherIcon(hCode, isDay),
                          size: 18,
                          color: isNow ? Colors.white : const Color(0xFF1C1C1E),
                        ),
                        Text(
                          displayValue,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isNow ? Colors.white : const Color(0xFF1C1C1E),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Quick Metrics Strip (Humidity, Wind, Rain, AQI)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(Icons.water_drop_outlined, '$humidity%', 'Humidity'),
                  _buildStatItem(Icons.air_rounded, '$windSpeed km/h', 'Wind'),
                  _buildStatItem(Icons.grain_rounded, '$rainChance%', 'Rain Chance'),
                  _buildAqiStatItem(aqi),
                ],
              ),
            ),
          ),

          // Hyper-Local 1km Spatial Downscaling Pill (if active)
          if (spatialDownscaling != null) ...[
            const SizedBox(height: 8),
            _buildDownscalingStrip(spatialDownscaling),
          ],

          const SizedBox(height: 12),

          // GIS Map Action Button ("Explore on GIS Map")
          if (widget.onViewMap != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () => widget.onViewMap!(lat, lon),
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text(
                    'Explore Spatial Map',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C1C1E),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricTab(String label, int index) {
    final isSelected = _selectedMetricTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedMetricTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1C1C1E) : const Color(0xFFEFEFEF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF555555),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF555555)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C1C1E),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            color: Color(0xFF888888),
          ),
        ),
      ],
    );
  }

  Widget _buildAqiStatItem(int aqi) {
    final color = _getAqiColor(aqi);
    final label = _getAqiLabel(aqi);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.shield_outlined, size: 14, color: color),
        const SizedBox(height: 2),
        Text(
          'AQI $aqi',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDownscalingStrip(Map<String, dynamic> ds) {
    final zone = (ds['microclimate_zone'] ?? '1km Microclimate').toString();
    final netDelta = (ds['net_temperature_delta_c'] as num?)?.toDouble() ?? 0.0;
    final terrain = ds['terrain_profile'] as Map<String, dynamic>?;
    final adjustments = ds['adjustments'] as Map<String, dynamic>?;
    final elevM = (terrain?['local_elevation_m'] as num?)?.round();
    final districtBias =
        (adjustments?['district_orographic_bias_c'] as num?)?.toDouble() ?? 0.0;

    final deltaSign = netDelta >= 0 ? '+' : '';
    final deltaText = '$deltaSign${netDelta.toStringAsFixed(1)}°C local';
    final extraNote = districtBias.abs() >= 0.8
        ? ' • ${districtBias >= 0 ? '+' : ''}${districtBias.toStringAsFixed(1)}°C vs 25km'
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEAEAEA)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.terrain_rounded,
              size: 14,
              color: Color(0xFF1C1C1E),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                elevM != null
                    ? '1km Cell • $zone (${elevM}m)'
                    : '1km Cell • $zone',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF444444),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$deltaText$extraNote',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
