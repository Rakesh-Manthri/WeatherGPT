class ChatMessage {
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

  ChatMessage({
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
  });
}
