import 'dart:io';
import 'package:flutter/services.dart';
import 'package:nobodywho/nobodywho.dart' as nobodywho;
import 'package:path_provider/path_provider.dart';
import '../models/rewrite_result.dart';
import 'ai_service.dart';

/// Service for local LLM inference using NobodyWho with a bundled GGUF model.
///
/// The GGUF model is shipped in `assets/model.gguf` and copied to the
/// application documents directory on first use. Subsequent launches
/// load from the cached copy, avoiding redundant I/O.
class NobodyWhoService implements AIService {
  nobodywho.Model? _model;
  nobodywho.Chat? _chat;
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _currentStyle;

  Function(String)? onStatusChanged;

  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;

  /// Copy the bundled asset to the documents directory if needed, then load it.
  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return;

    _isInitializing = true;
    onStatusChanged?.call('initializing');

    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelFile = File('${dir.path}/model.gguf');

      if (!await modelFile.exists()) {
        onStatusChanged?.call('copying');
        final data = await rootBundle.load('assets/model.gguf');
        await modelFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
      }

      _model = await nobodywho.Model.load(
        modelPath: modelFile.path,
        useGpu: true,
      );
      _chat = nobodywho.Chat(model: _model!);

      _isInitialized = true;
      _isInitializing = false;
      onStatusChanged?.call('ready');
    } catch (e) {
      _isInitialized = false;
      _isInitializing = false;
      onStatusChanged?.call('error');
      rethrow;
    }
  }

  String _systemPromptForStyle(String style) {
    switch (style) {
      case 'professional':
        return 'You are a professional writing assistant. '
            'When given text, rewrite it in a polished, professional tone. '
            'Return ONLY the rewritten text with no explanations or preamble.';
      case 'casual':
        return 'You are a friendly writing assistant. '
            'When given text, rewrite it in a relaxed, casual tone. '
            'Return ONLY the rewritten text with no explanations or preamble.';
      case 'concise':
        return 'You are a concise writing assistant. '
            'When given text, rewrite it to be as brief and clear as possible. '
            'Return ONLY the rewritten text with no explanations or preamble.';
      case 'academic':
        return 'You are an academic writing assistant. '
            'When given text, rewrite it in a formal, scholarly tone. '
            'Return ONLY the rewritten text with no explanations or preamble.';
      default:
        return 'You are a writing assistant. '
            'When given text, rewrite it to improve clarity and quality. '
            'Return ONLY the rewritten text with no explanations or preamble.';
    }
  }

  /// Recreate the chat with the right system prompt when the style changes,
  /// or just reset history between successive rewrites.
  Future<void> _ensureChatForStyle(String style) async {
    if (_chat == null || _model == null) return;
    if (_currentStyle != style) {
      _chat = nobodywho.Chat(
        model: _model!,
        systemPrompt: _systemPromptForStyle(style),
      );
      _currentStyle = style;
    } else {
      await _chat!.resetHistory();
    }
  }

  @override
  Future<RewriteResult> rewriteText(
    String text, {
    String style = 'professional',
    String? customPrompt,
  }) async {
    if (!_isInitialized || _chat == null) {
      return RewriteResult.failure(
        originalText: text,
        error: 'NobodyWho model not initialized',
      );
    }

    try {
      if (customPrompt != null) {
        _chat = nobodywho.Chat(
          model: _model!,
          systemPrompt: customPrompt,
        );
        _currentStyle = null;
      } else {
        await _ensureChatForStyle(style);
      }

      final prompt = 'Rewrite the following text:\n\n$text';
      final response = await _chat!.ask(prompt).completed();
      final trimmed = response.trim();

      if (trimmed.isEmpty) {
        return RewriteResult.failure(
          originalText: text,
          error: 'Empty response from model',
        );
      }

      return RewriteResult.success(originalText: text, rewrittenText: trimmed);
    } catch (e) {
      return RewriteResult.failure(originalText: text, error: e.toString());
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      if (!_isInitialized || _chat == null) return false;
      final result = await rewriteText('Test', style: 'professional');
      return result.success;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _chat = null;
    _model = null;
    _isInitialized = false;
    _currentStyle = null;
  }
}
