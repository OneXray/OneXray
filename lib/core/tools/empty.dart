class EmptyTool {
  static bool checkString(String? obj) => obj != null && obj.isNotEmpty;

  static bool checkList(List? obj) => obj != null && obj.isNotEmpty;

  static bool checkMap(Map? obj) => obj != null && obj.isNotEmpty;
}
