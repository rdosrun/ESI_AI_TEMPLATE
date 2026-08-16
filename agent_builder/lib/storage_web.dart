import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

class ArchitectureStorage {
  static const _draftKey = 'esi.agent-builder.draft';
  static const _darkModeKey = 'esi.agent-builder.dark-mode';

  Future<void> saveDraft(String json) async =>
      web.window.localStorage.setItem(_draftKey, json);

  Future<String?> loadDraft() async =>
      web.window.localStorage.getItem(_draftKey);

  Future<void> saveDarkMode(bool enabled) async =>
      web.window.localStorage.setItem(_darkModeKey, enabled.toString());

  Future<bool?> loadDarkMode() async {
    final value = web.window.localStorage.getItem(_darkModeKey);
    return value == null ? null : value == 'true';
  }

  Future<void> downloadJson(String filename, String json) async {
    final blob = web.Blob(
      [json.toJS].toJS,
      web.BlobPropertyBag(type: 'application/json'),
    );
    final url = web.URL.createObjectURL(blob);
    web.HTMLAnchorElement()
      ..href = url
      ..download = filename
      ..click();
    web.URL.revokeObjectURL(url);
  }

  Future<String?> pickJson() async {
    final completer = Completer<String?>();
    final picker = web.HTMLInputElement()
      ..type = 'file'
      ..accept = '.json,application/json';

    picker.addEventListener(
      'change',
      ((web.Event _) {
        final file = picker.files?.item(0);
        if (file == null) {
          completer.complete(null);
          return;
        }
        file.text().toDart.then(
          (content) => completer.complete(content.toDart),
          onError: completer.completeError,
        );
      }).toJS,
    );
    picker.click();
    return completer.future;
  }
}
