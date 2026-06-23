import 'package:flutter/material.dart';

/// Fallback-иконки категорий (мисли frontend/src/utils/categoryIcons.js).
const _slugIcons = <String, IconData>{
  'transport': Icons.directions_car_rounded,
  'gruzoviki-avtobusy': Icons.local_shipping_rounded,
  'gruzoviki': Icons.local_shipping_rounded,
  'avtomobili-avtodoma-i-mototehnika': Icons.directions_car_rounded,
  'avtomobili': Icons.directions_car_rounded,
  'mototehnika': Icons.two_wheeler_rounded,
  'vodnyy-transport': Icons.directions_boat_rounded,
  'nedvizhimsot': Icons.apartment_rounded,
  'nedvizhimost': Icons.apartment_rounded,
  'elektronika': Icons.smartphone_rounded,
  'rabota': Icons.work_outline_rounded,
  'vse-dlya-doma': Icons.chair_rounded,
  'odezhda-i-veshi': Icons.checkroom_rounded,
  'detskij-mir': Icons.child_care_rounded,
  'zhivotnye-i-rasteniya': Icons.pets_rounded,
  'hobbi-muzyka-i-sport': Icons.sports_soccer_rounded,
  'uslugi': Icons.handshake_outlined,
  'stritelstvo': Icons.construction_rounded,
  'vse-dlya-biznes': Icons.storefront_rounded,
  'otdam-darom': Icons.card_giftcard_rounded,
  'oborudovanie-zapchasti-uslugi': Icons.build_circle_outlined,
  'zapchasti': Icons.settings_rounded,
  'shiny-i-diski': Icons.album_rounded,
  'uslugi-arenda': Icons.key_rounded,
  'arenda': Icons.key_rounded,
  'kompanii': Icons.business_rounded,
};

IconData categoryIconForSlug(String? slug) {
  final s = (slug ?? '').trim().toLowerCase();
  if (s.isEmpty) return Icons.folder_rounded;
  return _slugIcons[s] ?? Icons.folder_rounded;
}
