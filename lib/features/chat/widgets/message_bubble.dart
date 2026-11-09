import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';
import 'weather_card_bubble.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final void Function(double lat, double lon)? onViewMap;

  const MessageBubble({
    super.key,
    required this.message,
    this.onViewMap,
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

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final content = _formatContent(message.text);
    final hasWeatherData = !isUser && message.weatherData != null;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: hasWeatherData
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
          maxWidth: MediaQuery.of(context).size.width * (hasWeatherData ? 0.92 : 0.85),
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
                  if (hasWeatherData)
                    WeatherCardBubble(
                      weatherData: message.weatherData!,
                      onViewMap: onViewMap,
                    ),
                  if (content.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                        top: hasWeatherData ? 6 : 0,
                        left: hasWeatherData ? 4 : 0,
                        right: hasWeatherData ? 4 : 0,
                      ),
                      child: MarkdownBody(
                        data: content,
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
                ],
              ),
      ),
    );
  }
}
