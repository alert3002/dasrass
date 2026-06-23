// Дарахти категория / подкатегория — мисли frontend categoryTree.js ва AdsBoard.jsx.

Map<String, dynamic>? categoryFindNodeBySlug(List<dynamic>? nodes, String slug) {
  if (slug.isEmpty || nodes == null) return null;
  for (final raw in nodes) {
    final n = raw as Map<String, dynamic>;
    if ('${n['slug']}' == slug) return n;
    final hit = categoryFindNodeBySlug(n['children'] as List<dynamic>?, slug);
    if (hit != null) return hit;
  }
  return null;
}

List<Map<String, dynamic>> categoryFindPathBySlug(List<dynamic>? nodes, String slug) {
  return _findPath(nodes, slug, const []);
}

List<Map<String, dynamic>> _findPath(
  List<dynamic>? nodes,
  String slug,
  List<Map<String, dynamic>> path,
) {
  for (final raw in nodes ?? const []) {
    final n = Map<String, dynamic>.from(raw as Map);
    final next = [...path, n];
    if ('${n['slug']}' == slug) return next;
    final inChildren = _findPath(n['children'] as List<dynamic>?, slug, next);
    if (inChildren.isNotEmpty) return inChildren;
  }
  return const [];
}

bool categoryNodeContainsSlug(Map<String, dynamic>? node, String slug) {
  if (slug.isEmpty || node == null) return false;
  if ('${node['slug']}' == slug) return true;
  final kids = node['children'] as List<dynamic>? ?? const [];
  for (final raw in kids) {
    if (categoryNodeContainsSlug(raw as Map<String, dynamic>, slug)) return true;
  }
  return false;
}

bool categoryHasPositiveCountInTree(Map<String, dynamic>? node) {
  if (node == null) return false;
  final count = node['ads_count'];
  if (count is! num) return true;
  if (count > 0) return true;
  final kids = node['children'] as List<dynamic>? ?? const [];
  for (final raw in kids) {
    if (categoryHasPositiveCountInTree(raw as Map<String, dynamic>)) return true;
  }
  return false;
}

List<dynamic> categoryGetChildrenForPath(List<dynamic>? rootNodes, List<String> slugPath) {
  var nodes = rootNodes ?? const <dynamic>[];
  for (final slug in slugPath) {
    if (slug.isEmpty) return const [];
    Map<String, dynamic>? found;
    for (final raw in nodes) {
      final m = raw as Map<String, dynamic>;
      if ('${m['slug']}' == slug) {
        found = m;
        break;
      }
    }
    if (found == null) return const [];
    nodes = found['children'] as List<dynamic>? ?? const [];
  }
  return nodes;
}

bool categoryIsLeafSlug(List<dynamic>? rootNodes, String slug) {
  final node = categoryFindNodeBySlug(rootNodes, slug);
  if (node == null) return false;
  final kids = node['children'] as List<dynamic>? ?? const [];
  return kids.isEmpty;
}
