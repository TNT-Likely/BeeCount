import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/custom_icon_service.dart';

final categoryIconServiceProvider =
    Provider<CustomIconService>((ref) => CustomIconService());
final categoryIconPickerProvider =
    Provider<CategoryIconPicker>((ref) => CategoryIconPicker());

/// Returns a temporary crop only. Picking/cancelling never writes category data
/// or deletes a saved icon; promotion happens in the explicit save operation.
class CategoryIconPicker {
  Future<File?> pick(BuildContext context, Color primary) async {
    final l = AppLocalizations.of(context);
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null || !context.mounted) return null;
    final crop = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 100,
        compressFormat: ImageCompressFormat.png,
        maxWidth: 512,
        maxHeight: 512,
        uiSettings: [
          AndroidUiSettings(
              toolbarTitle: l.categoryCustomIconCrop,
              toolbarColor: primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
              hideBottomControls: false),
          IOSUiSettings(
              title: l.categoryCustomIconCrop,
              aspectRatioLockEnabled: true,
              resetAspectRatioEnabled: false,
              aspectRatioPickerButtonHidden: true)
        ]);
    return crop == null ? null : File(crop.path);
  }
}
