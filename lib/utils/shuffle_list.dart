import 'dart:math';

/// Случайный порядок элементов (новый список при каждом вызове).
List<T> shuffleList<T>(List<T> items, [Random? random]) {
  final rng = random ?? Random();
  final out = List<T>.from(items);
  for (var i = out.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final tmp = out[i];
    out[i] = out[j];
    out[j] = tmp;
  }
  return out;
}
