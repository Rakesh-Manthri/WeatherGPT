import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../chat/screens/chat_screen.dart';
import '../../../core/localization/language_picker_sheet.dart';
import 'settings_screen.dart';
import '../../weather/screens/live_weather_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const ProfileScreen({super.key, this.onBack});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final user = Supabase.instance.client.auth.currentUser;
  List<dynamic> _chatSessions = [];
  bool _loading = true;

  Future<void> refreshHistory() => _fetchHistory();

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final response = await Supabase.instance.client
          .from('chat_sessions')
          .select('id, title, is_pinned, created_at, chat_messages(content, role, created_at)')
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          _chatSessions = response;
        });
      }
    } catch (e) {
      debugPrint('Error fetching chat sessions: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _togglePin(String sessionId, bool pin) async {
    try {
      await Supabase.instance.client
          .from('chat_sessions')
          .update({'is_pinned': pin})
          .eq('id', sessionId);
      await _fetchHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(pin ? 'Chat pinned to top' : 'Chat unpinned'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling pin: $e');
    }
  }

  void _showRenameDialog(BuildContext context, String sessionId, String currentTitle) {
    final textController = TextEditingController(text: currentTitle);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Rename chat',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E),
          ),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter new title...',
            filled: true,
            fillColor: const Color(0xFFF7F7F7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF757575))),
          ),
          TextButton(
            onPressed: () async {
              final newTitle = textController.text.trim();
              if (newTitle.isNotEmpty) {
                Navigator.pop(ctx);
                try {
                  await Supabase.instance.client
                      .from('chat_sessions')
                      .update({'title': newTitle})
                      .eq('id', sessionId);
                  await _fetchHistory();
                } catch (e) {
                  debugPrint('Error renaming chat: $e');
                }
              }
            },
            child: const Text(
              'Save',
              style: TextStyle(
                color: Color(0xFF1C1C1E),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String sessionId) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete chat?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E),
          ),
        ),
        content: const Text(
          'This will permanently delete this conversation and its messages.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF555555),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF757575))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await Supabase.instance.client
                    .from('chat_sessions')
                    .delete()
                    .eq('id', sessionId);
                if (mounted) {
                  setState(() {
                    _chatSessions.removeWhere((s) => s['id'] == sessionId);
                  });
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Chat deleted'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Error deleting chat: $e');
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Color(0xFFD93025),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChatOptionsBottomSheet(BuildContext context, Map<String, dynamic> session, String title) {
    final isPinned = session['is_pinned'] == true;
    final sessionId = session['id'] as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title preview
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              const SizedBox(height: 8),

              // 1. Pin / Unpin
              ListTile(
                leading: Icon(
                  isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                  color: const Color(0xFF1C1C1E),
                ),
                title: Text(
                  isPinned ? 'Unpin chat' : 'Pin chat to top',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _togglePin(sessionId, !isPinned);
                },
              ),

              // 2. Rename
              ListTile(
                leading: const Icon(
                  Icons.edit_outlined,
                  color: Color(0xFF1C1C1E),
                ),
                title: const Text(
                  'Rename chat',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameDialog(context, sessionId, title);
                },
              ),

              // 3. Delete
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFD93025),
                ),
                title: const Text(
                  'Delete chat',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFD93025),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context, sessionId);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final username = user?.userMetadata?['username'] ?? user?.email ?? 'User';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Navigation Bar matching the signature pill style
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button Pill
                  (widget.onBack != null || Navigator.canPop(context))
                      ? _ProfileCircularIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onPressed: () {
                            if (widget.onBack != null) {
                              widget.onBack!();
                            } else if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                        )
                      : const SizedBox(width: 44, height: 44),

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
                      'Profile',
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
                  _ProfileCircularIconButton(
                    icon: Icons.translate_rounded,
                    onPressed: () => LanguagePickerSheet.show(context),
                  ),
                ],
              ),
            ),

            // Top: Username & Avatar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: const Color(0xFFEFEFEF),
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 26,
                        color: Color(0xFF555555),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    username,
                    style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF555555),
                    ),
                  ),
                ],
              ),
            ),

            // Live Weather Details Card (Tappable to view detailed live telemetry)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 6.0),
              child: Container(
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
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LiveWeatherScreen()),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Live Weather Status',
                                style: TextStyle(
                                  color: Color(0xFF999999),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Connected',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1C1C1E),
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14,
                                    color: Color(0xFF1A73E8),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F7F7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.cloud_done_outlined,
                              size: 26,
                              color: Color(0xFF1A73E8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

          // Chat History Section Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'Chat History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF555555),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Chat Pills List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _chatSessions.isEmpty
                    ? const Center(
                        child: Text(
                          'No chat conversations yet',
                          style: TextStyle(color: Color(0xFF999999)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        itemCount: _chatSessions.length,
                        itemBuilder: (context, index) {
                          final session = _chatSessions[index];
                          final messages = (session['chat_messages'] as List<dynamic>?) ?? [];
                          final isPinned = session['is_pinned'] == true;

                          // Find chat title (custom title or initial user prompt)
                          String title = (session['title'] as String?)?.trim() ?? '';
                          if (title.isEmpty) {
                            for (final m in messages) {
                              if (m['role'] == 'user' && (m['content'] as String).trim().isNotEmpty) {
                                title = (m['content'] as String).trim();
                                break;
                              }
                            }
                          }
                          if (title.isEmpty) {
                            title = 'Weather Conversation';
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        sessionId: session['id'] as String?,
                                      ),
                                    ),
                                  );
                                  _fetchHistory();
                                },
                                onLongPress: () {
                                  _showChatOptionsBottomSheet(context, session, title);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  child: Row(
                                    children: [
                                      // Subtle pin icon if pinned (no chat bubble icon)
                                      if (isPinned) ...[
                                        const Icon(
                                          Icons.push_pin_rounded,
                                          size: 16,
                                          color: Color(0xFF555555),
                                        ),
                                        const SizedBox(width: 8),
                                      ],

                                      // Chat title only (no metadata, not bold even if pinned)
                                      Expanded(
                                        child: Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 15,
                                            color: Color(0xFF1C1C1E),
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 18,
                                        color: Color(0xFFCCCCCC),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Settings icon at the bottom
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 26),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}

/// Circular Header Navigation Button (Back, Language)
class _ProfileCircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _ProfileCircularIconButton({
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
