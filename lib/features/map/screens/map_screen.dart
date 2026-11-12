import 'package:flutter/material.dart';
import 'package:mappls_gl/mappls_gl.dart';
import '../../news/screens/news_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../chat/widgets/weather_map_bubble.dart';
import '../../../core/cache/offline_weather_cache.dart';
import '../../../core/navigation/slide_page_route.dart';

class MapScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLon;
  final String? locationName;
  final Map<String, dynamic>? weatherData;
  final VoidCallback? onBackToChat;

  const MapScreen({
    super.key,
    this.initialLat,
    this.initialLon,
    this.locationName,
    this.weatherData,
    this.onBackToChat,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  MapplsMapController? _mapController;
  int _selectedToggleIndex = 1; // 1 represents GIS Map mode
  MapLayerType _activeLayer = MapLayerType.radarPrecipitation;
  late final AnimationController _radarAnimController;

  late double _lat;
  late double _lon;
  late String _locationName;
  late Map<String, dynamic> _weather;
  bool _isCardExpanded = true;

  @override
  void initState() {
    super.initState();
    _radarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _resolveLocationAndTelemetry();
  }

  void _resolveLocationAndTelemetry() {
    if (widget.weatherData != null && widget.weatherData!.isNotEmpty) {
      _weather = Map<String, dynamic>.from(widget.weatherData!);
      _lat = (widget.initialLat ?? _weather['latitude'] as num?)?.toDouble() ?? 17.3850;
      _lon = (widget.initialLon ?? _weather['longitude'] as num?)?.toDouble() ?? 78.4867;
      _locationName = widget.locationName ??
          _weather['location_name']?.toString() ??
          'Local Coordinates';
    } else {
      _lat = widget.initialLat ?? 17.3850;
      _lon = widget.initialLon ?? 78.4867;
      _locationName = widget.locationName ?? 'Hyderabad';
      _weather = {
        'location_name': _locationName,
        'latitude': _lat,
        'longitude': _lon,
        'temperature': 29.0,
        'condition': 'Partly Cloudy',
        'rain_chance': 45,
        'humidity': 68,
        'wind_speed': 14.5,
        'wind_direction': 210.0,
        'aqi': 72,
        'spatial_downscaling': {
          'microclimate_zone': '1km High-Density Urban UHI (+1.8°C)',
        },
      };

      // Check offline cache asynchronously to enrich if available
      OfflineWeatherCache.instance.getCachedTelemetry().then((cached) {
        if (cached != null && mounted) {
          setState(() {
            _weather = cached;
            if (widget.initialLat == null) {
              _lat = (cached['latitude'] as num?)?.toDouble() ?? _lat;
              _lon = (cached['longitude'] as num?)?.toDouble() ?? _lon;
              _locationName = cached['location_name']?.toString() ?? _locationName;
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _radarAnimController.dispose();
    super.dispose();
  }

  void _onMapCreated(MapplsMapController controller) {
    _mapController = controller;
  }

  void _zoomIn() {
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  void _recenter() {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(_lat, _lon), 11.5),
    );
  }

  void _navigateBackToChat() {
    if (widget.onBackToChat != null) {
      widget.onBackToChat!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final temp = (_weather['temperature'] as num?)?.round() ?? 28;
    final cond = (_weather['condition'] ?? 'Partly Cloudy').toString();
    final rainChance = (_weather['rain_chance'] as num?)?.toInt() ?? 30;
    final windSpeed = (_weather['wind_speed'] as num?)?.toDouble() ?? 14.0;
    final windDir = (_weather['wind_direction'] as num?)?.toDouble() ?? 210.0;
    final hum = (_weather['humidity'] as num?)?.toInt() ?? 65;
    final aqi = (_weather['aqi'] as num?)?.toInt() ?? 70;
    final downscaling = _weather['spatial_downscaling'] as Map<String, dynamic>?;
    final microZone = downscaling?['microclimate_zone']?.toString() ?? '1km Grid Cell';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Underlying Vector Map Base
          Positioned.fill(
            child: MapplsMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(_lat, _lon),
                zoom: 11.0,
              ),
              onMapCreated: _onMapCreated,
              myLocationEnabled: false,
              compassEnabled: false,
            ),
          ),

          // Animated Radar Sweep & GIS Data Overlay (Precipitation, Wind, Thermal)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _radarAnimController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: GisRadarOverlayPainter(
                      sweepProgress: _radarAnimController.value,
                      layer: _activeLayer,
                      rainChance: rainChance,
                      windSpeed: windSpeed,
                      windDegrees: windDir,
                    ),
                  );
                },
              ),
            ),
          ),

          // Center Pin with Microclimate Pulse Ring
          Center(
            child: IgnorePointer(
              child: _buildLocationPin(temp.toString(), cond),
            ),
          ),

          // Top Floating Navigation Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back / Profile Button
                  _MapCircularIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: _navigateBackToChat,
                  ),

                  // Chat / GIS Map Segmented Toggle
                  _MapSegmentedToggle(
                    selectedIndex: _selectedToggleIndex,
                    onChanged: (index) {
                      if (index == 0) {
                        _navigateBackToChat();
                      } else {
                        setState(() => _selectedToggleIndex = 1);
                      }
                    },
                  ),

                  // News Button
                  _MapCircularIconButton(
                    icon: Icons.article_outlined,
                    onPressed: () {
                      Navigator.push(
                        context,
                        SlidePageRoute(
                          page: const NewsScreen(),
                          direction: SlideDirection.rightToLeft,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Floating Map Zoom / Recenter Controls (Right Side)
          Positioned(
            right: 18,
            top: 100,
            child: Column(
              children: [
                _buildFloatingActionBtn(
                  icon: Icons.add_rounded,
                  onPressed: _zoomIn,
                  tooltip: 'Zoom In',
                ),
                const SizedBox(height: 8),
                _buildFloatingActionBtn(
                  icon: Icons.remove_rounded,
                  onPressed: _zoomOut,
                  tooltip: 'Zoom Out',
                ),
                const SizedBox(height: 8),
                _buildFloatingActionBtn(
                  icon: Icons.my_location_rounded,
                  onPressed: _recenter,
                  tooltip: 'Recenter Pin',
                ),
              ],
            ),
          ),

          // Layer Toggle Selector (Left Floating Bar)
          Positioned(
            left: 18,
            top: 100,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E).withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLayerPill(
                    label: 'Radar',
                    icon: Icons.water_drop_rounded,
                    layer: MapLayerType.radarPrecipitation,
                  ),
                  const SizedBox(height: 4),
                  _buildLayerPill(
                    label: 'Wind',
                    icon: Icons.air_rounded,
                    layer: MapLayerType.windStreamlines,
                  ),
                  const SizedBox(height: 4),
                  _buildLayerPill(
                    label: '1km UHI',
                    icon: Icons.thermostat_rounded,
                    layer: MapLayerType.thermalElevation,
                  ),
                ],
              ),
            ),
          ),

          // Floating Bottom Telemetry Card
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _buildTelemetryCard(
              temp: temp,
              cond: cond,
              rainChance: rainChance,
              windSpeed: windSpeed,
              windDir: windDir,
              hum: hum,
              aqi: aqi,
              microZone: microZone,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPin(String temp, String cond) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF00E676)),
              const SizedBox(width: 4),
              Text(
                '$temp°C',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFF00E676),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E676).withValues(alpha: 0.6),
                blurRadius: 12,
                spreadRadius: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionBtn({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E).withValues(alpha: 0.90),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: Colors.white),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildLayerPill({
    required String label,
    required IconData icon,
    required MapLayerType layer,
  }) {
    final isSelected = _activeLayer == layer;
    return GestureDetector(
      onTap: () => setState(() => _activeLayer = layer),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00E676).withValues(alpha: 0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: const Color(0xFF00E676), width: 1.2)
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? const Color(0xFF00E676) : Colors.white70,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF00E676) : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryCard({
    required int temp,
    required String cond,
    required int rainChance,
    required double windSpeed,
    required double windDir,
    required int hum,
    required int aqi,
    required String microZone,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Location and Toggle Collapse
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF00E676),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _locationName,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      '${_lat.toStringAsFixed(4)}°N, ${_lon.toStringAsFixed(4)}°E • $microZone',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _isCardExpanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  color: const Color(0xFF64748B),
                ),
                onPressed: () => setState(() => _isCardExpanded = !_isCardExpanded),
                tooltip: _isCardExpanded ? 'Collapse' : 'Expand',
              ),
            ],
          ),

          if (_isCardExpanded) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),

            // Metrics Grid Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricCol(
                  icon: Icons.thermostat_rounded,
                  color: const Color(0xFFF57C00),
                  label: '$temp°C',
                  sub: cond,
                ),
                _buildMetricCol(
                  icon: Icons.water_drop_rounded,
                  color: const Color(0xFF0288D1),
                  label: '$rainChance%',
                  sub: 'Precipitation',
                ),
                _buildMetricCol(
                  icon: Icons.air_rounded,
                  color: const Color(0xFF10B981),
                  label: '${windSpeed.round()} km/h',
                  sub: 'Wind',
                ),
                _buildMetricCol(
                  icon: Icons.speed_rounded,
                  color: const Color(0xFF8B5CF6),
                  label: '$aqi AQI',
                  sub: 'Air Quality',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCol({
    required IconData icon,
    required Color color,
    required String label,
    required String sub,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        Text(
          sub,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _MapCircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _MapCircularIconButton({
    required this.icon,
    required this.onPressed,
  });

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
            color: Colors.black.withValues(alpha: 0.1),
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
            child: Icon(
              icon,
              size: 20,
              color: const Color(0xFF1C1C1E),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapSegmentedToggle extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _MapSegmentedToggle({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 48,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _MapToggleOption(
              icon: Icons.chat_bubble_outline_rounded,
              isSelected: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _MapToggleOption(
              icon: Icons.landscape_rounded,
              isSelected: selectedIndex == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapToggleOption extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _MapToggleOption({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1C1C1E) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 19,
            color: isSelected ? Colors.white : const Color(0xFF1C1C1E),
          ),
        ),
      ),
    );
  }
}
