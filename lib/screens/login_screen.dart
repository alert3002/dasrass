import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../services/dastrass_api.dart';
import '../services/moderation_service.dart';
import '../utils/network_error_message.dart';
import '../theme/app_theme.dart';
import '../widgets/dastrass_app_drawer.dart';
import '../widgets/dastrass_home_app_bar.dart';
import '../widgets/drawer_scaffold_scope.dart';

/// Формат 9 цифр без +992 → «92 720 30 02» (мисли [Login.jsx]).
String _formatTjMobileLocal(String digits) {
  final d = digits.replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty) return '';
  final sb = StringBuffer(d.substring(0, min(2, d.length)));
  if (d.length > 2) {
    sb.write(' ');
    sb.write(d.substring(2, min(5, d.length)));
  }
  if (d.length > 5) {
    sb.write(' ');
    sb.write(d.substring(5, min(7, d.length)));
  }
  if (d.length > 7) {
    sb.write(' ');
    sb.write(d.substring(7, min(9, d.length)));
  }
  return sb.toString();
}

/// Маскаи намоиш: танҳо 9 рақам, формати «92 123 45 67».
class _TjPhoneDisplayFormatter extends TextInputFormatter {
  const _TjPhoneDisplayFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 9 ? digits.substring(0, 9) : digits;
    final formatted = _formatTjMobileLocal(limited);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// +992 ҳамеша намоён — берун аз TextField (prefixText танҳо дар фокус).
class _TjPhoneField extends StatefulWidget {
  const _TjPhoneField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  State<_TjPhoneField> createState() => _TjPhoneFieldState();
}

class _TjPhoneFieldState extends State<_TjPhoneField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focusNode.removeListener(_onFocus);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark ? const Color(0x14FFFFFF) : const Color(0xFFF0F2FA);
    final borderColor = _focusNode.hasFocus
        ? AppColors.primary
        : (isDark ? const Color(0x24FFFFFF) : Colors.black.withValues(alpha: 0.1));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: _focusNode.hasFocus ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
            child: Text(
              '+992',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              focusNode: _focusNode,
              controller: widget.controller,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumber],
              maxLength: 12,
              inputFormatters: const [_TjPhoneDisplayFormatter()],
              style: theme.textTheme.bodyLarge,
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.fromLTRB(0, 16, 16, 16),
                counterText: '',
              ),
              onChanged: widget.onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.redirectTo});

  final String? redirectTo;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  var _step = 0;
  final _phoneCtrl = TextEditingController();
  final _code = TextEditingController();
  var _agree = false;
  var _loading = false;
  String? _error;
  var _cooldown = 0;
  bool _linkTapsBound = false;

  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  String get _digits {
    final d = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    return d.length > 9 ? d.substring(0, 9) : d;
  }

  bool get _canSendCode => _digits.length == 9 && _agree;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer();
    _privacyTap = TapGestureRecognizer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_linkTapsBound) return;
    _linkTapsBound = true;
    _termsTap.onTap = () => context.push('/terms');
    _privacyTap.onTap = () => context.push('/privacy');
  }

  Future<void> _sendOtp() async {
    if (!_canSendCode) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await DastrassApi.instance.requestOtp(_digits, _agree);
      setState(() {
        _step = 1;
        _cooldown = int.tryParse('${data['retry_after'] ?? 60}') ?? 60;
      });
      _tickCooldown();
    } catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _tickCooldown() {
    if (_cooldown <= 0) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _cooldown = (_cooldown - 1).clamp(0, 999));
      if (_cooldown > 0) _tickCooldown();
    });
  }

  Future<void> _resendOtp() async {
    if (_loading || _cooldown > 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await DastrassApi.instance.requestOtp(_digits, true);
      setState(() => _cooldown = int.tryParse('${data['retry_after'] ?? 60}') ?? 60);
      _tickCooldown();
    } catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await DastrassApi.instance.verifyOtp(_digits, _code.text.trim());
      final token = '${data['token'] ?? ''}';
      if (token.isEmpty) throw Exception('Нет токена в ответе');
      await AuthService.instance.setToken(token);
      unawaited(ModerationService.instance.syncFromServer());
      if (!mounted) return;
      final r = widget.redirectTo;
      if (r != null && r.isNotEmpty) {
        context.go(r);
      } else {
        context.go('/home');
      }
    } catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _leaveLogin() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    _phoneCtrl.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.hintColor;
    final light = theme.brightness == Brightness.light;
    final errBg = light ? const Color(0xFFF8D7DA) : Colors.red.withValues(alpha: 0.15);
    final errFg = light ? const Color(0xFF721C24) : const Color(0xFFFFB4B4);
    final linkStyle = TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.w600,
      fontSize: 14,
      height: 1.4,
    );
    final bodyStyle = TextStyle(
      color: muted,
      fontSize: 14,
      height: 1.4,
    );

    return DrawerScaffoldScope(
      scaffoldKey: _scaffoldKey,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const DastrassAppDrawer(),
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(DastrassHomeAppBar.heightFor(showSearchRow: false, closeOnly: true)),
          child: DastrassHomeAppBar(
            scaffoldKey: _scaffoldKey,
            onCloseInsteadOfMenu: _leaveLogin,
            showSearchRow: false,
          ),
        ),
        extendBody: true,
        body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              Text(
                'Вход / Регистрация',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Вход по номеру телефона через SMS-код',
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: errBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_error!, style: TextStyle(color: errFg, height: 1.35)),
                ),
              if (_step == 0) ...[
                Text(
                  'Номер телефона *',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                _TjPhoneField(
                  controller: _phoneCtrl,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _agree,
                          onChanged: (v) => setState(() => _agree = v ?? false),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: bodyStyle,
                          children: [
                            const TextSpan(
                              text:
                                  'Авторизуясь на сайте, вы подтверждаете, что принимаете условия ',
                            ),
                            TextSpan(
                              text: 'Пользовательского соглашения',
                              style: linkStyle,
                              recognizer: _termsTap,
                            ),
                            const TextSpan(text: ' и '),
                            TextSpan(
                              text: 'Политики конфиденциальности',
                              style: linkStyle,
                              recognizer: _privacyTap,
                            ),
                            const TextSpan(
                              text:
                                  ', подтверждаете, что вам исполнилось 18 лет, и соглашаетесь с нулевой терпимостью к оскорбительному и незаконному контенту.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: (_loading || !_canSendCode) ? null : _sendOtp,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_loading ? 'Отправка…' : 'Отправить код'),
                  ),
                ),
              ] else ...[
                Text(
                  'Код подтверждения *',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    hintText: '4 цифры',
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    style: theme.textTheme.bodySmall?.copyWith(color: muted, height: 1.35),
                    children: [
                      const TextSpan(text: 'Код отправлен на номер: '),
                      TextSpan(
                        text: '+992 ${_formatTjMobileLocal(_digits)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: (_loading || _code.text.replaceAll(RegExp(r'\D'), '').length != 4)
                        ? null
                        : _verify,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_loading ? 'Проверка…' : 'Подтвердить'),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() {
                                  _step = 0;
                                  _code.clear();
                                  _error = null;
                                }),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Изменить номер'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: (_loading || _cooldown > 0) ? null : _resendOtp,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _cooldown > 0 ? 'Отправить ещё раз через $_cooldown сек' : 'Отправить ещё раз',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }
}
