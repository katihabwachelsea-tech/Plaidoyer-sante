// lib/pages/chat_page.dart
//
// Messagerie instantanée entre patient et médecin pour un RDV donné.
// Polling automatique toutes les 5 secondes.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/chat_service.dart';
import '../widgets/metric_card.dart';

class ChatPage extends StatefulWidget {
  final int appointmentId;
  final String otherName; // Nom de l'interlocuteur (Dr. X ou Nom patient)

  const ChatPage({
    super.key,
    required this.appointmentId,
    required this.otherName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _service    = ChatService.instance;
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<ChatMessage> _messages = [];
  bool _loading  = true;
  bool _sending  = false;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // Polling toutes les 5 secondes
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _poll(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final msgs = await _service.getMessages(widget.appointmentId);
      if (mounted) {
        setState(() {
          _messages = msgs;
          _loading  = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _poll() async {
    if (!mounted) return;
    try {
      final msgs = await _service.getMessages(widget.appointmentId);
      if (mounted && msgs.length != _messages.length) {
        setState(() => _messages = msgs);
        _scrollToBottom();
      }
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    _controller.clear();
    setState(() => _sending = true);

    try {
      final msg = await _service.sendMessage(widget.appointmentId, text);
      if (mounted) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
        _controller.text = text; // Restaurer le texte
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const Text(
              'Messagerie RDV',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages()),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 64, color: AppColors.textLight),
            SizedBox(height: 12),
            Text(
              'Aucun message pour l\'instant.\nEnvoyez le premier !',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final showDate = index == 0 ||
            !_isSameDay(
              _messages[index - 1].createdAt,
              msg.createdAt,
            );
        return Column(
          children: [
            if (showDate) _buildDateSeparator(msg.createdAt),
            _buildBubble(msg),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime dt) {
    final label = DateFormat('EEEE d MMMM', 'fr_FR').format(dt);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    final isMe  = msg.isMe;
    final time  = DateFormat('HH:mm').format(msg.createdAt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft:     const Radius.circular(18),
              topRight:    const Radius.circular(18),
              bottomLeft:  Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    msg.senderNom,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              Text(
                msg.contenu,
                style: TextStyle(
                  fontSize: 14,
                  color: isMe ? Colors.white : AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppColors.textLight,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      msg.lu
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      size: 13,
                      color: msg.lu
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12, 8, 12, 8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Écrire un message…',
                  hintStyle:
                      const TextStyle(color: AppColors.textLight),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _sending
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
