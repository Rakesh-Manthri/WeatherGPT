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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'weatherData': weatherData,
      'ttsText': ttsText,
      'ttsLocale': ttsLocale,
      'detectedLanguage': detectedLanguage,
      'isOfflineEdgeAi': isOfflineEdgeAi,
      'offlineCacheAge': offlineCacheAge,
      'showMapBubble': showMapBubble,
      'isEditable': isEditable,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? weather;
    if (map['weatherData'] != null && map['weatherData'] is Map) {
      weather = Map<String, dynamic>.from(map['weatherData'] as Map);
    } else if (map['weather_data'] != null && map['weather_data'] is Map) {
      weather = Map<String, dynamic>.from(map['weather_data'] as Map);
    }

    final isUserVal = map['isUser'] as bool? ?? (map['role'] == 'user');
    final textVal = (map['text'] as String?) ?? (map['content'] as String?) ?? '';
    final dateStr = (map['timestamp'] as String?) ?? (map['created_at'] as String?) ?? '';

    return ChatMessage(
      id: map['id'] as String?,
      text: textVal,
      isUser: isUserVal,
      timestamp: DateTime.tryParse(dateStr) ?? DateTime.now(),
      weatherData: weather,
      ttsText: map['ttsText'] as String?,
      ttsLocale: map['ttsLocale'] as String?,
      detectedLanguage: map['detectedLanguage'] as String?,
      isOfflineEdgeAi: map['isOfflineEdgeAi'] as bool? ?? false,
      offlineCacheAge: map['offlineCacheAge'] as String?,
      showMapBubble: map['showMapBubble'] as bool? ?? false,
      isEditable: map['isEditable'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage.fromMap(json);
}
