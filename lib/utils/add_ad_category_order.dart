/// Порядок категорий на шаге 1 — мисли [frontend/src/pages/AddAd.jsx] `ADD_AD_CATEGORY_ORDER`.
const kAddAdCategoryOrder = <String>[
  'transport',
  'nedvizhimsot',
  'elektronika',
  'rabota',
  'vse-dlya-doma',
  'odezhda-i-veshi',
  'detskij-mir',
  'zhivotnye-i-rasteniya',
  'hobbi-muzyka-i-sport',
  'uslugi',
  'stritelstvo',
  'vse-dlya-biznes',
  'otdam-darom',
];

List<Map<String, dynamic>> orderCategoriesForAddAd(List<dynamic> categories) {
  if (categories.isEmpty) return const [];
  final bySlug = <String, Map<String, dynamic>>{};
  for (final raw in categories) {
    final m = raw as Map<String, dynamic>;
    final slug = '${m['slug'] ?? ''}';
    if (slug.isNotEmpty) bySlug[slug] = m;
  }
  final ordered = <Map<String, dynamic>>[];
  for (final slug in kAddAdCategoryOrder) {
    final cat = bySlug[slug];
    if (cat != null) ordered.add(cat);
  }
  for (final raw in categories) {
    final m = raw as Map<String, dynamic>;
    final slug = '${m['slug'] ?? ''}';
    if (slug.isNotEmpty && !kAddAdCategoryOrder.contains(slug)) {
      ordered.add(m);
    }
  }
  return ordered;
}
