import 'package:flutter/material.dart';

class ActivityChipsBar extends StatelessWidget {
  final void Function(String prompt) onChipSelected;

  const ActivityChipsBar({
    super.key,
    required this.onChipSelected,
  });

  static const List<Map<String, String>> _chips = [
    {
      'icon': '🗺️',
      'label': 'GIS Radar & Wind Map',
      'prompt': 'Show interactive radar map with wind and precipitation cells.',
    },
    {
      'icon': '🏃',
      'label': 'Running & Workout',
      'prompt': 'What is the outdoor running and workout suitability rating right now?',
    },
    {
      'icon': '🧥',
      'label': 'What to wear?',
      'prompt': 'What should I wear today based on current and evening weather?',
    },
    {
      'icon': '🌧️',
      'label': 'Rain Timeline',
      'prompt': 'Is it going to rain today? Give me an hourly rain timeline.',
    },
    {
      'icon': '🍃',
      'label': 'Air Quality Advisory',
      'prompt': 'How is the air quality (AQI) today and what health precautions should I take?',
    },
    {
      'icon': '✈️',
      'label': 'Commute & Travel',
      'prompt': 'Will current weather conditions cause any commute, road, or flight delays?',
    },
    {
      'icon': '☀️',
      'label': 'UV & Sun Index',
      'prompt': 'What is the UV index and sun protection recommendation for today?',
    },
    {
      'icon': '🪔',
      'label': 'Panchangam & Muhurtham',
      'prompt': 'Show today\'s Panchangam, Tithi, Nakshatra, and best weather Muhurtham windows.',
    },
    {
      'icon': '🌱',
      'label': 'Farming & Tithi',
      'prompt': 'Is today auspicious and weather-suitable for sowing crops per Panchangam?',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: _chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = _chips[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(19),
              onTap: () => onChipSelected(chip['prompt']!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      offset: const Offset(0, 1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(chip['icon']!, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(
                      chip['label']!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
