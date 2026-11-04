import 'package:flutter_test/flutter_test.dart';
import 'package:stylex/app/models/clothing_style_tags.dart';
import 'package:stylex/app/models/closet_item_preview.dart';
import 'package:stylex/app/services/closet_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

ClosetItemPreview piece(String id, String category, List<String> tags) =>
    ClosetItemPreview(
      id: id,
      category: category,
      styleTags: tags,
      imageUrl: '',
      source: 'gallery_upload',
      primaryColor: 'Black',
      material: '',
      title: id,
      subtitle: '',
      createdAt: null,
    );

void main() {
  test('normalizes recognized tags and removes duplicates', () {
    expect(
      ClothingStyleTags.normalize([
        'formal',
        ' Formal ',
        'smart-casual',
        'unknown',
      ]),
      ['Formal', 'Smart Casual'],
    );
  });

  test('matching tags rank above color-identical alternatives', () {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    final service = ClosetService(supabaseClient: client);
    final result = service.buildOutfitSuggestion(
      items: [
        piece('top', 'Top', ['Formal']),
        piece('a-casual', 'Bottom', ['Casual']),
        piece('z-formal', 'Bottom', ['Formal']),
        piece('shoe', 'Shoe', ['Formal']),
      ],
      includeOuterwear: false,
    );
    expect(result.map((item) => item.id), contains('z-formal'));
  });

  test('avoids formal/sporty clashes when alternatives exist', () {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    final service = ClosetService(supabaseClient: client);
    final items = [
      piece('top', 'Top', ['Formal']),
      piece('sporty', 'Bottom', ['Sporty']),
      piece('formal', 'Bottom', ['Formal']),
      piece('shoe', 'Shoe', []),
    ];
    for (var seed = 0; seed < 5; seed++) {
      expect(
        service
            .buildOutfitSuggestion(
              items: items,
              includeOuterwear: false,
              seed: seed,
            )
            .map((item) => item.id),
        isNot(contains('sporty')),
      );
    }
    final fallback = service.buildOutfitSuggestion(
      items: items.where((item) => item.id != 'formal').toList(),
      includeOuterwear: false,
    );
    expect(fallback, hasLength(3));
  });
}
