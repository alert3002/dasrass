import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'dastrass_header_home_style.dart';
import 'dastrass_header_icons.dart';

/// Ҷустӯҷӯи сар: ≥3 ҳарф → `/home?q=…`, натиҷаҳо дар саҳифаи асосӣ (шабакаи карточкаҳо).
class DastrassHeaderSearch extends StatefulWidget {
  const DastrassHeaderSearch({
    super.key,
    required this.controller,
    this.beforeNavigate,
    this.homeStyle = false,
  });

  final TextEditingController controller;
  final VoidCallback? beforeNavigate;
  /// Макет мисли сайт: фон #e9e9e9, лупа outline.
  final bool homeStyle;

  @override
  State<DastrassHeaderSearch> createState() => _DastrassHeaderSearchState();
}

class _DastrassHeaderSearchState extends State<DastrassHeaderSearch> {
  final _targetKey = GlobalKey();
  final _focusNode = FocusNode();
  Timer? _debounce;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_focusNode.hasFocus) return;
    final q = GoRouterState.of(context).uri.queryParameters['q'] ?? '';
    if (widget.controller.text != q) {
      widget.controller.text = q;
    }
  }

  void _onFocusChange() {
    final next = _focusNode.hasFocus;
    if (_focused != next && mounted) {
      setState(() => _focused = next);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _syncHomeQuery(String raw) {
    final q = raw.trim();
    final current = GoRouterState.of(context).uri.queryParameters['q']?.trim() ?? '';
    if (q.length < 3) {
      if (current.isNotEmpty) context.replace('/home');
      return;
    }
    if (q == current) return;
    context.replace(Uri(path: '/home', queryParameters: {'q': q}).toString());
  }

  void _scheduleSearch(String raw) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      _syncHomeQuery(widget.controller.text);
    });
  }

  void _submit() {
    final q = widget.controller.text.trim();
    widget.beforeNavigate?.call();
    if (q.isEmpty) {
      context.go('/home');
      return;
    }
    context.go(Uri(path: '/home', queryParameters: {'q': q}).toString());
  }

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final useHome = widget.homeStyle;

    final Color fillColor;
    final Color borderColor;
    final Color textColor;
    final Color hintColor;
    final Color searchIconColor;

    if (useHome && light) {
      fillColor = _focused ? DastrassHeaderHomeStyle.searchBgFocused : DastrassHeaderHomeStyle.searchBg;
      borderColor = Colors.transparent;
      textColor = DastrassHeaderHomeStyle.searchText;
      hintColor = DastrassHeaderHomeStyle.searchPlaceholder;
      searchIconColor = DastrassHeaderHomeStyle.iconInk;
    } else if (useHome) {
      fillColor = _focused ? const Color(0xFF30384D) : const Color(0xFF252B3D);
      borderColor = Colors.transparent;
      textColor = Colors.white;
      hintColor = Colors.white.withValues(alpha: 0.45);
      searchIconColor = Colors.white.withValues(alpha: 0.88);
    } else {
      fillColor = light ? Colors.white : const Color(0xFF1A2035);
      borderColor = light ? const Color(0xFFD1D9E6) : Colors.white.withValues(alpha: 0.22);
      textColor = light ? const Color(0xFF1A1F36) : Colors.white;
      hintColor = light ? const Color(0x730F172A) : Colors.white.withValues(alpha: 0.45);
      searchIconColor = light ? Colors.white : Colors.white.withValues(alpha: 0.9);
    }

    return SizedBox(
      key: _targetKey,
      height: useHome ? DastrassHeaderHomeStyle.searchHeight : 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(useHome ? DastrassHeaderHomeStyle.searchRadius : 12),
          border: Border.all(color: borderColor, width: useHome ? 0 : 1),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            useHome ? DastrassHeaderHomeStyle.searchPadLeft : 12,
            0,
            useHome ? DastrassHeaderHomeStyle.searchPadRight : (light ? 3 : 8),
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    textAlignVertical: TextAlignVertical.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: useHome ? DastrassHeaderHomeStyle.searchFontSize : 14,
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Colors.transparent,
                      hintText: 'Поиск...',
                      hintStyle: TextStyle(
                        color: hintColor,
                        fontWeight: FontWeight.w400,
                        fontSize: useHome ? DastrassHeaderHomeStyle.searchFontSize : 14,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    maxLines: 1,
                    textInputAction: TextInputAction.search,
                    onChanged: _scheduleSearch,
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ),
              if (useHome) const SizedBox(width: DastrassHeaderHomeStyle.searchInnerGap),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _submit,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: useHome ? DastrassHeaderHomeStyle.searchBtnSize : 32,
                    height: useHome ? DastrassHeaderHomeStyle.searchBtnSize : 32,
                    child: useHome
                        ? Center(
                            child: DastrassHeaderSearchIcon(
                              color: searchIconColor,
                              size: DastrassHeaderHomeStyle.searchIconSize,
                            ),
                          )
                        : Icon(
                            Icons.search_rounded,
                            color: searchIconColor,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
