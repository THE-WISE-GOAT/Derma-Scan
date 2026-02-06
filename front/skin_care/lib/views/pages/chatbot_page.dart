import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:skin_care/modules/app_theme.dart';
import 'package:skin_care/modules/app_config.dart';
import 'package:skin_care/views/shared/glass_appbar.dart';

class ChatbotPage extends StatefulWidget {
  final String? initialSystemContext;
  const ChatbotPage({super.key, this.initialSystemContext});

  @override
  State<ChatbotPage> createState() => ChatbotPageState();
}

class ChatbotPageState extends State<ChatbotPage> {
  final List<ChatMessage> messages = [];
  final TextEditingController controller = TextEditingController();
  bool sending = false;
  String selectedModel = 'qwen2.5:3b';

  void toggleModel() {
    setState(() {
      selectedModel =
          selectedModel == 'openrouter' ? 'qwen2.5:3b' : 'openrouter';
    });
  }

  Future<void> sendMessage() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    if (sending) return;

    setState(() {
      messages.add(ChatMessage(fromUser: true, text: text));
      controller.clear();
      sending = true;
    });

    try {
      final history = <Map<String, dynamic>>[];

      final baseSystemPrompt =
          'You are a medical chatbot that ONLY answers questions about skin, acne, dermatology, rashes, pigmentation, sun protection, scars, skin-care routines, and related topics. '
          'If the user asks about anything outside skin or dermatology, reply with a short apology and say you can only help with skin-related questions. '
          'Do not create blog posts, stories, essays, or long articles. '
          'Always answer in short, clear sentences and plain text. Do not use markdown, bullet points, headings, asterisks, or special formatting.';

      String systemContent = baseSystemPrompt;
      if (widget.initialSystemContext != null &&
          widget.initialSystemContext!.trim().isNotEmpty) {
        systemContent +=
            ' Here is context about the user’s last skin scan: ${widget.initialSystemContext}.';
      }

      history.add({
        'role': 'system',
        'content': systemContent,
      });

      for (final m in messages) {
        history.add({
          'role': m.fromUser ? 'user' : 'assistant',
          'content': m.text,
        });
      }

      final apiBaseUrl =
          await AppConfig.getApiBaseUrl() ?? 'https://secondly-unlidded-lennox.ngrok-free.dev';
      final uri = Uri.parse('$apiBaseUrl/chat');

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': selectedModel,
          'messages': history,
        }),
      ).timeout(const Duration(minutes: 2));

      if (res.statusCode == 200) {
        final jsonData = jsonDecode(res.body);
        final reply =
            jsonData['reply'] as String? ?? 'I could not generate a response.';
        setState(() {
          messages.add(ChatMessage(fromUser: false, text: reply));
        });
      } else {
        setState(() {
          messages.add(ChatMessage(
            fromUser: false,
            text: 'Error from API: ${res.statusCode}',
          ));
        });
      }
    } catch (e) {
      setState(() {
        messages.add(ChatMessage(
          fromUser: false,
          text: 'Could not reach API: $e',
        ));
      });
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  void initState() {
    super.initState();

    messages.add(const ChatMessage(
      fromUser: false,
      text:
          'Hi. I am your skin health assistant. Ask anything about your scans or skin care routine.',
    ));

    if (widget.initialSystemContext != null &&
        widget.initialSystemContext!.trim().isNotEmpty) {
      messages.add(const ChatMessage(
        fromUser: false,
        text:
            'I loaded your latest scan context. You can ask follow-up questions about it.',
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: AppTheme.backgroundDecoration(context)),
          Column(
            children: [
              const GlassAppBar(
                title: 'AI Chat',
                subtitle: 'Ask about your skin',
              ),

              // Model selector
              Container(
                margin: const EdgeInsets.all(16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: AppTheme.glassCardDecoration(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Model:', style: textTheme.bodyMedium),
                    Expanded(
                      child: Text(
                        selectedModel.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: toggleModel,
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Switch'),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final align = msg.fromUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft;
                    final bg = msg.fromUser
                        ? scheme.primary
                        : scheme.surface.withOpacity(0.75);
                    final fg =
                        msg.fromUser ? scheme.onPrimary : scheme.onSurface;

                    return Align(
                      alignment: align,
                        child: Row(
                          mainAxisAlignment: msg.fromUser
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            if (!msg.fromUser)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(
                                  Icons.smart_toy_outlined,
                                  size: 20,
                                  color: scheme.primary.withOpacity(0.7),
                                ),
                              ),
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(12),
                              constraints: const BoxConstraints(maxWidth: 280),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                msg.text,
                                style: textTheme.bodyMedium?.copyWith(color: fg),
                              ),
                            ),
                          ],
                      ),
                    );
                  },
                ),
              ),

              SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Container(
                    decoration: AppTheme.glassCardDecoration(context),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Ask about products, routines...',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            maxLines: null,
                            onSubmitted: sending ? null : (_) => sendMessage(),
                          ),
                        ),
                        IconButton(
                          icon: sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 3),
                                )
                              : const Icon(Icons.send_rounded),
                          onPressed: sending ? null : sendMessage,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final bool fromUser;
  final String text;
  const ChatMessage({required this.fromUser, required this.text});
}
