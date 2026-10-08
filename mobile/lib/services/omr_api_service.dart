import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/omr_result.dart';

class OmrApiException implements Exception {
  const OmrApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class OmrApiService {
  OmrApiService({String? baseUrl})
    : baseUrl = _normalizeBaseUrl(
        baseUrl ?? const String.fromEnvironment('OMR_API_URL'),
      );

  static const _androidUsbReverseUrl = 'http://127.0.0.1:8000';
  static const _androidEmulatorUrl = 'http://10.0.2.2:8000';
  static const _localUrl = 'http://127.0.0.1:8000';

  static String _normalizeBaseUrl(String value) {
    return value.trim().replaceFirst(RegExp(r'/$'), '');
  }

  List<String> get _candidateBaseUrls {
    if (baseUrl.isNotEmpty) return [baseUrl];
    if (Platform.isAndroid) {
      return const [_androidUsbReverseUrl, _androidEmulatorUrl];
    }
    return const [_localUrl];
  }

  final String baseUrl;

  Future<OmrResult> processImage({
    required String imagePath,
    required String imageName,
  }) async {
    final attemptedUrls = <String>[];
    Object? lastNetworkError;

    for (final candidateBaseUrl in _candidateBaseUrls) {
      attemptedUrls.add(candidateBaseUrl);
      final uri = Uri.parse('$candidateBaseUrl/api/v1/omr/process');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Accept'] = 'application/json'
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            imagePath,
            filename: imageName,
          ),
        );

      try {
        final streamed = await request.send().timeout(
          const Duration(seconds: 60),
        );
        final response = await http.Response.fromStream(streamed);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          String message = 'OMR processing failed (${response.statusCode}).';
          try {
            final body = jsonDecode(response.body);
            if (body is Map && body['detail'] != null) {
              message = body['detail'].toString();
            }
          } catch (_) {}
          throw OmrApiException(message);
        }

        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const OmrApiException('Invalid response from OMR server.');
        }

        return OmrResult.fromApiJson(
          decoded,
          imageName: imageName,
          sourceImagePath: imagePath,
        );
      } on SocketException catch (e) {
        lastNetworkError = e;
      } on TimeoutException catch (e) {
        lastNetworkError = e;
      } on http.ClientException catch (e) {
        lastNetworkError = e;
      } on FormatException {
        throw const OmrApiException('Server returned invalid JSON.');
      }
    }

    final tried = attemptedUrls.join(', ');
    final detail = lastNetworkError == null ? '' : ' ($lastNetworkError)';
    throw OmrApiException(
      'Cannot connect to OMR server. Tried: $tried. '
      'Make sure the backend is running on port 8000.$detail',
    );
  }
}
