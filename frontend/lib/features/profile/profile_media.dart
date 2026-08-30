import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

abstract interface class ProfileImagePicker {
  Future<XFile?> pick(ImageSource source);
}

final profileImagePickerProvider = Provider<ProfileImagePicker>((ref) {
  return ImagePickerProfileImagePicker();
});

final class ImagePickerProfileImagePicker implements ProfileImagePicker {
  ImagePickerProfileImagePicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<XFile?> pick(ImageSource source) {
    return _picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
      requestFullMetadata: false,
    );
  }
}
