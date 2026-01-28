import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'logger_service.dart';

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  String? _apiKey;
  GenerativeModel? _embeddingModel;

  void _init() {
    _apiKey = dotenv.env['GEMINI_API_KEY'];
    if (_apiKey == null || _apiKey!.isEmpty) {
      logger.warning(
          "⚠️ GEMINI_API_KEY is missing. AI features will be disabled.");
      return;
    }
    // Try the latest first
    _embeddingModel = GenerativeModel(
      model: 'text-embedding-004',
      apiKey: _apiKey!,
    );
  }

  /// Generate a vector embedding for the given text.
  /// Returns a list of 768 doubles.
  Future<List<double>?> generateEmbedding(String text) async {
    if (_embeddingModel == null) _init();

    if (_embeddingModel == null || _apiKey == null) {
      logger.error("Cannot generate embedding: AI Service not initialized.");
      return null;
    }

    try {
      final content = Content.text(text);
      final result = await _embeddingModel!.embedContent(content);
      return result.embedding.values;
    } catch (e) {
      logger.warning(
          "⚠️ 'text-embedding-004' failed ($e). Retrying with 'embedding-001'...");
      try {
        // Fallback to older stable model (Gecko) which is also 768 dims
        final fallbackModel = GenerativeModel(
          model: 'gemini-embedding-001',
          apiKey: _apiKey!,
        );
        final result = await fallbackModel.embedContent(Content.text(text));

        var values = result.embedding.values;
        if (values.length > 768) {
          logger
              .info("⚠️ Slicing embedding from ${values.length} to 768 dims.");
          values = values.take(768).toList();
        }

        logger.info("✅ Fallback to 'gemini-embedding-001' successful.");
        return values;
      } catch (e2) {
        logger.error("❌ All embedding attempts failed.", error: e2);
        return null;
      }
    }
  }
}

final aiService = AiService();
