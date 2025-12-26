import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';

// Presents a save dialog on Android/iOS/Windows/macOS/Linux and writes raw bytes.
Future<void> saveBytes(String suggestedName, List<int> bytes, String mimeType) async {
  final u8 = Uint8List.fromList(bytes);
  await FileSaver.instance.saveFile(
    name: suggestedName,
    bytes: u8,
    fileExtension: _extFromMime(mimeType),
    mimeType: MimeType.other,
    customMimeType: mimeType,
    includeExtension: true,
  );
}

String _extFromMime(String mime) {
  if (mime.contains('spreadsheetml.sheet')) return 'xlsx';
  if (mime.contains('pdf')) return 'pdf';
  return 'bin';
}
