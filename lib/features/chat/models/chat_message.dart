import 'package:uuid/uuid.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Map<String, dynamic>? weatherData;
  final String? ttsText;
  final String? ttsLocale;
  final String? detectedLanguage;
  final bool isOfflineEdgeAi;
  final String? offlineCacheAge;
  final bool showMapBubble;
  final bool isEditable;

  ChatMessage({
    String? id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.weatherData,
    this.ttsText,
    this.ttsLocale,
    this.detectedLanguage,
    this.isOfflineEdgeAi = false,
    this.offlineCacheAge,
    this.showMapBubble = false,
    bool? isEditable,
  })  : id = id ?? const Uuid().v4(),
        isEditable = isEditable ?? isUser;
}
