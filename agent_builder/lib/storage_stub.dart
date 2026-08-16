class ArchitectureStorage {
  static String? _draft;
  static bool? _darkMode;

  Future<void> saveDraft(String json) async => _draft = json;
  Future<String?> loadDraft() async => _draft;
  Future<void> saveDarkMode(bool enabled) async => _darkMode = enabled;
  Future<bool?> loadDarkMode() async => _darkMode;
  Future<void> downloadJson(String filename, String json) async {}
  Future<String?> pickJson() async => null;
}
