import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';
import 'panchangam_weather_card.dart';
import 'weather_card_bubble.dart';
import 'weather_map_bubble.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final void Function(double lat, double lon)? onViewMap;
  final VoidCallback? onSpeakTap;
  final VoidCallback? onRetryTap;
  final VoidCallback? onEditTap;
  final VoidCallback? onCopyTap;
  final bool isSpeaking;

  const MessageBubble({
    super.key,
    required this.message,
    this.onViewMap,
    this.onSpeakTap,
    this.onRetryTap,
    this.onEditTap,
    this.onCopyTap,
    this.isSpeaking = false,
  });

  String _formatContent(String rawText) {
    final trimmed = rawText.trim();
    // If the LLM returned raw unformatted JSON, pretty-format it inside a code block
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      try {
        final decoded = json.decode(trimmed);
        const encoder = JsonEncoder.withIndent('  ');
        return '```json\n${encoder.convert(decoded)}\n```';
      } catch (_) {
        return rawText;
      }
    }
    return rawText;
  }

  String _stripOfflinePrefix(String text) {
    var cleaned = text;
    cleaned = cleaned.replaceFirst(
      RegExp(r'^\*\([^\)]*Cached[^\)]*\)\*\s*', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceFirst(
      RegExp(r'^\*\([^\)]*AI[^\)]*\)\*\s*', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceFirst(
      RegExp(r'^\*\([^\)]*एआई[^\)]*\)\*\s*', caseSensitive: false),
      '',
    );
    return cleaned;
  }

  void _showMessageActionSheet(BuildContext context) {
    final isUser = message.isUser;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (isUser && onEditTap != null)
                  ListTile(
                    leading: const Icon(Icons.edit_outlined, color: Color(0xFF1C1C1E)),
                    title: const Text('Edit Message'),
                    subtitle: const Text('Modify this message and resend'),
                    onTap: () {
                      Navigator.pop(ctx);
                      onEditTap?.call();
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.copy_rounded, color: Color(0xFF1C1C1E)),
                  title: const Text('Copy to Clipboard'),
                  subtitle: Text(isUser ? 'Copy query text' : 'Copy formatted response'),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (onCopyTap != null) {
                      onCopyTap!.call();
                    } else {
                      Clipboard.setData(ClipboardData(text: message.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                ),
                if (!isUser && onRetryTap != null)
                  ListTile(
                    leading: const Icon(Icons.refresh_rounded, color: Color(0xFF1A73E8)),
                    title: const Text('Retry Response'),
                    subtitle: const Text('Regenerate response from model'),
                    onTap: () {
                      Navigator.pop(ctx);
                      onRetryTap?.call();
                    },
                  ),
                if (!isUser && onSpeakTap != null)
                  ListTile(
                    leading: Icon(
                      isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up_rounded,
                      color: isSpeaking ? const Color(0xFFD93025) : const Color(0xFF1C1C1E),
                    ),
                    title: Text(isSpeaking ? 'Stop Speaking' : 'Read Aloud'),
                    subtitle: Text(
                      message.detectedLanguage != null
                          ? 'Text-to-Speech in ${message.detectedLanguage}'
                          : 'Listen to this response',
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onSpeakTap?.call();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final formattedContent = _formatContent(message.text);
    final displayContent = message.isOfflineEdgeAi
        ? _stripOfflinePrefix(formattedContent)
        : formattedContent;
    final weatherMap = message.weatherData;
    final hasWeatherData = !isUser && weatherMap != null;
    final hasWeatherTelemetry =
        hasWeatherData && weatherMap.containsKey('temperature');
    final panchangamData = !isUser && weatherMap != null
        ? weatherMap['panchangam_fusion'] as Map<String, dynamic>?
        : null;
    final hasMap = !isUser && message.showMapBubble && hasWeatherData;
    final hasCard = hasWeatherTelemetry || panchangamData != null || hasMap;
    final showActionRow = !isUser &&
        displayContent.isNotEmpty &&
        (onCopyTap != null || onRetryTap != null || onSpeakTap != null);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageActionSheet(context),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: hasCard
              ? const EdgeInsets.all(12)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isUser ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(20).copyWith(
              bottomRight: isUser ? const Radius.circular(4) : null,
              bottomLeft: !isUser ? const Radius.circular(4) : null,
            ),
            boxShadow: !isUser
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * (hasCard ? 0.92 : 0.85),
          ),
          child: isUser
              ? Text(
                  message.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    height: 1.4,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.isOfflineEdgeAi)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFE082)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.offline_bolt_rounded,
                              size: 14,
                              color: Color(0xFFF57C00),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Offline Edge AI${message.offlineCacheAge != null ? ' • ${message.offlineCacheAge}' : ''}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFE65100),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (hasMap)
                      WeatherMapBubble(
                        weatherData: weatherMap,
                        onExpandFullscreen: onViewMap,
                      ),
                    if (hasWeatherTelemetry)
                      WeatherCardBubble(
                        weatherData: weatherMap,
                        onViewMap: onViewMap,
                      ),
                    if (panchangamData != null)
                      PanchangamWeatherCard(
                        panchangamData: panchangamData,
                      ),
                    if (displayContent.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          top: hasCard ? 6 : 0,
                          left: hasCard ? 4 : 0,
                          right: hasCard ? 4 : 0,
                        ),
                        child: MarkdownBody(
                          data: displayContent,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                              color: Color(0xFF1C1C1E),
                              fontSize: 15.0,
                              height: 1.45,
                            ),
                            h1: const TextStyle(
                              color: Color(0xFF1C1C1E),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'serif',
                              height: 1.3,
                            ),
                            h2: const TextStyle(
                              color: Color(0xFF1C1C1E),
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'serif',
                              height: 1.3,
                            ),
                            h3: const TextStyle(
                              color: Color(0xFF1C1C1E),
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                            strong: const TextStyle(
                              color: Color(0xFF1C1C1E),
                              fontWeight: FontWeight.bold,
                            ),
                            listBullet: const TextStyle(
                              color: Color(0xFF1C1C1E),
                            ),
                            code: TextStyle(
                              color: const Color(0xFF1A73E8),
                              backgroundColor: Colors.grey.shade100,
                              fontSize: 14,
                              fontFamily: 'monospace',
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: const Color(0xFFF1F3F4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE0E0E0)),
                            ),
                          ),
                        ),
                      ),
                    if (showActionRow)
                      Padding(
                        padding: EdgeInsets.only(
                          top: 10,
                          left: hasCard ? 4 : 0,
                          right: hasCard ? 4 : 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (onCopyTap != null)
                              _BubbleActionButton(
                                icon: Icons.copy_rounded,
                                label: 'Copy',
                                onTap: onCopyTap!,
                              ),
                            if (onRetryTap != null) ...[
                              const SizedBox(width: 6),
                              _BubbleActionButton(
                                icon: Icons.refresh_rounded,
                                label: 'Retry',
                                onTap: onRetryTap!,
                              ),
                            ],
                            if (onSpeakTap != null) ...[
                              const SizedBox(width: 6),
                              _BubbleActionButton(
                                icon: isSpeaking
                                    ? Icons.stop_circle_outlined
                                    : Icons.volume_up_rounded,
                                label: isSpeaking
                                    ? 'Stop'
                                    : (message.detectedLanguage != null
                                        ? 'Listen (${message.detectedLanguage})'
                                        : 'Listen'),
                                isActive: isSpeaking,
                                onTap: onSpeakTap!,
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _BubbleActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _BubbleActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE8F1FC) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? const Color(0xFF1A73E8) : const Color(0xFF5F6368),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isActive ? const Color(0xFF1A73E8) : const Color(0xFF5F6368),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
