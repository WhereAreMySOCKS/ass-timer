abstract final class VersionUtils {
  static int compare(String left, String right) {
    final leftParts = _parts(left);
    final rightParts = _parts(right);
    final length = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;
    for (var index = 0; index < length; index += 1) {
      final leftValue = index < leftParts.length ? leftParts[index] : 0;
      final rightValue = index < rightParts.length ? rightParts[index] : 0;
      final order = leftValue.compareTo(rightValue);
      if (order != 0) return order;
    }
    return 0;
  }

  static List<int> _parts(String value) => value
      .trim()
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split('.')
      .map((part) => int.tryParse(RegExp(r'^\d+').stringMatch(part) ?? '') ?? 0)
      .toList(growable: false);
}
