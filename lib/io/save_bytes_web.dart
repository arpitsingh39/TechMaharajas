import 'dart:typed_data';
import 'dart:html' as html;

Future<void> saveBytes(String suggestedName, List<int> bytes, String mimeType) async {
  final u8 = Uint8List.fromList(bytes);
  // html.Blob accepts a List<Object?> for parts; Uint8List is fine.
  final blob = html.Blob([u8], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..download = suggestedName
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
