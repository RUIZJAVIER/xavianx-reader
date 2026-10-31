import 'dart:io';
import 'dart:typed_data';

import 'package:anx_reader/service/md5_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculateFileMd5 hashes large files in chunks', () async {
    final dir = await Directory.systemTemp.createTemp('anx_md5_');
    final file = File('${dir.path}/book.bin');
    final bytes = Uint8List(3 * 1024 * 1024);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = i & 0xff;
    }
    await file.writeAsBytes(bytes);

    expect(
      await MD5Service.calculateFileMd5(file.path),
      md5.convert(bytes).toString(),
    );

    await dir.delete(recursive: true);
  });
}
