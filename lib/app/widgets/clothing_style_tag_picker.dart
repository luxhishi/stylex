import 'package:flutter/material.dart';
import '../models/clothing_style_tags.dart';

class ClothingStyleTagPicker extends StatelessWidget {
  const ClothingStyleTagPicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<String> selected;
  final ValueChanged<List<String>>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Clothing style', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Select all that fit. These help match pieces into outfits.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: ClothingStyleTags.options.map((tag) {
            final active = selected.contains(tag);
            return FilterChip(
              label: Text(tag),
              selected: active,
              backgroundColor: scheme.surfaceContainerLow,
              selectedColor: scheme.primaryContainer,
              checkmarkColor: scheme.onPrimaryContainer,
              labelStyle: TextStyle(
                color: active ? scheme.onPrimaryContainer : scheme.onSurface,
              ),
              onSelected: onChanged == null
                  ? null
                  : (value) {
                      onChanged!(
                        ClothingStyleTags.normalize(
                          value
                              ? [...selected, tag]
                              : selected.where((t) => t != tag),
                        ),
                      );
                    },
            );
          }).toList(),
        ),
      ],
    );
  }
}
