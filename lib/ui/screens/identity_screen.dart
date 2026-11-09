import 'package:baller/game/models/player_identity.dart';
import 'package:baller/ui/screens/country_screen.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:baller/ui/widgets/alabaster.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Character creation stage 1: name, shirt name and preferred foot.
class IdentityScreen extends StatefulWidget {
  const IdentityScreen({super.key, required this.slot});

  /// Save slot the finished career is written to.
  final int slot;

  @override
  State<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<IdentityScreen> {
  final _name = TextEditingController();
  final _shirt = TextEditingController();
  Foot? _foot;

  /// Once the player types their own shirt name, stop auto-filling it.
  bool _shirtEdited = false;
  bool _nameTouched = false;

  @override
  void dispose() {
    _name.dispose();
    _shirt.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    setState(() {
      _nameTouched = true;
      if (!_shirtEdited) {
        _shirt.text = PlayerIdentity.nameError(value) == null
            ? PlayerIdentity.suggestShirt(value)
            : '';
      }
    });
  }

  String? get _nameError => PlayerIdentity.nameError(_name.text);
  String? get _shirtError => PlayerIdentity.shirtError(_shirt.text);

  bool get _ready => _nameError == null && _shirtError == null && _foot != null;

  /// What the shirt preview shows.
  String get _previewShirt {
    final typed = PlayerIdentity.tidy(_shirt.text);
    if (typed.isNotEmpty) return typed.toUpperCase();
    if (_nameError == null) return PlayerIdentity.suggestShirt(_name.text);
    return 'YOUR NAME';
  }

  void _continue() {
    final identity = PlayerIdentity.fromInput(
      name: _name.text,
      shirtName: _shirt.text,
      foot: _foot!,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CountryScreen(slot: widget.slot, identity: identity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlabasterPage(
      title: 'Create your player',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        children: [
          Text('STAGE 1 OF 6', style: AppText.caps()),
          const SizedBox(height: 4),
          Text(
            'Who are you?',
            style: AppText.display(32, color: AppColors.ink),
          ),
          const SizedBox(height: 20),
          _ShirtPreview(shirt: _previewShirt, foot: _foot),
          const SizedBox(height: 20),
          _Field(
            label: 'Full name',
            controller: _name,
            hint: 'e.g. Tunde Bakare',
            error: _nameTouched ? _nameError : null,
            maxLength: PlayerIdentity.maxNameLength,
            capitalization: TextCapitalization.words,
            onChanged: _onNameChanged,
          ),
          const SizedBox(height: 16),
          _Field(
            label: 'Shirt name',
            controller: _shirt,
            hint: 'Defaults to your surname',
            helper: 'On your shirt and in commentary.',
            error: _shirtError,
            maxLength: PlayerIdentity.maxShirtLength,
            capitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() => _shirtEdited = true),
          ),
          const SizedBox(height: 20),
          Text('PREFERRED FOOT', style: AppText.caps()),
          const SizedBox(height: 8),
          _FootPicker(
            selected: _foot,
            onSelect: (foot) => setState(() => _foot = foot),
          ),
          const SizedBox(height: 8),
          Text(
            'Your other foot is your weak foot.',
            style: AppText.inter(13, color: AppColors.muted),
          ),
        ],
      ),
      bottom: PillButton(
        label: 'Continue',
        trailingArrow: true,
        onPressed: _ready ? _continue : null,
      ),
    );
  }
}

/// Back of a shirt showing the shirt name, updating as you type.
class _ShirtPreview extends StatelessWidget {
  const _ShirtPreview({required this.shirt, required this.foot});

  final String shirt;
  final Foot? foot;

  @override
  Widget build(BuildContext context) {
    final foot = this.foot;
    return HeroCard(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SHIRT',
                  style: AppText.caps(color: AppColors.onDarkMuted),
                ),
              ),
              if (foot != null)
                Text(
                  '${foot.label}-footed',
                  style: AppText.inter(12, weight: 600, color: AppColors.mint),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                shirt,
                maxLines: 1,
                style: AppText.manrope(
                  34,
                  weight: 800,
                  letterSpacing: 6,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    required this.maxLength,
    required this.capitalization,
    required this.onChanged,
    this.helper,
    this.error,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final String? helper;
  final String? error;
  final int maxLength;
  final TextCapitalization capitalization;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.sand, width: 1.5),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppText.caps()),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          textCapitalization: capitalization,
          inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
          style: AppText.inter(16, weight: 500, color: AppColors.ink),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            hintText: hint,
            hintStyle: AppText.inter(16, color: AppColors.muted),
            helperText: helper,
            helperStyle: AppText.inter(13, color: AppColors.muted),
            errorText: error,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            border: outline,
            enabledBorder: outline,
            focusedBorder: outline.copyWith(
              borderSide: const BorderSide(
                color: AppColors.charcoal,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Left | Right pill toggle.
class _FootPicker extends StatelessWidget {
  const _FootPicker({required this.selected, required this.onSelect});

  final Foot? selected;
  final ValueChanged<Foot> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final foot in Foot.values)
            Expanded(
              child: Semantics(
                selected: foot == selected,
                button: true,
                child: Material(
                  color: foot == selected
                      ? AppColors.charcoal
                      : Colors.transparent,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onSelect(foot),
                    child: SizedBox(
                      height: 48,
                      child: Center(
                        child: Text(
                          foot.label,
                          style: AppText.inter(
                            15,
                            weight: 600,
                            color: foot == selected
                                ? Colors.white
                                : AppColors.mutedStrong,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
