import 'dart:convert';
import 'dart:io';

import '../models/dictionary_word_model.dart';

class DictionaryRemoteDataSourceException implements Exception {
  DictionaryRemoteDataSourceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DictionaryRemoteDataSource {
  Future<List<DictionaryWordModel>> searchWord(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const [];

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);

    try {
      final request = await client.getUrl(
        Uri.parse(
          'https://api.dictionaryapi.dev/api/v2/entries/en/${Uri.encodeComponent(normalizedQuery)}',
        ),
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == HttpStatus.notFound) {
        return const [];
      }

      if (response.statusCode != HttpStatus.ok) {
        throw DictionaryRemoteDataSourceException(
          'Free Dictionary API returned ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is! List) return const [];

      final now = DateTime.now();
      final words = <DictionaryWordModel>[];

      for (final item in decoded) {
        if (item is! Map) continue;
        final entry = Map<String, dynamic>.from(item);
        final word = (entry['word'] as String?)?.trim();
        if (word == null || word.isEmpty) continue;

        final phonetic = _extractPhonetic(entry);
        final meanings = entry['meanings'];
        if (meanings is! List) continue;

        for (final meaningItem in meanings) {
          if (meaningItem is! Map) continue;
          final meaning = Map<String, dynamic>.from(meaningItem);
          final partOfSpeech =
              (meaning['partOfSpeech'] as String?)?.trim() ?? 'unknown';
          final definitions = meaning['definitions'];
          if (definitions is! List) continue;

          for (final definitionItem in definitions) {
            if (definitionItem is! Map) continue;
            final definition = Map<String, dynamic>.from(definitionItem);
            final definitionText =
                (definition['definition'] as String?)?.trim() ?? '';
            if (definitionText.isEmpty) continue;

            words.add(
              DictionaryWordModel(
                word: word,
                phonetic: phonetic,
                partOfSpeech: partOfSpeech,
                definition: definitionText,
                example: (definition['example'] as String?)?.trim() ?? '',
                isSaved: false,
                createdAt: now,
                updatedAt: now,
              ),
            );
          }
        }
      }

      return _deduplicate(words);
    } on SocketException {
      throw DictionaryRemoteDataSourceException(
        'Unable to connect to Free Dictionary API.',
      );
    } on HttpException {
      throw DictionaryRemoteDataSourceException(
        'Unable to connect to Free Dictionary API.',
      );
    } on FormatException {
      throw DictionaryRemoteDataSourceException(
        'Free Dictionary API returned invalid data.',
      );
    } on DictionaryRemoteDataSourceException {
      rethrow;
    } catch (_) {
      throw DictionaryRemoteDataSourceException(
        'Failed to load dictionary results.',
      );
    } finally {
      client.close(force: true);
    }
  }

  String _extractPhonetic(Map<String, dynamic> entry) {
    final direct = (entry['phonetic'] as String?)?.trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final phonetics = entry['phonetics'];
    if (phonetics is! List) return '';

    for (final item in phonetics) {
      if (item is! Map) continue;
      final phonetic = (item['text'] as String?)?.trim();
      if (phonetic != null && phonetic.isNotEmpty) {
        return phonetic;
      }
    }

    return '';
  }

  List<DictionaryWordModel> _deduplicate(List<DictionaryWordModel> words) {
    final seen = <String>{};
    final deduplicated = <DictionaryWordModel>[];

    for (final word in words) {
      final key = [
        word.word.trim().toLowerCase(),
        word.partOfSpeech.trim().toLowerCase(),
        word.definition.trim().toLowerCase(),
      ].join('|');

      if (seen.add(key)) {
        deduplicated.add(word);
      }
    }

    return deduplicated;
  }
}
