// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;

Future<void> downloadCsv(String filename, String csv) async {
  final bytes = utf8.encode(csv);
  final blob = html.Blob([bytes], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}