import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/screens/auth_screen.dart';
import '../../../core/localization/language_picker_sheet.dart';
import '../../../core/api/weather_api_client.dart';
import '../../../core/ai/offline_edge_ai_service.dart';
import '../../../core/cache/offline_weather_cache.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _usernameController = TextEditingController();
  bool _isEditing = false;
  bool _isSaving = false;
  bool _offlineMode = WeatherApiClient.forceOfflineMode;
  bool _isSyncingCache = false;
  String _cacheSummary = 'Loading cache...';

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    _usernameController.text =
        user?.userMetadata?['username'] ?? user?.email?.split('@').first ?? '';
    _loadOfflineEdgeState();
  }

  Future<void> _loadOfflineEdgeState() async {
    await WeatherApiClient.loadOfflinePreference();
    await OfflineEdgeAiService.instance.init();
    final cacheAge = await OfflineWeatherCache.instance.getCacheAgeString();
    final data = await OfflineWeatherCache.instance.getCachedTelemetry();
    if (mounted) {
      setState(() {
        _offlineMode = WeatherApiClient.forceOfflineMode;
        if (data != null) {
          final loc = data['location_name'] ?? 'Local Area';
          final temp = data['temperature'] ?? '--';
          final cond = data['condition'] ?? '';
          _cacheSummary = '$loc • $temp°C ${cond.isNotEmpty ? '($cond) ' : ''}• Cached $cacheAge';
        } else {
          _cacheSummary = 'No offline telemetry cached yet';
        }
      });
    }
  }

  Future<void> _syncLiveCache() async {
    setState(() => _isSyncingCache = true);
    try {
      final res = await OfflineWeatherCache.instance.syncFromLiveOpenMeteo();
      await _loadOfflineEdgeState();
      if (mounted) {
        final loc = res?['location_name'] ?? 'Local Area';
        final temp = res?['temperature'] ?? '--';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Live cache refreshed: $loc ($temp°C)'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sync live weather: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingCache = false);
    }
  }

  Future<void> _clearCache() async {
    await OfflineWeatherCache.instance.clear();
    await _loadOfflineEdgeState();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offline telemetry cache cleared'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _saveUsername() async {
    final newUsername = _usernameController.text.trim();
    if (newUsername.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'username': newUsername}),
      );
      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign Out',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E),
          ),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Color(0xFF555555)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF555555)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(
                color: Color(0xFFD93025),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        // Pop all the way back to root
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final username =
        user?.userMetadata?['username'] ?? user?.email?.split('@').first ?? 'User';
    final email = user?.email ?? 'Not signed in';
    final isSignedIn = user != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar matching the signature pill style
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button Pill
                  _SettingsCircularIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: () => Navigator.pop(context),
                  ),

                  // Pill Styled Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
                      'Settings',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),

                  // Language Button Pill
                  _SettingsCircularIconButton(
                    icon: Icons.translate_rounded,
                    onPressed: () => LanguagePickerSheet.show(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              children: [
                // Profile Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: const Color(0xFFEFEFEF),
                        child: Text(
                          username.isNotEmpty ? username[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 32,
                            color: Color(0xFF555555),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Username (editable)
                      if (_isEditing)
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _usernameController,
                                autofocus: true,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1C1C1E),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Username',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE0E0E0),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE0E0E0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF1C1C1E),
                                      width: 1.5,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _isSaving
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF1C1C1E),
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(
                                      Icons.check_rounded,
                                      color: Color(0xFF1C1C1E),
                                    ),
                                    onPressed: _saveUsername,
                                  ),
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFF999999),
                              ),
                              onPressed: () {
                                setState(() {
                                  _isEditing = false;
                                  _usernameController.text = username;
                                });
                              },
                            ),
                          ],
                        )
                      else
                        Text(
                          username,
                          style: const TextStyle(
                            fontFamily: 'serif',
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1C1C1E),
                          ),
                        ),

                      const SizedBox(height: 6),

                      // Email
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF999999),
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Edit Profile Option
                _SettingsTile(
                  icon: Icons.edit_outlined,
                  title: 'Edit Profile',
                  subtitle: 'Change your display name',
                  onTap: isSignedIn
                      ? () {
                          setState(() => _isEditing = true);
                        }
                      : null,
                ),

                const SizedBox(height: 10),

                // Sign In tile (shown when not signed in)
                if (!isSignedIn)
                  _SettingsTile(
                    icon: Icons.login_rounded,
                    title: 'Sign In',
                    subtitle: 'Sign in to sync your chats',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AuthScreen()),
                      );
                      if (mounted) setState(() {});
                    },
                  ),

                const SizedBox(height: 24),

                // Offline Edge AI Section Header
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text(
                    'OFFLINE EDGE AI (PHASE 3)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Color(0xFF888888),
                    ),
                  ),
                ),

                // Offline Mode Force Switch
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _offlineMode
                              ? const Color(0xFFFFF3E0)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.offline_bolt_rounded,
                          size: 20,
                          color: _offlineMode
                              ? const Color(0xFFF57C00)
                              : const Color(0xFF555555),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Force Offline Edge Mode',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1C1C1E),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Test zero-connectivity Qwen2.5 SLM reasoning',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF999999),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _offlineMode,
                        activeTrackColor: const Color(0xFFF57C00),
                        onChanged: (val) async {
                          await WeatherApiClient.setForceOfflineMode(val);
                          setState(() => _offlineMode = val);
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Model Management Tile
                ValueListenableBuilder<EdgeAiStatus>(
                  valueListenable: OfflineEdgeAiService.instance.statusNotifier,
                  builder: (context, status, _) {
                    final isReady = status == EdgeAiStatus.ready;
                    final isDownloading = status == EdgeAiStatus.downloading;

                    return _SettingsTile(
                      icon: Icons.memory_rounded,
                      title: 'Qwen2.5-0.5B-Instruct Model',
                      subtitle: isReady
                          ? 'Quantized INT4 (Q4_K_M ~352MB) • Ready'
                          : (isDownloading
                              ? 'Initializing / downloading edge model...'
                              : 'Tap to initialize on-device SLM weights'),
                      onTap: () async {
                        if (isDownloading) return;
                        if (!isReady) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Initializing Qwen2.5-0.5B on-device model bundle...'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          await OfflineEdgeAiService.instance.downloadModel();
                          if (mounted) setState(() {});
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Qwen2.5-0.5B INT4 is ready for zero-latency offline inference.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),

                const SizedBox(height: 10),

                // Cache Telemetry Status
                _SettingsTile(
                  icon: Icons.cached_rounded,
                  title: 'Local Telemetry Cache',
                  subtitle: _cacheSummary,
                  onTap: () async {
                    await _loadOfflineEdgeState();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Cache status: $_cacheSummary'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),

                const SizedBox(height: 10),

                // Sync Live Weather into Cache
                _SettingsTile(
                  icon: Icons.sync_rounded,
                  title: 'Sync Live Weather Cache',
                  subtitle: _isSyncingCache
                      ? 'Fetching live satellite & ground telemetry...'
                      : 'Refresh local cache with live Open-Meteo readings',
                  onTap: _isSyncingCache ? null : _syncLiveCache,
                ),

                const SizedBox(height: 10),

                // Clear Offline Cache
                _SettingsTile(
                  icon: Icons.delete_sweep_outlined,
                  title: 'Clear Cache',
                  subtitle: 'Purge local telemetry cache to force fresh re-sync',
                  onTap: _clearCache,
                ),
              ],
            ),
          ),

          // Bottom Logout Button
          if (isSignedIn)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 20,
                    color: Color(0xFFD93025),
                  ),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD93025),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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

/// Reusable settings list tile
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: const Color(0xFF555555)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFFCCCCCC),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular Header Navigation Button for Settings Screen
class _SettingsCircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _SettingsCircularIconButton({
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
