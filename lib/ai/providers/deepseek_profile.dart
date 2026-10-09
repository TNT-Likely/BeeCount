import 'package:dio/dio.dart';

import 'provider_models.dart';

/// DeepSeek's fixed endpoint and explicitly advertised input modalities.
abstract final class DeepSeekProfile {
  static const providerId = 'deepseek';
  static const baseUrl = 'https://api.deepseek.com';
  static const generationModel = 'deepseek-flash';

  static Future<ProviderModels> discover(String apiKey, {Dio? client}) async {
    final dio = client ??
        Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
        ));
    try {
      final response = await dio.get<dynamic>('$baseUrl/models',
          options: Options(headers: {'Authorization': 'Bearer $apiKey'}));
      final data = response.data;
      if (data is! Map || data['data'] is! List) {
        throw const FormatException('Invalid model list');
      }
      final text = <String>[];
      final vision = <String>[];
      for (final model in data['data'] as List) {
        if (model is! Map || model['id'] is! String) continue;
        final id = model['id'] as String;
        final modalities = model['input_modalities'];
        if (id.isEmpty || modalities is! List) continue;
        if (modalities.contains('text')) text.add(id);
        if (modalities.contains('image')) vision.add(id);
      }
      return ProviderModels(text: text, vision: vision);
    } on DioException catch (error) {
      // Never expose request options, credentials or arbitrary server bodies.
      throw ProviderModelLoadException(error.response?.statusCode == 401 ||
          error.response?.statusCode == 403);
    }
  }
}

final class ProviderModelLoadException implements Exception {
  const ProviderModelLoadException(this.unauthorized);
  final bool unauthorized;
}
