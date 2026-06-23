import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../services/dastrass_api.dart';
import '../utils/network_error_message.dart';
import '../theme/app_theme.dart';
import '../utils/subscription_filters.dart';

/// Фосилаи болои поёни body (таб-бар аллакай дар [DastrassOuterTabShell] берун аст).
const kFilterSubscribeBottomGap = 4.0;

/// Баландии тугмаи «Подписаться» — мисли `.filter-subscribe-fab` дар сайт.
const kFilterSubscribeFabHeight = 40.0;

/// Забо padding-и поёни рӯйхат (баландии тугма + фосила).
double filterSubscribeBarBottomInset(BuildContext context) => kFilterSubscribeBottomGap;

/// Кнопка «Подписаться» — мисли [FilterSubscribeFab.jsx] / `.filter-subscribe-fab`.
class FilterSubscribeFab extends StatefulWidget {
  const FilterSubscribeFab({
    super.key,
    required this.filters,
    this.onVisibilityChanged,
  });

  final Map<String, String> filters;
  final ValueChanged<bool>? onVisibilityChanged;

  @override
  State<FilterSubscribeFab> createState() => _FilterSubscribeFabState();
}

class _FilterSubscribeFabState extends State<FilterSubscribeFab> {
  bool _loading = false;
  bool _subscribed = false;
  bool _checking = false;

  static const _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF005BFE), Color(0xFF0046C8)],
  );

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_onAuth);
    _refreshSubscribed();
  }

  @override
  void didUpdateWidget(covariant FilterSubscribeFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filters != widget.filters) _refreshSubscribed();
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuth);
    super.dispose();
  }

  void _onAuth() {
    if (mounted) _refreshSubscribed();
  }

  void _notifyVisibility() {
    final visible = canSubscribeToFilters(widget.filters) && !_subscribed;
    widget.onVisibilityChanged?.call(visible);
  }

  Future<void> _refreshSubscribed() async {
    if (!AuthService.instance.isAuthenticated || !canSubscribeToFilters(widget.filters)) {
      if (mounted) {
        setState(() => _subscribed = false);
        _notifyVisibility();
      }
      return;
    }
    setState(() => _checking = true);
    try {
      final list = await DastrassApi.instance.filterSubscriptions();
      if (!mounted) return;
      setState(() {
        _subscribed = isSubscribedToFilters(list, widget.filters);
      });
      _notifyVisibility();
    } catch (_) {
      if (mounted) {
        setState(() => _subscribed = false);
        _notifyVisibility();
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _subscribe() async {
    if (!AuthService.instance.isAuthenticated) {
      final from = Uri(path: '/ads', queryParameters: widget.filters).toString();
      if (mounted) context.push('/login?from=${Uri.encodeComponent(from)}');
      return;
    }
    final payload = filtersToSubscriptionPayload(widget.filters);
    if (payload['category'] == null) {
      _toast('Выберите категорию');
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await DastrassApi.instance.createFilterSubscription(payload);
      final already = data['already_exists'] == true;
      if (mounted) {
        setState(() => _subscribed = true);
        _notifyVisibility();
      }
      if (!already) {
        _toast('Подписка оформлена. Смотрите раздел «Уведомления»');
      }
    } catch (e) {
      _toast(friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (!canSubscribeToFilters(widget.filters)) return const SizedBox.shrink();

    if (_subscribed) return const SizedBox.shrink();

    final label = _loading
        ? 'Подписка…'
        : _checking
            ? '…'
            : 'Подписаться';

    return Positioned(
      right: 12,
      bottom: filterSubscribeBarBottomInset(context),
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: InkWell(
          onTap: (_loading || _checking) ? null : _subscribe,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            height: kFilterSubscribeFabHeight,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: _gradient,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.32),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_loading)
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                else
                  const Icon(Icons.notifications_outlined, color: Colors.white, size: 15),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
