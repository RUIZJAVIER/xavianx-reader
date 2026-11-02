import 'dart:async';

import 'package:anx_reader/service/ai/index.dart';
import 'package:anx_reader/widgets/markdown/styled_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:langchain_core/chat_models.dart';

class VocabularyCoachPage extends ConsumerStatefulWidget {
  const VocabularyCoachPage({super.key});

  @override
  ConsumerState<VocabularyCoachPage> createState() =>
      _VocabularyCoachPageState();
}

class _VocabularyCoachPageState extends ConsumerState<VocabularyCoachPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isStreaming = false;

  static const String _coachSystemPrompt =
      'Eres un Coach de Idiomas y Aprendizaje. Guías, motivas y diseñas planes de repaso '
      'personalizados para el estudiante. Tienes acceso a herramientas del sistema, especialmente '
      '"get_srs_statistics" para consultar en tiempo real el progreso de los mazos, tarjetas nuevas '
      'y repasos pendientes, y "manage_vocabulary" para listar o actualizar mnemotecnias. '
      'Responde siempre de forma motivadora, clara y estructurada en el idioma del usuario.';

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage.ai(
        '¡Hola! Soy tu Coach de Idiomas y Aprendizaje 🎓✨\n\n'
        'Estoy aquí para ayudarte a dominar tu vocabulario, optimizar tus repasos espaciados (SRS) '
        'y planificar tus metas. Puedo revisar tus estadísticas de hoy y aconsejarte qué mazo priorizar.\n\n'
        '¿En qué te gustaría enfocarte?',
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? textToSend]) async {
    final text = (textToSend ?? _textController.text).trim();
    if (text.isEmpty || _isStreaming) return;

    _textController.clear();
    setState(() {
      _messages.add(ChatMessage.humanText(text));
      _messages.add(ChatMessage.ai(''));
      _isStreaming = true;
    });
    _scrollToBottom();

    final messagesToSend = _messages.sublist(0, _messages.length - 1);

    try {
      final stream = aiGenerateStream(
        messagesToSend,
        useAgent: true,
        ref: ref,
        customSystemMessage: ChatMessage.system(_coachSystemPrompt),
      );

      var responseBuffer = '';
      await for (final chunk in stream) {
        if (!mounted) return;
        responseBuffer = chunk;
        setState(() {
          _messages[_messages.length - 1] = ChatMessage.ai(responseBuffer);
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages[_messages.length - 1] = ChatMessage.ai(
          'Lo siento, ocurrió un error al comunicarme con el modelo: $e',
        );
      });
    } finally {
      if (mounted) setState(() => _isStreaming = false);
    }
  }

  Widget _quickChip(String label, String prompt) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: _isStreaming ? null : () => _sendMessage(prompt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach de Aprendizaje'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                _quickChip('📊 Mi progreso hoy',
                    'Consulta mis estadísticas de tarjetas con get_srs_statistics y dame un resumen de mi progreso hoy.'),
                const SizedBox(width: 8),
                _quickChip('🎯 ¿Qué mazo repasar?',
                    'Analiza mis mazos y dime cuál necesita más atención según las tarjetas pendientes.'),
                const SizedBox(width: 8),
                _quickChip('💡 Consejos de memorización',
                    'Dame consejos rápidos y técnicas mnemotécnicas para retener mejor palabras difíciles.'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message is HumanChatMessage;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: isUser
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      if (!isUser) ...[
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(Icons.psychology,
                              size: 18, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUser
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: isUser
                              ? Text(
                                  message.contentAsString,
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                )
                              : StyledMarkdown(
                                  text: message.contentAsString.isEmpty &&
                                          _isStreaming
                                      ? 'Pensando...'
                                      : message.contentAsString,
                                ),
                        ),
                      ),
                      if (isUser) ...[
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          child: Icon(Icons.person,
                              size: 18, color: theme.colorScheme.secondary),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Pregunta a tu coach...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: _isStreaming
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  onPressed: _isStreaming ? null : () => _sendMessage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
