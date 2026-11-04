import 'dart:io';

import 'package:flutter/painting.dart';

ImageProvider<Object>? nativeProfilePhoto(String source) =>
    FileImage(File(source));
