import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/weather_api_client.dart';

class NewsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const NewsScreen({super.key, this.onBack});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final WeatherApiClient _apiClient = WeatherApiClient();
  String _selectedCategory = 'ALL';
  String _selectedSource = 'ALL';
  bool _isLoading = true;
  bool _isOfflineCache = false;
  List<Map<String, dynamic>> _articles = [];
  String? _errorMessage;

  static const List<Map<String, String>> _sources = [
    {'id': 'ALL', 'label': 'All Sources', 'icon': '🌐'},
    {'id': 'GOVERNMENT', 'label': 'Govt (IMD/NDMA)', 'icon': '🏛️'},
    {'id': 'GLOBAL', 'label': 'Global (BBC/Reuters)', 'icon': '🌍'},
    {'id': 'SCIENCE', 'label': 'Science (ISRO/ICAR)', 'icon': '🔬'},
  ];

  static const List<Map<String, String>> _categories = [
    {'id': 'ALL', 'label': 'All Updates', 'icon': '📰'},
    {'id': 'ALERTS', 'label': 'Disaster Alerts', 'icon': '🚨'},
    {'id': 'AGRICULTURE', 'label': 'Krishi & Sowing', 'icon': '🌱'},
    {'id': 'CYCLONE', 'label': 'Cyclones & Squalls', 'icon': '🌀'},
    {'id': 'MONSOON', 'label': 'Monsoon Surge', 'icon': '🌧️'},
    {'id': 'CLIMATE', 'label': 'Microclimate & UHI', 'icon': '🌡️'},
  ];

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  String _cacheKey(String source, String category) => 'cached_news_${source}_$category';

  Future<void> _loadNews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isOfflineCache = false;
    });

    try {
      final items = await _apiClient.getWeatherNews(
        category: _selectedCategory,
        source: _selectedSource,
        limit: 20,
      );

      // Cache locally in SharedPreferences for offline reading
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey(_selectedSource, _selectedCategory), jsonEncode(items));
      } catch (_) {}

      if (mounted) {
        setState(() {
          _articles = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Offline fallback: load from SharedPreferences cache
      List<Map<String, dynamic>> fallback = [];
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedJson = prefs.getString(_cacheKey(_selectedSource, _selectedCategory));
        if (cachedJson != null && cachedJson.isNotEmpty) {
          final decoded = jsonDecode(cachedJson) as List<dynamic>;
          fallback = decoded.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (fallback.isNotEmpty) {
            _articles = fallback;
            _isOfflineCache = true;
          } else {
            _errorMessage = 'Could not load meteorological news: $e';
          }
        });
      }
    }
  }

  void _onCategorySelected(String categoryId) {
    if (_selectedCategory == categoryId) return;
    setState(() {
      _selectedCategory = categoryId;
    });
    _loadNews();
  }

  void _onSourceSelected(String sourceId) {
    if (_selectedSource == sourceId) return;
    setState(() {
      _selectedSource = sourceId;
    });
    _loadNews();
  }

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
                  _NewsCircularIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: () {
                      if (widget.onBack != null) {
                        widget.onBack!();
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.feed_rounded, size: 16, color: Color(0xFF1C1C1E)),
                        SizedBox(width: 6),
                        Text(
                          'Weather & Agro Bulletins',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1C1C1E),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  _NewsCircularIconButton(
                    icon: Icons.refresh_rounded,
                    onPressed: _loadNews,
                  ),
                ],
              ),
            ),

            // Source Selector Bar (Multi-Source Expansion: Govt, Global Wire, Science)
            Container(
              height: 38,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _sources.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final src = _sources[index];
                  final isSelected = src['id'] == _selectedSource;

                  return GestureDetector(
                    onTap: () => _onSourceSelected(src['id']!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF1E3A8A) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF1E3A8A)
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(src['icon']!, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 6),
                          Text(
                            src['label']!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF4B5563),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Category Horizontal Chips Bar
            SizedBox(
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = cat['id'] == _selectedCategory;

                  return GestureDetector(
                    onTap: () => _onCategorySelected(cat['id']!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF1C1C1E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF1C1C1E)
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cat['icon']!, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 6),
                          Text(
                            cat['label']!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF555555),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_isOfflineCache)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.offline_pin_rounded, size: 13, color: Color(0xFFD97706)),
                    SizedBox(width: 6),
                    Text(
                      'Showing offline cached articles',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // News Feed List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2.5,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNews,
                      child: _articles.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 100),
                                Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        _errorMessage != null
                                            ? Icons.error_outline_rounded
                                            : Icons.check_circle_outline_rounded,
                                        size: 48,
                                        color: _errorMessage != null
                                            ? Colors.orange.shade400
                                            : Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _errorMessage ?? 'No reports in this category',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontFamily: 'serif',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF666666),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                              itemCount: _articles.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final article = _articles[index];
                                return _WeatherNewsCard(article: article);
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherNewsCard extends StatelessWidget {
  final Map<String, dynamic> article;

  const _WeatherNewsCard({required this.article});

  Color _getSeverityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return const Color(0xFFD32F2F);
      case 'WARNING':
        return const Color(0xFFF57C00);
      case 'ADVISORY':
        return const Color(0xFF1976D2);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  String _formatTimeAgo(dynamic epochSec) {
    if (epochSec is! num) return 'Recently';
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = nowSec - epochSec.toInt();
    if (diff < 3600) return '${(diff / 60).round()}m ago';
    if (diff < 86400) return '${(diff / 3600).round()}h ago';
    return '${(diff / 86400).round()}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final title = article['title']?.toString() ?? 'Weather Bulletin';
    final summary = article['summary']?.toString() ?? '';
    final source = article['source']?.toString() ?? 'Official Meteorological Bureau';
    final sourceType = (article['source_type']?.toString() ?? 'GOVERNMENT').toUpperCase();
    final severity = article['severity']?.toString() ?? 'INFO';
    final region = article['region']?.toString() ?? 'India';
    final citations = (article['citations'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final severityColor = _getSeverityColor(severity);
    final timeAgo = _formatTimeAgo(article['published_at']);

    // Source Type Badge Details
    String sourceBadgeLabel = '🏛️ Govt';
    Color sourceBadgeBg = const Color(0xFFEFF6FF);
    Color sourceBadgeColor = const Color(0xFF1D4ED8);

    if (sourceType == 'GLOBAL') {
      sourceBadgeLabel = '🌍 Global';
      sourceBadgeBg = const Color(0xFFF5F3FF);
      sourceBadgeColor = const Color(0xFF6D28D9);
    } else if (sourceType == 'SCIENCE') {
      sourceBadgeLabel = '🔬 Science';
      sourceBadgeBg = const Color(0xFFECFDF5);
      sourceBadgeColor = const Color(0xFF047857);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag & Time Header with Multi-Source Badge
          Row(
            children: [
              // Severity pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  severity.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: severityColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Source type badge (Govt / Global / Science)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                decoration: BoxDecoration(
                  color: sourceBadgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sourceBadgeLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: sourceBadgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Region pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 11, color: Color(0xFF4B5563)),
                    const SizedBox(width: 3),
                    Text(
                      region,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF444444),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),
              Text(
                timeAgo,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Headline
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'serif',
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1E),
              height: 1.3,
              letterSpacing: -0.2,
            ),
          ),

          const SizedBox(height: 8),

          // Summary Body
          Text(
            summary,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF444444),
              height: 1.45,
            ),
          ),

          const SizedBox(height: 14),

          // Verifiable Citations Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 13, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        source,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
                    ),
                  ],
                ),
                if (citations.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: citations.map((citation) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                        ),
                        child: Text(
                          '🔗 $citation',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF666666),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsCircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _NewsCircularIconButton({
    required this.icon,
    required this.onPressed,
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
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: const Color(0xFF1C1C1E)),
        onPressed: onPressed,
      ),
    );
  }
}
