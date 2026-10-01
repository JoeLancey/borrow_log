import 'csv_download_stub.dart'
    if (dart.library.html) 'csv_download_web.dart' as impl;

/// Cross-platform download helper.
/// - On web: triggers a browser download.
/// - On native: throws [UnsupportedError].
Future<void> downloadCsv(String filename, String csv) {
  return impl.downloadCsv(filename, csv);
}