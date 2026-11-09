import 'package:flutter/material.dart';
import 'locale_service.dart';

class LanguagePickerSheet extends StatelessWidget {
  const LanguagePickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LanguagePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleService.currentLanguageNotifier,
      builder: (context, currentLang, _) {
        final screenHeight = MediaQuery.of(context).size.height;

        return Container(
          height: screenHeight * 0.55,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Drag handle
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F3F4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.translate_rounded,
                          color: Color(0xFF1C1C1E),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Choose Language / भाषा चुनें',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFF0F0F0)),

                // Scrollable Language List
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: LocaleService.supportedLanguages.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF5F5F5)),
                    itemBuilder: (context, index) {
                      final lang = LocaleService.supportedLanguages[index];
                      final isSelected = lang.code == currentLang.code;

                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        tileColor: isSelected ? const Color(0xFFF7F7F7) : Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        title: Text(
                          lang.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: const Color(0xFF1C1C1E),
                          ),
                        ),
                        subtitle: Text(
                          lang.englishName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF888888),
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF1C1C1E),
                                size: 22,
                              )
                            : null,
                        onTap: () async {
                          await LocaleService.setLanguage(lang);
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
