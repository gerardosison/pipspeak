import 'dart:convert';

import 'package:flutter/painting.dart';

import 'profile_photo_stub.dart' if (dart.library.io) 'profile_photo_io.dart';

/// Small photos are stored in SQLite as data URIs, usable offline in browsers.
/// Native file paths from older installations remain readable on that device.
ImageProvider<Object>? profilePhoto(String? source) {
  if (source == null || source.isEmpty) return null;
  if (source.startsWith('data:image/')) {
    try {
      final data = Uri.parse(source).data;
      if (data == null || data.contentAsBytes().length > 1024 * 1024) {
        return null;
      }
      return MemoryImage(data.contentAsBytes());
    } on FormatException {
      return null;
    }
  }
  return nativeProfilePhoto(source);
}

String encodeProfilePhoto(List<int> bytes) {
  if (bytes.length > 1024 * 1024) {
    throw ArgumentError('Choose a profile photo smaller than 1 MB.');
  }
  return 'data:image/jpeg;base64,${base64Encode(bytes)}';
}
