import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../features/chat/models/chat_message.dart';

class LocalChatStore {
  static const String _sessionsBoxName = 'chat_sessions_box';
  static const String _messagesBoxName = 'chat_messages_box';

  static Box? _sessionsBox;
  static Box? _messagesBox;
  static bool _initialized = false;

  /// Whether the local chat store is ready and active.
  static bool get isAvailable => _initialized && _sessionsBox?.isOpen == true && _messagesBox?.isOpen == true;

  /// Initializes Hive and opens required boxes.
  static Future<void> init() async {
    try {
      if (_sessionsBox == null || !_sessionsBox!.isOpen) {
        _sessionsBox = await Hive.openBox(_sessionsBoxName);
      }
      if (_messagesBox == null || !_messagesBox!.isOpen) {
        _messagesBox = await Hive.openBox(_messagesBoxName);
      }
      _initialized = (_sessionsBox?.isOpen == true) && (_messagesBox?.isOpen == true);
    } catch (e) {
      debugPrint('LocalChatStore init warning: $e');
      _initialized = false;
    }
  }

  /// Resets store state for unit tests.
  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
    _sessionsBox = null;
    _messagesBox = null;
  }

  /// Caches a single session metadata entry.
  static Future<void> saveSession({
    required String sessionId,
    String? title,
    bool isPinned = false,
    DateTime? createdAt,
    String? lastMessage,
  }) async {
    if (!_initialized || _sessionsBox == null || !_sessionsBox!.isOpen) return;
    try {
      final existing = _sessionsBox?.get(sessionId);
      Map<String, dynamic> sessionMap = {};
      if (existing != null) {
        if (existing is Map) {
          sessionMap = Map<String, dynamic>.from(existing);
        } else if (existing is String) {
          try {
            sessionMap = Map<String, dynamic>.from(jsonDecode(existing) as Map);
          } catch (_) {}
        }
      }

      sessionMap['id'] = sessionId;
      if (title != null && title.trim().isNotEmpty) {
        sessionMap['title'] = title.trim();
      } else if (!sessionMap.containsKey('title')) {
        sessionMap['title'] = 'Weather Conversation';
      }
      sessionMap['is_pinned'] = isPinned;
      sessionMap['created_at'] = (createdAt ?? DateTime.now()).toIso8601String();
      if (lastMessage != null) {
        sessionMap['last_message'] = lastMessage;
      }

      await _sessionsBox?.put(sessionId, jsonEncode(sessionMap));
    } catch (e) {
      debugPrint('LocalChatStore.saveSession error: $e');
    }
  }

  /// Bulk caches sessions fetched from remote (e.g. Supabase).
  static Future<void> saveSessionsList(List<dynamic> remoteSessions) async {
    if (!_initialized || _sessionsBox == null || !_sessionsBox!.isOpen) return;
    try {
      for (final raw in remoteSessions) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final id = map['id']?.toString();
        if (id == null || id.isEmpty) continue;

        // Extract chat_messages if nested
        if (map.containsKey('chat_messages') && map['chat_messages'] is List) {
          final msgsList = (map['chat_messages'] as List)
              .whereType<Map>()
              .map((m) => ChatMessage.fromMap(Map<String, dynamic>.from(m)))
              .toList();
          if (msgsList.isNotEmpty) {
            await saveMessages(id, msgsList);
          }
        }

        await _sessionsBox?.put(id, jsonEncode(map));
      }
    } catch (e) {
      debugPrint('LocalChatStore.saveSessionsList error: $e');
    }
  }

  /// Returns all cached chat sessions ordered by is_pinned desc, created_at desc.
  static List<Map<String, dynamic>> getCachedSessions() {
    if (!_initialized || _sessionsBox == null || !_sessionsBox!.isOpen) return [];
    try {
      final List<Map<String, dynamic>> sessions = [];
      for (final key in _sessionsBox!.keys) {
        final val = _sessionsBox!.get(key);
        if (val == null) continue;
        Map<String, dynamic>? sessionMap;
        if (val is Map) {
          sessionMap = Map<String, dynamic>.from(val);
        } else if (val is String) {
          try {
            sessionMap = Map<String, dynamic>.from(jsonDecode(val) as Map);
          } catch (_) {}
        }
        if (sessionMap != null) {
          sessions.add(sessionMap);
        }
      }

      // Sort: pinned first, then newest created_at first
      sessions.sort((a, b) {
        final aPinned = (a['is_pinned'] as bool?) ?? false;
        final bPinned = (b['is_pinned'] as bool?) ?? false;
        if (aPinned != bPinned) {
          return aPinned ? -1 : 1;
        }
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });

      return sessions;
    } catch (e) {
      debugPrint('LocalChatStore.getCachedSessions error: $e');
      return [];
    }
  }

  /// Saves the full list of messages for a session (including weatherData).
  static Future<void> saveMessages(String sessionId, List<ChatMessage> messages) async {
    if (!_initialized || _messagesBox == null || !_messagesBox!.isOpen) return;
    try {
      final list = messages.map((m) => m.toMap()).toList();
      await _messagesBox?.put(sessionId, jsonEncode(list));

      // Also update session last_message if available
      if (messages.isNotEmpty) {
        final last = messages.last;
        await saveSession(
          sessionId: sessionId,
          lastMessage: last.text,
          createdAt: messages.first.timestamp,
        );
      }
    } catch (e) {
      debugPrint('LocalChatStore.saveMessages error: $e');
    }
  }

  /// Appends a single message to an existing session in cache.
  static Future<void> appendMessage(String sessionId, ChatMessage message) async {
    if (!_initialized || _messagesBox == null || !_messagesBox!.isOpen) return;
    try {
      final currentMessages = getCachedMessages(sessionId);
      // Avoid duplicate by id
      final existingIndex = currentMessages.indexWhere((m) => m.id == message.id);
      if (existingIndex >= 0) {
        currentMessages[existingIndex] = message;
      } else {
        currentMessages.add(message);
      }
      await saveMessages(sessionId, currentMessages);
    } catch (e) {
      debugPrint('LocalChatStore.appendMessage error: $e');
    }
  }

  /// Retrieves cached messages for a session.
  static List<ChatMessage> getCachedMessages(String sessionId) {
    if (!_initialized || _messagesBox == null || !_messagesBox!.isOpen) return [];
    try {
      final val = _messagesBox!.get(sessionId);
      if (val == null) return [];

      List<dynamic> rawList = [];
      if (val is List) {
        rawList = val;
      } else if (val is String) {
        try {
          rawList = jsonDecode(val) as List<dynamic>;
        } catch (_) {}
      }

      return rawList
          .whereType<Map>()
          .map((m) => ChatMessage.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    } catch (e) {
      debugPrint('LocalChatStore.getCachedMessages error: $e');
      return [];
    }
  }

  /// Deletes a session and its associated messages.
  static Future<void> deleteSession(String sessionId) async {
    if (!_initialized) return;
    try {
      await _sessionsBox?.delete(sessionId);
      await _messagesBox?.delete(sessionId);
    } catch (e) {
      debugPrint('LocalChatStore.deleteSession error: $e');
    }
  }

  /// Updates a session title in cache.
  static Future<void> updateSessionTitle(String sessionId, String newTitle) async {
    if (!_initialized || _sessionsBox == null || !_sessionsBox!.isOpen) return;
    try {
      final existing = _sessionsBox?.get(sessionId);
      if (existing != null) {
        Map<String, dynamic> sessionMap = {};
        if (existing is Map) {
          sessionMap = Map<String, dynamic>.from(existing);
        } else if (existing is String) {
          try {
            sessionMap = Map<String, dynamic>.from(jsonDecode(existing) as Map);
          } catch (_) {}
        }
        sessionMap['title'] = newTitle;
        await _sessionsBox?.put(sessionId, jsonEncode(sessionMap));
      }
    } catch (e) {
      debugPrint('LocalChatStore.updateSessionTitle error: $e');
    }
  }

  /// Updates pin status in cache.
  static Future<void> updateSessionPin(String sessionId, bool isPinned) async {
    if (!_initialized || _sessionsBox == null || !_sessionsBox!.isOpen) return;
    try {
      final existing = _sessionsBox?.get(sessionId);
      if (existing != null) {
        Map<String, dynamic> sessionMap = {};
        if (existing is Map) {
          sessionMap = Map<String, dynamic>.from(existing);
        } else if (existing is String) {
          try {
            sessionMap = Map<String, dynamic>.from(jsonDecode(existing) as Map);
          } catch (_) {}
        }
        sessionMap['is_pinned'] = isPinned;
        await _sessionsBox?.put(sessionId, jsonEncode(sessionMap));
      }
    } catch (e) {
      debugPrint('LocalChatStore.updateSessionPin error: $e');
    }
  }

  /// Clear all cached chats.
  static Future<void> clearAll() async {
    if (!_initialized) return;
    try {
      await _sessionsBox?.clear();
      await _messagesBox?.clear();
    } catch (e) {
      debugPrint('LocalChatStore.clearAll error: $e');
    }
  }
}
