import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/rewrite_result.dart';
import 'rate_limit_service.dart';

/// Service for interacting with Google Gemini API
class GeminiService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1';
  // Try different model names - will auto-detect available one
  static const List<String> _modelCandidates = [
    'gemini-1.5-flash',
    'gemini-1.5-pro',
    'gemini-pro',
    'gemini-2.0-flash-exp',
    'models/gemini-1.5-flash',
    'models/gemini-1.5-pro',
  ];

  final String apiKey;
  final RateLimitService? rateLimitService;
  String? _cachedModel;

  GeminiService({required this.apiKey, this.rateLimitService});

  /// Get the model name to use (with fallback)
  Future<String> _getModelName() async {
    // If we've already found a working model, use it
    if (_cachedModel != null) {
      return _cachedModel!;
    }

    // Try to find an available model
    try {
      final availableModels = await listAvailableModels();
      debugPrint('Available models: $availableModels');

      // Look for a model that supports generateContent
      for (final candidate in _modelCandidates) {
        // Remove 'models/' prefix if present for comparison
        final candidateName = candidate.replaceFirst('models/', '');
        // Check if any available model matches (handle both with and without 'models/' prefix)
        final matchingModel = availableModels.firstWhere((m) {
          final modelName = m.replaceFirst('models/', '');
          return modelName == candidateName || m.contains(candidateName);
        }, orElse: () => '');

        if (matchingModel.isNotEmpty) {
          // Use the model name as returned by API (might include 'models/' prefix)
          _cachedModel = matchingModel;
          debugPrint('Using model: $_cachedModel');
          return _cachedModel!;
        }
      }

      // If no match found, try first available model
      if (availableModels.isNotEmpty) {
        _cachedModel = availableModels.first;
        debugPrint('Using first available model: $_cachedModel');
        return _cachedModel!;
      }
    } catch (e) {
      debugPrint('Error detecting model, using fallback: $e');
    }

    // Fallback to first candidate
    _cachedModel = _modelCandidates.first;
    debugPrint('Using fallback model: $_cachedModel');
    return _cachedModel!;
  }

  /// Rewrite text using Gemini API - generates 2 different versions
  Future<List<RewriteResult>> rewriteTextMultiple(
    String text, {
    String style = 'professional',
  }) async {
    // Generate 2 different rewritten versions
    final results = <RewriteResult>[];

    // First version: standard rewrite
    final result1 = await rewriteText(text, style: style);
    results.add(result1);

    // Second version: alternative rewrite (try different approach)
    if (result1.success) {
      // Ask for an alternative version
      final result2 = await rewriteTextAlternative(text, style: style);
      results.add(result2);
    } else {
      // If first failed, try again with same style
      final result2 = await rewriteText(text, style: style);
      results.add(result2);
    }

    return results;
  }

  /// Rewrite text using Gemini API
  Future<RewriteResult> rewriteText(
    String text, {
    String style = 'professional',
  }) async {
    try {
      // Check rate limit before making request
      if (rateLimitService != null) {
        final rateLimitCheck = await rateLimitService!.canMakeRequest();
        if (!rateLimitCheck.allowed) {
          final reason = rateLimitCheck.reason == RateLimitReason.perMinuteLimit
              ? 'Rate limit: Too many requests per minute'
              : rateLimitCheck.reason == RateLimitReason.perHourLimit
              ? 'Rate limit: Too many requests per hour'
              : 'Rate limit: Daily limit reached';
          return RewriteResult.failure(originalText: text, error: reason);
        }
      }

      final modelName = await _getModelName();
      // Model name from API might be "models/gemini-1.5-flash" or just "gemini-1.5-flash"
      // If it includes "models/", use it directly, otherwise add "models/" prefix
      final cleanModelName = modelName.startsWith('models/')
          ? modelName.replaceFirst('models/', '')
          : modelName;
      final url =
          '$_baseUrl/models/$cleanModelName:generateContent?key=$apiKey';
      debugPrint('Using API URL: $url');

      final prompt = _buildPrompt(text, style);

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
            }),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timeout');
            },
          );

      if (response.statusCode == 200) {
        // Record successful request
        if (rateLimitService != null) {
          await rateLimitService!.recordRequest();
        }

        final jsonResponse = jsonDecode(response.body);
        final rewrittenText = _extractText(jsonResponse);

        if (rewrittenText != null && rewrittenText.isNotEmpty) {
          return RewriteResult.success(
            originalText: text,
            rewrittenText: rewrittenText,
          );
        } else {
          return RewriteResult.failure(
            originalText: text,
            error: 'Empty response from API',
          );
        }
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['error']?['message'] ?? 'Unknown error';
        return RewriteResult.failure(
          originalText: text,
          error: 'API Error: $errorMessage',
        );
      }
    } catch (e) {
      return RewriteResult.failure(originalText: text, error: e.toString());
    }
  }

  /// Rewrite text with alternative approach
  Future<RewriteResult> rewriteTextAlternative(
    String text, {
    String style = 'professional',
  }) async {
    try {
      final modelName = await _getModelName();
      // Model name from API might be "models/gemini-1.5-flash" or just "gemini-1.5-flash"
      // If it includes "models/", use it directly, otherwise add "models/" prefix
      final cleanModelName = modelName.startsWith('models/')
          ? modelName.replaceFirst('models/', '')
          : modelName;
      final url =
          '$_baseUrl/models/$cleanModelName:generateContent?key=$apiKey';
      debugPrint('Using API URL (alternative): $url');

      final prompt = _buildAlternativePrompt(text, style);

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
            }),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timeout');
            },
          );

      if (response.statusCode == 200) {
        // Record successful request
        if (rateLimitService != null) {
          await rateLimitService!.recordRequest();
        }

        final jsonResponse = jsonDecode(response.body);
        final rewrittenText = _extractText(jsonResponse);

        if (rewrittenText != null && rewrittenText.isNotEmpty) {
          return RewriteResult.success(
            originalText: text,
            rewrittenText: rewrittenText,
          );
        } else {
          return RewriteResult.failure(
            originalText: text,
            error: 'Empty response from API',
          );
        }
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['error']?['message'] ?? 'Unknown error';
        return RewriteResult.failure(
          originalText: text,
          error: 'API Error: $errorMessage',
        );
      }
    } catch (e) {
      return RewriteResult.failure(originalText: text, error: e.toString());
    }
  }

  /// Build prompt for rewriting
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

  /// Build alternative prompt for second version
  String _buildAlternativePrompt(String text, String style) {
    final alternativeInstructions = {
      'professional':
          'Rewrite this sentence in a professional manner, but with a different wording and structure:',
      'casual':
          'Rewrite this sentence in a casual manner, but with a different tone:',
      'concise': 'Rewrite this sentence more concisely, using different words:',
      'academic':
          'Rewrite this sentence in an academic style, but with different phrasing:',
    };

    final instruction =
        alternativeInstructions[style] ??
        alternativeInstructions['professional']!;

    return '$instruction\n\n"$text"\n\nProvide only the rewritten sentence without quotes or additional explanation.';
  }

  /// Extract text from Gemini API response
  String? _extractText(Map<String, dynamic> jsonResponse) {
    try {
      final candidates = jsonResponse['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      if (content == null) return null;

      final parts = content['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;

      final text = parts[0]['text'] as String?;
      return text?.trim();
    } catch (e) {
      return null;
    }
  }

  /// List available models (for debugging)
  Future<List<String>> listAvailableModels() async {
    try {
      final url = '$_baseUrl/models?key=$apiKey';
      debugPrint('Fetching available models from: $url');
      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout');
            },
          );

      debugPrint('ListModels response status: ${response.statusCode}');
      debugPrint('ListModels response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final models = jsonResponse['models'] as List?;
        if (models != null) {
          final modelList = models
              .map((m) {
                final name = m['name'] as String? ?? '';
                final supportedMethods =
                    m['supportedGenerationMethods'] as List?;
                final supportsGenerateContent =
                    supportedMethods?.contains('generateContent') ?? false;
                debugPrint(
                  'Model: $name, supports generateContent: $supportsGenerateContent',
                );
                return name;
              })
              .where((name) => name.isNotEmpty)
              .toList();
          debugPrint('Found ${modelList.length} available models');
          return modelList;
        }
      } else {
        debugPrint(
          'Error listing models: ${response.statusCode} - ${response.body}',
        );
      }
      return [];
    } catch (e) {
      debugPrint('Error listing models: $e');
      return [];
    }
  }

  /// Test API connection
  Future<bool> testConnection() async {
    try {
      final result = await rewriteText('Test', style: 'professional');
      return result.success;
    } catch (e) {
      return false;
    }
  }
}
