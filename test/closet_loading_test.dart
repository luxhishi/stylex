import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stylex/app/services/closet_service.dart';

void main() {
  test(
    'signs private photos in one batch and preserves external URLs',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var signingRequests = 0;
      var failSigning = false;
      List<dynamic>? requestedPaths;
      final items = [
        {'id': 'a', 'image_url': 'user/a.jpg'},
        {'id': 'b', 'image_url': 'user/b.jpg'},
        {'id': 'c', 'image_url': 'user/a.jpg'},
        {'id': 'd', 'image_url': 'https://example.com/photo.jpg'},
      ];
      final subscription = server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        Object body;
        if (request.uri.path == '/auth/v1/token') {
          body = {
            'access_token': 'test-token',
            'refresh_token': 'test-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': 'user',
              'aud': 'authenticated',
              'email': 'test@example.com',
              'created_at': '2026-01-01T00:00:00Z',
              'app_metadata': <String, dynamic>{},
              'user_metadata': <String, dynamic>{},
            },
          };
        } else if (request.uri.path == '/rest/v1/clothing_items') {
          body = items;
        } else if (request.uri.path == '/rest/v1/clothing_ai_analyses') {
          body = [
            {
              'clothing_item_id': 'a',
              'raw_response': {
                'style_tags': ['formal', 'smart-casual'],
              },
            },
          ];
        } else if (request.uri.path == '/storage/v1/object/sign/closet-items') {
          signingRequests++;
          final payload =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
          requestedPaths = payload['paths'] as List<dynamic>;
          if (failSigning) {
            request.response.statusCode = 503;
            request.response.write(
              jsonEncode({'message': 'Storage unavailable'}),
            );
            await request.response.close();
            return;
          }
          body = requestedPaths!
              .map(
                (path) => {
                  'path': path,
                  'signedURL': '/object/sign/closet-items/$path?token=test',
                },
              )
              .toList();
        } else {
          request.response.statusCode = 404;
          body = {'message': 'Unexpected request: ${request.uri}'};
        }
        request.response.write(jsonEncode(body));
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(() async {
        await client.dispose();
        await server.close(force: true);
        await subscription.cancel();
      });

      await client.auth.signInWithPassword(
        email: 'test@example.com',
        password: 'test-password',
      );
      final result = await ClosetService(
        supabaseClient: client,
      ).fetchClosetItems();

      expect(signingRequests, 1);
      expect(requestedPaths, ['user/a.jpg', 'user/b.jpg']);
      expect(result.map((item) => item.id), ['a', 'b', 'c', 'd']);
      expect(result[0].imageUrl, contains('token=test'));
      expect(result[0].imageUrl, result[2].imageUrl);
      expect(result.last.imageUrl, 'https://example.com/photo.jpg');
      expect(result.first.styleTags, ['Formal', 'Smart Casual']);
      expect(result[1].styleTags, isEmpty);

      failSigning = true;
      final fallback = await ClosetService(
        supabaseClient: client,
      ).fetchClosetItems();
      expect(fallback.length, items.length);
      expect(fallback.first.imageUrl, contains('/object/public/closet-items/'));
      expect(fallback.last.imageUrl, 'https://example.com/photo.jpg');
    },
  );
}
