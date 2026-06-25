import 'dastrass_api.dart';
import 'blocked_phones_store.dart';

/// Жалобы и блокировки UGC (App Store Guideline 1.2).
class ModerationService {
  ModerationService._();
  static final ModerationService instance = ModerationService._();

  final _store = BlockedPhonesStore.instance;

  Future<void> ensureLoaded() => _store.ensureLoaded();

  Future<void> syncFromServer() async {
    try {
      final phones = await DastrassApi.instance.fetchBlockedPhones();
      await _store.replaceAll(phones);
    } catch (_) {}
  }

  bool isPhoneBlocked(String? phone) => _store.isPhoneBlocked(phone);

  List<Map<String, dynamic>> filterAds(Iterable<dynamic> ads) => _store.filterAds(ads);

  Future<void> blockPhoneLocally(String phone) => _store.add(phone);

  Future<void> blockUserOnServer({
    required String phone,
    String? adId,
    String reason = 'abusive',
    String details = '',
  }) async {
    await DastrassApi.instance.blockUser(
      phone: phone,
      adId: adId,
      reason: reason,
      details: details,
    );
    await _store.add(phone);
  }

  Future<void> reportContent({
    required String targetType,
    required String targetId,
    required String reason,
    String reportedPhone = '',
    String details = '',
  }) async {
    await DastrassApi.instance.reportContent(
      targetType: targetType,
      targetId: targetId,
      reason: reason,
      reportedPhone: reportedPhone,
      details: details,
    );
  }
}
