import 'auth_service.dart';
import 'dastrass_api.dart';
import 'favorites_store.dart';

/// Избранное: API барои вурудшуда, маҳаллӣ барои меҳмон.
class FavoritesService {
  FavoritesService._();

  static bool isFavoriteId(int id) {
    if (id <= 0) return false;
    if (AuthService.instance.isAuthenticated) return false;
    return FavoritesStore.instance.contains(id);
  }

  static Future<List<dynamic>> loadList() async {
    if (AuthService.instance.isAuthenticated) {
      return DastrassApi.instance.favorites();
    }
    await FavoritesStore.instance.hydrate();
    final out = <Map<String, dynamic>>[];
    for (final id in FavoritesStore.instance.ids) {
      try {
        final ad = await DastrassApi.instance.adDetail('$id');
        out.add({...ad, 'is_favorite': true});
      } catch (_) {}
    }
    return out;
  }

  static Future<Map<String, dynamic>> toggle(String id) async {
    if (AuthService.instance.isAuthenticated) {
      return DastrassApi.instance.toggleFavorite(id);
    }
    final n = int.tryParse(id) ?? 0;
    if (n <= 0) {
      return {'ok': false, 'error': 'Неверный ID'};
    }
    final isFavorite = await FavoritesStore.instance.toggle(n);
    return {'ok': true, 'is_favorite': isFavorite};
  }
}
