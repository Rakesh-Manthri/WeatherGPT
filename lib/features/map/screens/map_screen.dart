import 'package:flutter/material.dart';
import 'package:mappls_gl/mappls_gl.dart';
import '../../news/screens/news_screen.dart';
import '../../chat/screens/chat_screen.dart';
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

class _MapScreenState extends State<MapScreen> {
  int _selectedToggleIndex = 1; // 1 represents GIS Map mode

  late double _lat;
  late double _lon;

  @override
  void initState() {
    super.initState();
    _resolveLocation();
  }

  void _resolveLocation() {
    if (widget.weatherData != null && widget.weatherData!.isNotEmpty) {
      final weather = widget.weatherData!;
      _lat = (widget.initialLat ?? weather['latitude'] as num?)?.toDouble() ?? 17.3850;
      _lon = (widget.initialLon ?? weather['longitude'] as num?)?.toDouble() ?? 78.4867;
    } else {
      _lat = widget.initialLat ?? 17.3850;
      _lon = widget.initialLon ?? 78.4867;

      OfflineWeatherCache.instance.getCachedTelemetry().then((cached) {
        if (cached != null && mounted && widget.initialLat == null) {
          setState(() {
            _lat = (cached['latitude'] as num?)?.toDouble() ?? _lat;
            _lon = (cached['longitude'] as num?)?.toDouble() ?? _lon;
          });
        }
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // 1. Full-screen Clean Vector Map (All overlay components removed)
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

          // 2. Top Floating Navigation Bar (Back button, Chat/GIS Map toggle, News button)
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
        ],
      ),
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
