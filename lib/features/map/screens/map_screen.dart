import 'package:flutter/material.dart';
import 'package:mappls_gl/mappls_gl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/screens/auth_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../news/screens/news_screen.dart';
import '../../../core/navigation/slide_page_route.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapplsMapController? mapController;
  int _selectedToggleIndex = 1; // 1 represents Mountain / Map mode

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Stack(
        children: [
          // Fullscreen Map
          Positioned.fill(
            child: MapplsMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(28.6139, 77.2090), // New Delhi
                zoom: 11.0,
              ),
              onMapCreated: (MapplsMapController controller) {
                mapController = controller;
              },
              myLocationEnabled: true,
              myLocationTrackingMode: MyLocationTrackingMode.tracking,
            ),
          ),

          // Floating Top Navigation Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back or Profile Button (slides from left to right if opened)
                  _MapCircularIconButton(
                    icon: Navigator.canPop(context)
                        ? Icons.arrow_back_ios_new_rounded
                        : Icons.person_outline_rounded,
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        final session = Supabase.instance.client.auth.currentSession;
                        final target = session == null ? const AuthScreen() : const ProfileScreen();
                        Navigator.push(
                          context,
                          SlidePageRoute(
                            page: target,
                            direction: SlideDirection.leftToRight,
                          ),
                        );
                      }
                    },
                  ),

                  // Search / Map Mode Segmented Toggle
                  _MapSegmentedToggle(
                    selectedIndex: _selectedToggleIndex,
                    onChanged: (index) {
                      setState(() {
                        _selectedToggleIndex = index;
                      });
                      if (index == 0) {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      }
                    },
                  ),

                  // News Button (slides from right to left)
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
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _MapToggleOption(
              icon: Icons.search_rounded,
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
