import 'package:baller/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Building blocks of the Luminous Alabaster look, shared by every screen.

/// Page scaffold: alabaster ground, a [ScreenHeader] row, scrollable or fixed
/// [body], and an optional pinned [bottom] (usually a [PillButton]).
class AlabasterPage extends StatelessWidget {
  const AlabasterPage({
    super.key,
    this.title,
    this.center,
    this.trailing,
    this.showBack = true,
    this.background,
    required this.body,
    this.bottom,
  });

  final String? title;

  /// Replaces [title] in the middle of the header (e.g. a score).
  final Widget? center;
  final Widget? trailing;
  final bool showBack;
  final Widget? background;
  final Widget body;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final bottom = this.bottom;
    return Scaffold(
      body: Stack(
        children: [
          if (background case final bg?) Positioned.fill(child: bg),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null ||
                    center != null ||
                    showBack ||
                    trailing != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: ScreenHeader(
                      title: title,
                      center: center,
                      showBack: showBack,
                      trailing: trailing,
                    ),
                  ),
                Expanded(child: body),
                if (bottom != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: bottom,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Back circle · centred title · optional trailing circle.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    this.title,
    this.center,
    this.showBack = true,
    this.trailing,
  });

  final String? title;

  /// Replaces [title] when set.
  final Widget? center;
  final bool showBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: showBack
              ? CircleIconButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                )
              : null,
        ),
        Expanded(
          child: center != null
              ? Center(child: center)
              : title == null
              ? const SizedBox(height: 44)
              : Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppText.manrope(18, weight: 600),
                ),
        ),
        SizedBox(width: 44, child: trailing),
      ],
    );
  }
}

/// 44px white circle with a soft shadow.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: AppColors.softShadow,
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.ink,
          fixedSize: const Size.square(44),
        ),
      ),
    );
  }
}

/// White, 28px-radius card with the whisper shadow.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _Card(
    color: AppColors.surface,
    shadow: AppColors.softShadow,
    radius: radius,
    padding: padding,
    onTap: onTap,
    child: child,
  );
}

/// Charcoal hero card (white text).
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 22, 24, 22),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _Card(
    color: AppColors.charcoal,
    radius: 28,
    padding: padding,
    onTap: onTap,
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: Colors.white),
      child: IconTheme.merge(
        data: const IconThemeData(color: Colors.white),
        child: child,
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({
    required this.color,
    required this.radius,
    required this.padding,
    required this.child,
    this.shadow,
    this.onTap,
  });

  final Color color;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Widget child;
  final List<BoxShadow>? shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: shape, boxShadow: shadow),
      child: Material(
        color: color,
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Full-width 56px pill: charcoal primary or white secondary.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.trailingArrow = false,
    this.secondary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? leading;
  final bool trailingArrow;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final fg = secondary ? AppColors.ink : Colors.white;
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading case final icon?) ...[
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 10),
        ],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (trailingArrow) ...[
          const SizedBox(width: 10),
          Icon(Icons.arrow_forward, size: 20, color: fg),
        ],
      ],
    );
    if (!secondary) {
      return FilledButton(onPressed: onPressed, child: content);
    }
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(999)),
        boxShadow: AppColors.softShadow,
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.ink,
        ),
        child: content,
      ),
    );
  }
}

/// 40px circle holding an icon.
class IconDisc extends StatelessWidget {
  const IconDisc({
    super.key,
    required this.icon,
    this.background = AppColors.chip,
    this.foreground = AppColors.ink,
    this.size = 40,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: background, shape: BoxShape.circle),
    child: Icon(icon, size: size * 0.5, color: foreground),
  );
}

/// Soft beige ovals behind a screen's content.
class DecorOvals extends StatelessWidget {
  const DecorOvals({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              _oval(
                -0.4 * w,
                -0.28 * h,
                1.4 * w,
                0.74 * h,
                -0.35,
                AppColors.sand,
              ),
              _oval(
                -0.15 * w,
                0.62 * h,
                1.6 * w,
                0.62 * h,
                0.2,
                AppColors.sandDeep,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _oval(
    double left,
    double top,
    double width,
    double height,
    double turns,
    Color color,
  ) => Positioned(
    left: left,
    top: top,
    width: width,
    height: height,
    child: Transform.rotate(
      angle: turns,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.all(Radius.elliptical(width, height)),
        ),
      ),
    ),
  );
}
