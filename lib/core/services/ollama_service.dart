import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/rewrite_result.dart';
import 'ai_service.dart';

/// Service for interacting with Ollama running on the local machine.
/// Requires Ollama to be installed and running (e.g. http://localhost:11434).
class OllamaService implements AIService {
  static const String _defaultBaseUrl = 'http://localhost:11434';

  final String baseUrl;
  final String model;

  OllamaService({
    String? baseUrl,
    required this.model,
  }) : baseUrl = (baseUrl?.trim().isEmpty ?? true) ? _defaultBaseUrl : baseUrl!.trim().replaceAll(RegExp(r'/$'), '');

  String _buildPrompt(String text, String style) {
    final styleInstructions = {
      'professional':
          'Rewrite this sentence in a professional and clear manner:',
      'casual': 'Rewrite this sentence in a casual and friendly manner:',
      'concise': 'Rewrite this sentence more concisely:',
      'academic': 'Rewrite this sentence in an academic style:',
    };
    final instruction =
        styleInstructions[style] ?? styleInstructions['professional']!;
    return '$instruction\n\n"$text"\n\nProvide only the rewritten sentence without quotes or additional explanation.';
  }

  @override
  Future<RewriteResult> rewriteText(
    String text, {
    String style = 'professional',
  }) async {
    try {
      final prompt = _buildPrompt(text, style);
      final uri = Uri.parse('$baseUrl/api/generate');

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'prompt': prompt,
              'stream': false,
            }),
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw Exception('Request timeout - is Ollama running?');
            },
          );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final rewrittenText = jsonResponse['response'] as String?;
        if (rewrittenText != null && rewrittenText.trim().isNotEmpty) {
          return RewriteResult.success(
            originalText: text,
            rewrittenText: rewrittenText.trim(),
          );
        }
        return RewriteResult.failure(
          originalText: text,
          error: 'Empty response from Ollama',
        );
      }

      String errorMessage = 'HTTP ${response.statusCode}';
      try {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = err['error'] as String? ?? errorMessage;
      } catch (_) {}
      return RewriteResult.failure(
        originalText: text,
        error: errorMessage,
      );
    } catch (e) {
      return RewriteResult.failure(
        originalText: text,
        error: e.toString(),
      );
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      // List models to verify Ollama is reachable and model exists
      final listUri = Uri.parse('$baseUrl/api/tags');
      final listResponse = await http
          .get(listUri)
          .timeout(const Duration(seconds: 5), onTimeout: () {
        throw Exception('Connection timeout');
      });

      if (listResponse.statusCode != 200) {
        return false;
      }

      final json = jsonDecode(listResponse.body) as Map<String, dynamic>;
      final models = json['models'] as List?;
      if (models == null) return false;

      final hasModel = models.any((m) {
        final name = m is Map ? m['name'] as String? : null;
        return name != null && (name == model || name.startsWith('$model:'));
      });
      return hasModel;
    } catch (e) {
      debugPrint('OllamaService testConnection: $e');
      return false;
    }
  }

  /// List available models from the Ollama server.
  Future<List<String>> listModels() async {
    try {
      final uri = Uri.parse('$baseUrl/api/tags');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final models = json['models'] as List?;
      if (models == null) return [];
      return models
          .map((m) => m is Map ? m['name'] as String? : null)
          .whereType<String>()
          .toList();
    } catch (e) {
      debugPrint('OllamaService listModels: $e');
      return [];
    }
  }
}
