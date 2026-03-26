import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';

class AiCoachFab extends StatefulWidget {
  const AiCoachFab({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<AiCoachFab> createState() => _AiCoachFabState();
}

class _AiCoachFabState extends State<AiCoachFab> {
  static const _kPosXKey = 'ai_coach_pos_x';
  static const _kPosYKey = 'ai_coach_pos_y';
  static const _kMemoryIdKey = 'ai_coach_memory_id';
  static const _kMessagesKey = 'ai_coach_messages';
  static const _kFabSize = 60.0;

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = <_ChatMessage>[];

  double _x = 16;
  double _y = 420;
  int _memoryId = DateTime.now().millisecondsSinceEpoch % 1000000;
  int _unreadCount = 0;
  bool _expanded = false;
  bool _sending = false;
  bool _initialized = false;
  bool _prefsAvailable = true;

  @override
  void initState() {
    super.initState();
    _loadLocalState();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalState() async {
    double? savedX;
    double? savedY;
    int? savedMemoryId;
    String? rawMessages;
    try {
      final prefs = await SharedPreferences.getInstance();
      savedX = prefs.getDouble(_kPosXKey);
      savedY = prefs.getDouble(_kPosYKey);
      savedMemoryId = prefs.getInt(_kMemoryIdKey);
      rawMessages = prefs.getString(_kMessagesKey);
    } on MissingPluginException {
      _prefsAvailable = false;
    } catch (_) {
      _prefsAvailable = false;
    }
    final restoredMessages = <_ChatMessage>[];
    if (rawMessages != null && rawMessages.isNotEmpty) {
      final decoded = jsonDecode(rawMessages) as List<dynamic>;
      for (final item in decoded) {
        restoredMessages.add(_ChatMessage.fromJson(item as Map<String, dynamic>));
      }
    }

    if (!mounted) return;
    setState(() {
      if (savedX != null) _x = savedX;
      if (savedY != null) _y = savedY;
      if (savedMemoryId != null) _memoryId = savedMemoryId;
      if (restoredMessages.isNotEmpty) {
        _messages
          ..clear()
          ..addAll(restoredMessages);
      } else {
        _messages
          ..clear()
          ..add(
            const _ChatMessage(
              role: _MessageRole.ai,
              text: '你好，我是你的智能教练。告诉我你的目标或今天的训练计划。',
            ),
          );
      }
      _initialized = true;
    });
    _scrollToBottom(jump: true);
  }

  Future<void> _saveLocalState() async {
    if (!_prefsAvailable) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kPosXKey, _x);
      await prefs.setDouble(_kPosYKey, _y);
      await prefs.setInt(_kMemoryIdKey, _memoryId);
      await prefs.setString(
        _kMessagesKey,
        jsonEncode(_messages.map((m) => m.toJson()).toList()),
      );
    } on MissingPluginException {
      _prefsAvailable = false;
    } catch (_) {
      _prefsAvailable = false;
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final offset = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(offset);
      } else {
        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _messages.add(_ChatMessage(role: _MessageRole.user, text: text));
      _messages.add(const _ChatMessage(role: _MessageRole.ai, text: ''));
      _inputController.clear();
    });
    _saveLocalState();
    _scrollToBottom();

    var unreadAdded = false;
    try {
      await for (final chunk in widget.apiClient.aiCoachChatStream(
        memoryId: _memoryId,
        message: text,
      )) {
        if (!mounted) return;
        setState(() {
          final last = _messages.last;
          _messages[_messages.length - 1] = _ChatMessage(
            role: _MessageRole.ai,
            text: last.text + chunk,
          );
          if (!_expanded && !unreadAdded && chunk.trim().isNotEmpty) {
            _unreadCount += 1;
            unreadAdded = true;
          }
        });
        _saveLocalState();
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(role: _MessageRole.ai, text: '请求失败：$e'));
        if (!_expanded) _unreadCount += 1;
      });
      _saveLocalState();
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
      _scrollToBottom();
    }
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) _unreadCount = 0;
    });
    if (_expanded) {
      _scrollToBottom();
    }
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    final maxX = size.width - _kFabSize - 8;
    final maxY = size.height - _kFabSize - 8;
    setState(() {
      _x = (_x + details.delta.dx).clamp(8.0, maxX);
      _y = (_y + details.delta.dy).clamp(8.0, maxY);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final maxX = size.width - _kFabSize - 8;
        final maxY = size.height - _kFabSize - 8;
        if (_x > maxX || _y > maxY) {
          _x = _x.clamp(8.0, maxX);
          _y = _y.clamp(8.0, maxY);
        }

        return Stack(
          children: [
            if (_expanded)
              Positioned(
                left: 12,
                right: 12,
                bottom: 88,
                top: 72,
                child: Material(
                  elevation: 12,
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.smart_toy_outlined),
                        ),
                        title: const Text('智能教练'),
                        subtitle: const Text('实时 AI 对话'),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _toggleExpanded,
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final item = _messages[index];
                            final isUser = item.role == _MessageRole.user;
                            return Align(
                              alignment: isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                                ),
                                decoration: BoxDecoration(
                                  color: isUser ? Colors.blueAccent : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  item.text,
                                  style: TextStyle(
                                    color: isUser ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _inputController,
                                  minLines: 1,
                                  maxLines: 4,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _sendMessage(),
                                  decoration: const InputDecoration(
                                    hintText: '输入你的训练/饮食问题...',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                onPressed: _sending ? null : _sendMessage,
                                icon: _sending
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.send),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              left: _x,
              top: _y,
              child: GestureDetector(
                onPanUpdate: (details) => _onPanUpdate(details, size),
                onPanEnd: (_) => _saveLocalState(),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    FloatingActionButton(
                      heroTag: 'ai_coach_fab',
                      onPressed: _toggleExpanded,
                      backgroundColor: Colors.blueAccent,
                      child: const Icon(Icons.smart_toy_outlined),
                    ),
                    if (_unreadCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                          child: Center(
                            child: Text(
                              _unreadCount > 99 ? '99+' : '$_unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _MessageRole { user, ai }

class _ChatMessage {
  const _ChatMessage({required this.role, required this.text});

  final _MessageRole role;
  final String text;

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'text': text,
      };

  static _ChatMessage fromJson(Map<String, dynamic> json) {
    final roleText = json['role'] as String? ?? _MessageRole.ai.name;
    return _ChatMessage(
      role: roleText == _MessageRole.user.name ? _MessageRole.user : _MessageRole.ai,
      text: json['text'] as String? ?? '',
    );
  }
}
