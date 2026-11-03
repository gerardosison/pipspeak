import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/pip_misc.dart';
import '../feedback/local_llm_service.dart';

class LocalCoachScreen extends StatefulWidget {
  const LocalCoachScreen({super.key});

  @override
  State<LocalCoachScreen> createState() => _LocalCoachScreenState();
}

class _LocalCoachScreenState extends State<LocalCoachScreen> {
  final _llm = LocalLlmService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_CoachMessage> _messages = [];
  bool _busy = false;
  InferenceCancellation? _request;
  String _status = 'Offline Qwen assistant';

  @override
  void dispose() {
    _request?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final question = _input.text.trim();
    if (question.isEmpty || _busy) return;
    final request = InferenceCancellation();
    _request = request;
    _input.clear();
    setState(() {
      _busy = true;
      _messages.add(_CoachMessage(question, true));
      _messages.add(_CoachMessage('', false));
      _status = _llm.isLoaded ? 'Qwen is responding…' : 'Loading local Qwen…';
    });
    final replyIndex = _messages.length - 1;
    final rawReply = StringBuffer();
    final renderClock = Stopwatch()..start();
    try {
      if (!_llm.isLoaded) {
        await Future.any<void>([
          _llm.initialize(
            onStatus: (message) {
              if (mounted && !request.isCancelled) {
                setState(() => _status = message);
              }
            },
          ),
          request.whenCancelled,
        ]);
      }
      if (!mounted || request.isCancelled) return;
      final history = _messages
          .take(replyIndex - 1)
          .where((message) => message.includeInHistory)
          .map(
            (message) => ChatMessage(
              role: message.isUser ? 'user' : 'assistant',
              content: message.text,
            ),
          )
          .toList();
      await for (final token in _llm.generateStream(
        userMessage: question,
        conversationHistory: history,
        maxTokens: 256,
        cancellation: request,
      )) {
        if (!mounted || request.isCancelled) return;
        rawReply.write(token);
        // Rebuild at most 25 times per second, rather than once per token.
        if (renderClock.elapsedMilliseconds < 40) continue;
        renderClock.reset();
        setState(() {
          _messages[replyIndex].text = LocalLlmService.stripThinking(
            rawReply.toString(),
          );
        });
        _scrollToBottom();
      }
      final answer = LocalLlmService.stripThinking(rawReply.toString());
      if (answer.isEmpty) {
        throw StateError('The model returned no answer. Try again.');
      }
      if (mounted) {
        setState(() => _messages[replyIndex].text = answer);
      }
      if (mounted) setState(() => _status = 'Offline Qwen assistant');
    } catch (error) {
      if (mounted && !request.isCancelled) {
        setState(() {
          _messages[replyIndex - 1].includeInHistory = false;
          _messages[replyIndex].includeInHistory = false;
          _messages[replyIndex].text = 'Could not answer locally: $error';
          _status = 'Qwen could not answer';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          if (request.isCancelled) {
            _messages[replyIndex - 1].includeInHistory = false;
            _messages[replyIndex].includeInHistory = false;
            _messages[replyIndex].text =
                LocalLlmService.stripThinking(rawReply.toString()).isEmpty
                ? 'Response stopped.'
                : LocalLlmService.stripThinking(rawReply.toString());
            _status = 'Response stopped';
          }
        });
      }
      if (identical(_request, request)) _request = null;
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: pipAppBar(context, title: 'Ask Local Qwen'),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                const Icon(Icons.offline_bolt, color: AppColors.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _status,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'Magtanong tungkol sa speech, presentation, o kahit ibang paksa. Sasagot ang Qwen nang offline sa device na ito.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return Align(
                        alignment: message.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 520),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: message.isUser
                                ? AppColors.navy
                                : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            message.text.isEmpty && _busy ? '…' : message.text,
                            style: TextStyle(
                              color: message.isUser
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Type your question…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _busy
                      ? () {
                          _request?.cancel();
                          setState(() => _status = 'Stopping response…');
                        }
                      : _send,
                  icon: Icon(_busy ? Icons.stop_rounded : Icons.send_rounded),
                  tooltip: _busy ? 'Stop response' : 'Send to local Qwen',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _CoachMessage {
  _CoachMessage(this.text, this.isUser);

  String text;
  final bool isUser;
  bool includeInHistory = true;
}
