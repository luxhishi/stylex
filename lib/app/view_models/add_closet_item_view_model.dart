import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/action_result.dart';
import '../models/closet_analysis_result.dart';
import '../services/closet_service.dart';

class AddClosetItemViewModel extends ChangeNotifier {
  AddClosetItemViewModel({ClosetService? closetService})
      : _closetService = closetService ?? ClosetService();

  final ClosetService _closetService;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  Future<ActionResult> saveItem({
    required String imagePath,
    required String source,
    required ClosetAnalysisResult analysis,
  }) async {
    _setSaving(true);

    try {
      await _closetService.addClosetItem(
        imagePath: imagePath,
        source: source,
        analysis: analysis,
      );

      return const ActionResult(
        success: true,
        message: 'Added to your closet.',
      );
    } on StorageException catch (error) {
      return ActionResult(
        success: false,
        message:
            'Image upload failed: ${error.message}. Make sure the `closet-items` storage bucket exists.',
      );
    } on AuthException catch (error) {
      return ActionResult(
        success: false,
        message: error.message,
      );
    } on PostgrestException catch (error) {
      return ActionResult(
        success: false,
        message: 'Closet save failed: ${error.message}',
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
}
