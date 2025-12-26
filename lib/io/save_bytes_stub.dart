// Fallback if neither web nor io implementation is selected.
Future<void> saveBytes(String suggestedName, List<int> bytes, String mimeType) async {
  throw UnsupportedError('saveBytes not implemented for this platform');
}
