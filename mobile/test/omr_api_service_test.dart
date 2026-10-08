import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/omr_api_service.dart';

void main() {
  test('OmrApiService uploads an image and parses OMR JSON', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    final requests = server.listen((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/v1/omr/process');
      expect(request.headers.contentType?.mimeType, startsWith('multipart/'));

      await request.drain<void>();

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'template_id': 'OMR-001',
            'answers': [
              {
                'question': 1,
                'answer': 'ক',
                'status': 'marked',
                'confidence_gap': 42.5,
                'scores': {'ক': 180.0, 'খ': 10.0, 'গ': 12.0, 'ঘ': 8.0},
              },
            ],
            'summary': {
              'total_questions': 1,
              'marked': 1,
              'blank': 0,
              'ambiguous': 0,
            },
          }),
        );
      await request.response.close();
    });
    addTearDown(requests.cancel);

    final tempDir = await Directory.systemTemp.createTemp('omr-api-test-');
    addTearDown(() => tempDir.delete(recursive: true));

    final imageFile = File('${tempDir.path}${Platform.pathSeparator}sheet.png');
    await imageFile.writeAsBytes([0, 1, 2, 3, 4]);

    final api = OmrApiService(
      baseUrl:
          ' http://${InternetAddress.loopbackIPv4.address}:${server.port}/ ',
    );
    final result = await api.processImage(
      imagePath: imageFile.path,
      imageName: 'sheet.png',
    );

    expect(
      api.baseUrl,
      'http://${InternetAddress.loopbackIPv4.address}:${server.port}',
    );
    expect(result.templateId, 'OMR-001');
    expect(result.answers, hasLength(1));
    expect(result.answers.single.selectedOption, 'ক');
    expect(result.summary?.marked, 1);
  });

  test('OmrApiService surfaces backend detail errors', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    final requests = server.listen((request) async {
      await request.drain<void>();
      request.response
        ..statusCode = HttpStatus.unprocessableEntity
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'detail': 'Could not find four corner markers.'}));
      await request.response.close();
    });
    addTearDown(requests.cancel);

    final tempDir = await Directory.systemTemp.createTemp('omr-api-test-');
    addTearDown(() => tempDir.delete(recursive: true));

    final imageFile = File('${tempDir.path}${Platform.pathSeparator}sheet.png');
    await imageFile.writeAsBytes([0, 1, 2, 3, 4]);

    final api = OmrApiService(
      baseUrl: 'http://${InternetAddress.loopbackIPv4.address}:${server.port}',
    );

    expect(
      () => api.processImage(imagePath: imageFile.path, imageName: 'sheet.png'),
      throwsA(
        isA<OmrApiException>().having(
          (error) => error.message,
          'message',
          'Could not find four corner markers.',
        ),
      ),
    );
  });
}
