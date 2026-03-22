import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/action_result.dart';

class StylePreferenceViewModel extends ChangeNotifier {
  StylePreferenceViewModel({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  bool _isSaving = false;

  bool get isSaving => _isSaving;

  Future<ActionResult> savePreference(String styleName) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const ActionResult(
        success: false,
        message: 'No signed-in user was found.',
      );
    }

    _setSaving(true);

    try {
      await _supabase.from('users').update({
        'primary_style_slug': _toSlug(styleName),
        'onboarding_completed': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', user.id);

      return const ActionResult(
        success: true,
        message: 'Style preference saved.',
      );
    } on PostgrestException catch (error) {
      return ActionResult(
        success: false,
        message: 'Could not save your style preference: ${error.message}',
      );
    } catch (error) {
      return ActionResult(
        success: false,
        message: 'Something went wrong: $error',
      );
    } finally {
      _setSaving(false);
    }
  }

  void _setSaving(bool value) {
    if (_isSaving == value) return;
    _isSaving = value;
    notifyListeners();
  }

  String _toSlug(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
