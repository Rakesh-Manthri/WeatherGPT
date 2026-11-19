import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mappls_gl/mappls_gl.dart';
import '../../news/screens/news_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../chat/services/weather_share_service.dart';
import '../../../core/api/weather_api_client.dart';
import '../../../core/cache/offline_weather_cache.dart';
import '../../../core/navigation/slide_page_route.dart';
import '../services/rainviewer_service.dart';
import '../widgets/radar_animation_controls.dart';
import '../widgets/radar_sweep_painter.dart';
import '../widgets/aqi_heatmap_layer.dart';

enum GisMapLayer {
  cleanMap,
  rainfallRadar,
  aqiHeatmap,
}

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

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  final WeatherApiClient _apiClient = WeatherApiClient();
  int _selectedToggleIndex = 1; // 1 represents GIS Map mode
  GisMapLayer _activeGisLayer = GisMapLayer.cleanMap;

  late double _lat;
  late double _lon;
  late String _locationName;
  late Map<String, dynamic> _weather;

  // Rainfall Radar Animation State
  late final AnimationController _radarAnimController;
  Timer? _radarTimer;
  List<RadarFrame> _radarFrames = [];
  int _currentFrameIndex = 0;
  bool _isPlayingRadar = true;

  // AQI Heatmap State
  List<AqiStation> _aqiStations = [];
  bool _isLoadingAqi = false;

  @override
  void initState() {
    super.initState();
    _radarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _resolveLocation();
    _loadRadarFrames();
  }

  @override
  void dispose() {
    _radarTimer?.cancel();
    _radarAnimController.dispose();
    super.dispose();
  }

  void _resolveLocation() {
    if (widget.weatherData != null && widget.weatherData!.isNotEmpty) {
      _weather = Map<String, dynamic>.from(widget.weatherData!);
      _lat = (widget.initialLat ?? _weather['latitude'] as num?)?.toDouble() ?? 17.3850;
      _lon = (widget.initialLon ?? _weather['longitude'] as num?)?.toDouble() ?? 78.4867;
      _locationName = widget.locationName ?? _weather['location_name']?.toString() ?? 'Local Coordinates';
    } else {
      _lat = widget.initialLat ?? 17.3850;
      _lon = widget.initialLon ?? 78.4867;
      _locationName = widget.locationName ?? 'Hyderabad';
      _weather = {
        'location_name': _locationName,
        'latitude': _lat,
        'longitude': _lon,
        'temperature': 28.0,
        'condition': 'Partly Cloudy',
        'rain_chance': 35,
        'humidity': 64,
        'wind_speed': 13.5,
        'wind_direction': 210.0,
        'aqi': 68,
      };

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

  Future<void> _loadRadarFrames() async {
    final frames = await RainviewerService.instance.getRadarFrames();
    if (mounted) {
      setState(() {
        _radarFrames = frames;
        _currentFrameIndex = frames.isNotEmpty ? frames.length - 1 : 0;
      });
    }
  }

  Future<void> _loadAqiGrid() async {
    if (_aqiStations.isNotEmpty) return;
    setState(() => _isLoadingAqi = true);

    try {
      final res = await _apiClient.getAqiGrid(lat: _lat, lon: _lon);
      final rawList = (res['stations'] as List<dynamic>?) ?? [];
      final stations = rawList
          .whereType<Map>()
          .map((m) => AqiStation.fromMap(Map<String, dynamic>.from(m)))
          .toList();

      if (mounted) {
        setState(() {
          _aqiStations = stations;
          _isLoadingAqi = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAqi = false);
    }
  }

  void _startRadarTimer() {
    _radarTimer?.cancel();
    _radarTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (!mounted || !_isPlayingRadar || _radarFrames.isEmpty) return;
      setState(() {
        _currentFrameIndex = (_currentFrameIndex + 1) % _radarFrames.length;
      });
    });
  }

  void _toggleRadarPlay() {
    setState(() {
      _isPlayingRadar = !_isPlayingRadar;
      if (_isPlayingRadar) {
        _radarAnimController.repeat();
        _startRadarTimer();
      } else {
        _radarAnimController.stop();
        _radarTimer?.cancel();
      }
    });
  }

  void _selectRadarFrame(int index) {
    setState(() {
      _currentFrameIndex = index;
    });
  }

  void _switchGisLayer(GisMapLayer layer) {
    setState(() {
      _activeGisLayer = layer;
    });

    if (layer == GisMapLayer.rainfallRadar) {
      _radarAnimController.repeat();
      _isPlayingRadar = true;
      _startRadarTimer();
    } else {
      _radarAnimController.stop();
      _radarTimer?.cancel();
    }

    if (layer == GisMapLayer.aqiHeatmap) {
      _loadAqiGrid();
    }
  }

  void _onMapCreated(MapplsMapController controller) {}

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

  void _shareReportCard() {
    WeatherShareService.instance.showShareModal(
      context,
      weatherData: _weather,
      locationName: _locationName,
      lat: _lat,
      lon: _lon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rainChance = (_weather['rain_chance'] as num?)?.toInt() ?? 35;
    final windSpeed = (_weather['wind_speed'] as num?)?.toDouble() ?? 13.5;
    final windDir = (_weather['wind_direction'] as num?)?.toDouble() ?? 210.0;
    final aqiVal = (_weather['aqi'] as num?)?.toInt() ?? 68;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // 1. Full-screen Clean Vector Map Base
          Positioned.fill(
            child: MapplsMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(_lat, _lon),
                zoom: 11.0,
              ),
              onMapCreated: _onMapCreated,
              myLocationEnabled: true,
              compassEnabled: true,
            ),
          ),

          // 2. Feature 1: Rainfall Radar Animation Overlay
          if (_activeGisLayer == GisMapLayer.rainfallRadar)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _radarAnimController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: RadarSweepPainter(
                        sweepProgress: _radarAnimController.value,
                        frameIndex: _currentFrameIndex,
                        rainChance: rainChance,
                        windSpeed: windSpeed,
                        windDegrees: windDir,
                      ),
                    );
                  },
                ),
              ),
            ),

          // 3. Feature 2: AQI Heatmap on GIS Map Layer
          if (_activeGisLayer == GisMapLayer.aqiHeatmap)
            Positioned.fill(
              child: _isLoadingAqi
                  ? const Center(
                      child: CircularProgressIndicator.adaptive(
                        backgroundColor: Color(0xFF00E676),
                      ),
                    )
                  : AqiHeatmapLayer(
                      stations: _aqiStations,
                      centerAqi: aqiVal,
                    ),
            ),

          // 4. Feature 1: Radar Animation Controls (Scrubber & Play/Pause)
          if (_activeGisLayer == GisMapLayer.rainfallRadar)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: RadarAnimationControls(
                frames: _radarFrames,
                currentIndex: _currentFrameIndex,
                isPlaying: _isPlayingRadar,
                onTogglePlay: _toggleRadarPlay,
                onSelectFrame: _selectRadarFrame,
                rainChance: rainChance,
              ),
            ),

          // 5. Top Floating Navigation Bar (Back, Chat/GIS Toggle, Share Report Card, News)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back Button
                        _MapCircularIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onPressed: _navigateBackToChat,
                          tooltip: 'Back to Chat',
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

                        // Right Action Group: Share Report Card + News
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Feature 3: Share Weather Report Card Button
                            _MapCircularIconButton(
                              icon: Icons.share_rounded,
                              onPressed: _shareReportCard,
                              tooltip: 'Share Weather Report Card',
                            ),
                            const SizedBox(width: 8),

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
                              tooltip: 'Weather Bulletins',
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // GIS Mode Selector Pill (Clean Map vs Rain Radar vs AQI Heatmap)
                    _buildGisLayerSelector(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGisLayerSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLayerTab(
            label: 'Clean Map',
            icon: Icons.map_outlined,
            layer: GisMapLayer.cleanMap,
          ),
          const SizedBox(width: 4),
          _buildLayerTab(
            label: 'Rain Radar',
            icon: Icons.radar_rounded,
            layer: GisMapLayer.rainfallRadar,
          ),
          const SizedBox(width: 4),
          _buildLayerTab(
            label: 'AQI Heatmap',
            icon: Icons.air_rounded,
            layer: GisMapLayer.aqiHeatmap,
          ),
        ],
      ),
    );
  }

  Widget _buildLayerTab({
    required String label,
    required IconData icon,
    required GisMapLayer layer,
  }) {
    final isSelected = _activeGisLayer == layer;

    return GestureDetector(
      onTap: () => _switchGisLayer(layer),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E676) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? const Color(0xFF0F172A) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapCircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  const _MapCircularIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: onPressed,
          child: Center(
            child: Icon(
              icon,
              size: 19,
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
      width: 140,
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.white : const Color(0xFF1C1C1E),
          ),
        ),
      ),
    );
  }
}
