import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../services/dastrass_api.dart';
import '../theme/app_theme.dart';
import '../utils/locality_label.dart';
import '../utils/network_error_message.dart';

const _fuelChoices = <MapEntry<String, String>>[
  MapEntry('diesel', 'Дизель'),
  MapEntry('petrol', 'Бензин'),
  MapEntry('gas', 'Газ'),
  MapEntry('electric', 'Электро'),
];

const _transChoices = <MapEntry<String, String>>[
  MapEntry('manual', 'Механика'),
  MapEntry('automatic', 'Автомат'),
];

const _colorChoices = <MapEntry<String, String>>[
  MapEntry('white', 'Белый'),
  MapEntry('black', 'Чёрный'),
  MapEntry('silver', 'Серебристый'),
  MapEntry('grey', 'Серый'),
  MapEntry('red', 'Красный'),
  MapEntry('blue', 'Синий'),
  MapEntry('green', 'Зелёный'),
  MapEntry('yellow', 'Жёлтый'),
  MapEntry('orange', 'Оранжевый'),
  MapEntry('brown', 'Коричневый'),
  MapEntry('beige', 'Бежевый'),
  MapEntry('other', 'Другой'),
];

String _coerceFuel(String? v) {
  const ok = {'diesel', 'gas', 'petrol', 'electric'};
  if (v != null && ok.contains(v)) return v;
  return 'diesel';
}

String _coerceTransmission(String? v) {
  if (v == 'automatic') return 'automatic';
  if (v == 'manual') return 'manual';
  return 'manual';
}

String _coerceColor(String? v) {
  const codes = {'white', 'black', 'silver', 'grey', 'red', 'blue', 'green', 'yellow', 'orange', 'brown', 'beige', 'other'};
  if (v != null && v.isNotEmpty && codes.contains(v)) return v;
  return 'other';
}

/// Редактирование своего объявления — поля как у объявления + API `/ads/{id}/update/`.
class EditAdScreen extends StatefulWidget {
  const EditAdScreen({super.key, required this.adId});

  final String adId;

  @override
  State<EditAdScreen> createState() => _EditAdScreenState();
}

class _EditAdScreenState extends State<EditAdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _catDisplayCtrl = TextEditingController();
  final _subDisplayCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _mileageCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  List<Map<String, dynamic>> _localities = [];
  Map<String, dynamic>? _ad;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  String _priceType = 'fixed';
  String? _localityId;
  String _fuel = 'diesel';
  String _transmission = 'manual';
  String _color = 'other';

  @override
  void dispose() {
    _catDisplayCtrl.dispose();
    _subDisplayCtrl.dispose();
    _titleCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _mileageCtrl.dispose();
    _capacityCtrl.dispose();
    _phoneCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = DastrassApi.instance;
      final ad = await api.adDetail(widget.adId);
      List<Map<String, dynamic>> loc = [];
      try {
        loc = await api.localitiesFlat();
      } catch (_) {}
      if (!mounted) return;
      final priceNum = num.tryParse('${ad['price'] ?? 0}') ?? 0;
      final priceType = priceNum == 0 ? 'negotiable' : 'fixed';
      var cityVal = '';
      final lid = ad['locality_id'];
      if (lid != null && '$lid'.isNotEmpty) {
        cityVal = '$lid';
      } else if (loc.isNotEmpty && '${ad['location'] ?? ''}'.isNotEmpty) {
        final locStr = '${ad['location']}';
        for (final row in loc) {
          if ('${row['full_label']}' == locStr || '${row['name']}' == locStr) {
            cityVal = '${row['id']}';
            break;
          }
        }
      }
      final y = int.tryParse('${ad['year'] ?? ''}') ?? DateTime.now().year;
      final mileage = int.tryParse('${ad['mileage'] ?? 0}') ?? 0;

      setState(() {
        _ad = ad;
        _localities = loc;
        _catDisplayCtrl.text = '${ad['category'] ?? ''}'.trim();
        _subDisplayCtrl.text = '${ad['subcategory'] ?? ad['subcategory_slug'] ?? ''}'.trim();
        _titleCtrl.text = '${ad['title'] ?? ''}'.trim();
        _brandCtrl.text = '${ad['brand'] ?? ''}'.trim();
        _modelCtrl.text = '${ad['model'] ?? ''}'.trim();
        _yearCtrl.text = '$y';
        _mileageCtrl.text = '$mileage';
        _capacityCtrl.text = '${ad['capacity'] ?? ''}'.trim();
        _phoneCtrl.text = '${ad['phone'] ?? ''}'.trim();
        _descCtrl.text = '${ad['description'] ?? ''}'.trim();
        _priceType = priceType;
        if (priceType == 'fixed') {
          _priceCtrl.text = priceNum == 0 ? '' : _stripTrailingZeros(priceNum);
        } else {
          _priceCtrl.clear();
        }
        _localityId = cityVal.isNotEmpty ? cityVal : null;
        _fuel = _coerceFuel('${ad['fuel_type'] ?? ''}');
        _transmission = _coerceTransmission('${ad['transmission'] ?? ''}');
        _color = _coerceColor('${ad['color'] ?? ''}');
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = friendlyErrorMessage(e);
          _loading = false;
        });
      }
    }
  }

  String _stripTrailingZeros(num n) {
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toString();
  }

  PopupProps<String> _popupProps(ThemeData theme, String titleText) {
    return PopupProps.modalBottomSheet(
      showSearchBox: true,
      title: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            titleText,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      searchFieldProps: TextFieldProps(
        decoration: InputDecoration(
          hintText: 'Поиск...',
          isDense: true,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          prefixIcon: const Icon(Icons.search, size: 22),
        ),
      ),
      modalBottomSheetProps: ModalBottomSheetProps(
        backgroundColor: theme.colorScheme.surface,
        showDragHandle: true,
      ),
    );
  }

  DropDownDecoratorProps _fieldDeco(ThemeData theme, String hint) {
    final th = theme.inputDecorationTheme;
    return DropDownDecoratorProps(
      decoration: InputDecoration(
        hintText: hint,
        filled: th.filled,
        fillColor: th.fillColor,
        contentPadding: th.contentPadding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: th.border ?? OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: th.enabledBorder,
        focusedBorder: th.focusedBorder,
        disabledBorder: th.disabledBorder,
      ),
      baseStyle: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_localityId == null || _localityId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите место / район')));
      return;
    }
    if (_priceType == 'fixed' && _priceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Укажите цену')));
      return;
    }
    setState(() => _saving = true);
    try {
      final fields = <String, String>{
        'category': '${_ad?['category_slug'] ?? ''}',
        'subcategory': '${_ad?['subcategory_slug'] ?? ''}',
        'title': _titleCtrl.text.trim(),
        'brand': _brandCtrl.text.trim(),
        'model': _modelCtrl.text.trim(),
        'year': _yearCtrl.text.trim(),
        'mileage': _mileageCtrl.text.trim(),
        'fuel': _fuel,
        'transmission': _transmission,
        'color': _color,
        'capacity': _capacityCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'city': _localityId!,
        'currency': 'TJS',
        'priceType': _priceType,
        if (_priceType == 'fixed') 'price': _priceCtrl.text.trim(),
      };
      await DastrassApi.instance.updateAd(id: widget.adId, fields: fields);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Изменения сохранены')));
      context.pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBg = theme.colorScheme.onSurface;
    final muted = theme.hintColor;

    if (!AuthService.instance.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Редактирование')),
        body: const Center(child: Text('Войдите в аккаунт')),
      );
    }

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Редактирование')),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_loadError != null || _ad == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Редактирование')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_loadError ?? 'Ошибка', textAlign: TextAlign.center, style: TextStyle(color: onBg)),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Повторить')),
              ],
            ),
          ),
        ),
      );
    }

    final inactive = _ad!['is_active'] == false;
    final nowY = DateTime.now().year;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать объявление'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            if (inactive)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Объявление скрыто. После сохранения оно останется в том же статусе.',
                  style: TextStyle(fontSize: 13, color: muted, height: 1.35),
                ),
              ),
            Text('Категория', style: TextStyle(fontWeight: FontWeight.w600, color: onBg)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _catDisplayCtrl,
              readOnly: true,
              style: TextStyle(color: muted),
              decoration: const InputDecoration(
                hintText: 'Категория',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Text('Подкатегория', style: TextStyle(fontWeight: FontWeight.w600, color: onBg)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _subDisplayCtrl,
              readOnly: true,
              style: TextStyle(color: muted),
              decoration: const InputDecoration(
                hintText: 'Подкатегория',
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleCtrl,
              style: TextStyle(color: onBg),
              decoration: const InputDecoration(labelText: 'Заголовок *'),
              validator: (v) => (v == null || v.trim().length < 3) ? 'Минимум 3 символа' : null,
            ),
            const SizedBox(height: 16),
            Text('Параметры', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: onBg)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _brandCtrl,
                    style: TextStyle(color: onBg),
                    decoration: const InputDecoration(labelText: 'Марка / тип *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Укажите' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _modelCtrl,
                    style: TextStyle(color: onBg),
                    decoration: const InputDecoration(labelText: 'Модель *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Укажите' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _yearCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(color: onBg),
                    decoration: InputDecoration(labelText: 'Год *', hintText: '$nowY'),
                    validator: (v) {
                      final y = int.tryParse(v?.trim() ?? '');
                      if (y == null || y < 1900 || y > nowY + 2) return 'Год $nowY…';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _mileageCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(color: onBg),
                    decoration: const InputDecoration(labelText: 'Пробег, км *'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Укажите пробег';
                      if (int.tryParse(v.trim()) == null) return 'Число';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Топливо'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _fuel,
                        isExpanded: true,
                        isDense: true,
                        items: _fuelChoices
                            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: _saving ? null : (v) => setState(() => _fuel = v ?? 'diesel'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Коробка'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _transmission,
                        isExpanded: true,
                        isDense: true,
                        items: _transChoices
                            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                            .toList(),
                        onChanged: _saving ? null : (v) => setState(() => _transmission = v ?? 'manual'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Цвет'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _color,
                  isExpanded: true,
                  isDense: true,
                  items: _colorChoices
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: _saving ? null : (v) => setState(() => _color = v ?? 'other'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _capacityCtrl,
              style: TextStyle(color: onBg),
              decoration: const InputDecoration(
                labelText: 'Грузоподъёмность',
                hintText: 'Необязательно',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: onBg),
              decoration: const InputDecoration(labelText: 'Телефон (WhatsApp) *'),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.length < 5) return 'Минимум 5 символов';
                if (t.length > 20) return 'Не длиннее 20';
                return null;
              },
            ),
            const SizedBox(height: 20),
            Text('Цена', style: TextStyle(fontWeight: FontWeight.w600, color: onBg)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(value: 'fixed', label: Text('Фиксированная')),
                  ButtonSegment<String>(value: 'negotiable', label: Text('Договорная')),
                ],
                selected: {_priceType},
                onSelectionChanged: _saving
                    ? null
                    : (s) {
                        if (s.isEmpty) return;
                        setState(() => _priceType = s.first);
                      },
              ),
            ),
            if (_priceType == 'fixed') ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: onBg),
                      decoration: const InputDecoration(labelText: 'Сумма *'),
                      validator: (v) {
                        if (_priceType != 'fixed') return null;
                        if (v == null || v.trim().isEmpty) return 'Укажите цену';
                        if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Некорректная цена';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 56,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'смн',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text('Место / район *', style: TextStyle(fontWeight: FontWeight.w600, color: onBg)),
            const SizedBox(height: 6),
            DropdownSearch<String>(
              key: ValueKey('loc_${_localities.length}_${_localityId ?? ''}'),
              selectedItem: _localityId != null && _localities.any((e) => '${e['id']}' == _localityId)
                  ? _localityId
                  : null,
              enabled: _localities.isNotEmpty && !_saving,
              items: (filter, _) async {
                final q = filter.trim().toLowerCase();
                final out = <String>[];
                for (final e in selectableLocalities(_localities)) {
                  final id = '${e['id']}';
                  final label = localitySelectLabel(e).toLowerCase();
                  if (q.isEmpty || label.contains(q) || id.contains(q)) {
                    out.add(id);
                  }
                }
                return out;
              },
              itemAsString: (id) {
                for (final e in _localities) {
                  if ('${e['id']}' == id) return localitySelectLabel(e);
                }
                return id;
              },
              onSelected: (v) => setState(() => _localityId = v),
              validator: (v) => v == null || v.isEmpty ? 'Выберите' : null,
              popupProps: _popupProps(theme, 'Выберите место'),
              decoratorProps: _fieldDeco(theme, 'Выберите'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              minLines: 4,
              maxLines: 8,
              style: TextStyle(color: onBg),
              decoration: const InputDecoration(
                labelText: 'Описание *',
                alignLabelWithHint: true,
              ),
              validator: (v) => (v == null || v.trim().length < 10) ? 'Минимум 10 символов' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
