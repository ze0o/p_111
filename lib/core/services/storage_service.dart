import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

/// Uploads images to Firebase Storage and returns their download URLs.
class StorageService {
  StorageService._();

  /// Uploads [files] under [folder] (for example `vehicle_images`) and returns
  /// the download URL of each file, in the same order.
  ///
  /// [filePrefix] is prepended to every generated file name.
  static Future<List<String>> uploadImages(
    List<File> files, {
    required String folder,
    String filePrefix = 'image',
  }) async {
    final urls = <String>[];
    final batchId = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < files.length; i++) {
      final ref = FirebaseStorage.instance
          .ref()
          .child(folder)
          .child('${filePrefix}_${batchId}_$i.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');

      final UploadTask task =
          kIsWeb
              ? ref.putData(await files[i].readAsBytes(), metadata)
              : ref.putFile(files[i], metadata);

      task.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes == 0) return;
        final progress = snapshot.bytesTransferred / snapshot.totalBytes * 100;
        debugPrint('Upload $folder/$i: ${progress.toStringAsFixed(0)}%');
      });

      await task;
      urls.add(await ref.getDownloadURL());
    }

    return urls;
  }
}
