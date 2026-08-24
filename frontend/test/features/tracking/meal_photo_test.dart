import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/core/config/app_config.dart';
import 'package:kalonet_frontend/core/network/api_client.dart';
import 'package:kalonet_frontend/features/tracking/meal_photo.dart';
import 'package:kalonet_frontend/features/tracking/presentation/meal_photo_review_page.dart';
import 'package:kalonet_frontend/features/tracking/tracking_api.dart';

void main() {
  test('AI response preserves multiple editable food proposals', () {
    final analysis = MealPhotoAnalysisModel.fromJson(_analysisJson);

    expect(analysis.items, hasLength(2));
    expect(analysis.items.first.name, 'Rice');
    expect(analysis.items.first.estimatedGrams, 180);
    expect(analysis.items.last.nutrition.proteinG, 37);
  });

  test('AI upload uses the protected multipart route', () async {
    final adapter = _Adapter(_analysisJson);
    final api = TrackingApi(client: _client(adapter));

    final analysis = await api.analyzeMealPhoto(
      bytes: <int>[0xFF, 0xD8, 0xFF, 0x01],
      filename: 'meal.jpg',
      mimeType: 'image/jpeg',
    );

    expect(adapter.method, 'POST');
    expect(adapter.uri?.path, '/api/v1/ai/meal-photo-analyses');
    expect(adapter.headers?['content-type'], contains('multipart/form-data'));
    expect(adapter.receiveTimeout, const Duration(seconds: 45));
    expect(analysis.items.first.name, 'Rice');
  });

  testWidgets('AI review renders editable controls before saving', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MealPhotoReviewPage(
          analysis: MealPhotoAnalysisModel.fromJson(_analysisJson),
        ),
      ),
    );

    expect(find.text('Review AI meal estimate'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(find.text('Use reviewed foods'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(12));
  });
}

ApiClient _client(_Adapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1/'))
    ..httpClientAdapter = adapter;
  return ApiClient(
    config: const AppConfig(apiBaseUrl: 'http://test/api/v1'),
    dio: dio,
  );
}

final class _Adapter implements HttpClientAdapter {
  _Adapter(this.response);

  final Map<String, dynamic> response;
  String? method;
  Uri? uri;
  Map<String, dynamic>? headers;
  Duration? receiveTimeout;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    method = options.method;
    uri = options.uri;
    receiveTimeout = options.receiveTimeout;
    headers = options.headers.map(
      (key, value) => MapEntry(key.toLowerCase(), '$value'),
    );
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final _analysisJson = <String, dynamic>{
  'items': [
    {
      'name': 'Rice',
      'estimated_grams': 180,
      'confidence': 0.86,
      'nutrition': {
        'calories_kcal': 234,
        'protein_g': 4.3,
        'carbohydrate_g': 51,
        'fat_g': 0.5,
      },
    },
    {
      'name': 'Chicken',
      'estimated_grams': 120,
      'confidence': 0.78,
      'nutrition': {
        'calories_kcal': 198,
        'protein_g': 37,
        'carbohydrate_g': 0,
        'fat_g': 4.3,
      },
    },
  ],
  'overall_confidence': 0.82,
  'disclaimer': 'Review before saving.',
};
