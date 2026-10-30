import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../core/constants.dart';
import 'theme.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: dark
              ? const [Brand.bg1, Brand.bg2]
              : const [Color(0xFFF7F6FF), Color(0xFFE9E5FF)],
        ),
      ),
      child: child,
    );
  }
}

class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorder),
      ),
      child: child,
    );
  }
}

class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 34});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'SOFYAN ', style: TextStyle(color: context.textMain)),
          const TextSpan(text: 'YT', style: TextStyle(color: Brand.violetLight)),
        ],
      ),
      textDirection: TextDirection.ltr,
      style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, letterSpacing: 1.2),
    );
  }
}

class Header extends StatelessWidget {
  const Header({super.key, this.trailing});
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Wordmark(size: 30),
                Text(kTagline, style: TextStyle(color: context.textMuted, fontSize: 13)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.busy = false});
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Brand.indigo, Brand.violet]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  else if (icon != null)
                    Icon(icon, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(label,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: context.chipColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) Icon(icon, size: 18, color: context.textMain),
                if (icon != null) const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      style: TextStyle(color: context.textMain, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x33EF4444),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(color: context.isDark ? Brand.red : const Color(0xFFB91C1C))),
    );
  }
}

class NoticeBanner extends StatelessWidget {
  const NoticeBanner(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(color: context.isDark ? Brand.amber : const Color(0xFFB45309), fontSize: 13));
  }
}

InputDecoration fieldDecoration(BuildContext context, {String? hint, String? label}) {
  return InputDecoration(
    hintText: hint,
    labelText: label,
    filled: true,
    fillColor: context.fieldColor,
    hintStyle: TextStyle(color: context.textMuted),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

class DropdownField extends StatelessWidget {
  const DropdownField({super.key, required this.value, required this.items, required this.onChanged, this.label});
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : items.first,
      isExpanded: true,
      decoration: fieldDecoration(context, label: label),
      dropdownColor: context.isDark ? const Color(0xFF1A1450) : Colors.white,
      items: [for (final i in items) DropdownMenuItem<String>(value: i, child: Text(i, overflow: TextOverflow.ellipsis))],
      onChanged: (v) {
        if (v != null) {
          onChanged(v);
        }
      },
    );
  }
}

class MarkdownView extends StatelessWidget {
  const MarkdownView(this.data, {super.key});
  final String data;

  @override
  Widget build(BuildContext context) {
    final base = MarkdownStyleSheet.fromTheme(Theme.of(context));
    final style = TextStyle(color: context.textMain, fontSize: 15.5, height: 1.8);
    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: base.copyWith(
        p: style,
        listBullet: style,
        h1: style.copyWith(fontSize: 22, fontWeight: FontWeight.w800),
        h2: style.copyWith(fontSize: 19, fontWeight: FontWeight.w800),
        h3: style.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
        strong: style.copyWith(fontWeight: FontWeight.w800),
        blockquote: style.copyWith(color: context.textMuted),
        tableBody: style,
        tableHead: style.copyWith(fontWeight: FontWeight.w700),
        code: style.copyWith(fontFamily: 'monospace', fontSize: 14),
      ),
    );
  }
}
