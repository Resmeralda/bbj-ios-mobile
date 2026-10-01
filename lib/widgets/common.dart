import 'package:flutter/material.dart';

import '../theme.dart';

/// Colored header + optional pill tabs + rounded white body (matches mockups).
class ScreenScaffold extends StatelessWidget {
  final String title;
  final Color color;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final List<String> tabs;
  final int tab;
  final ValueChanged<int>? onTab;
  final List<Widget> children;

  const ScreenScaffold({
    super.key,
    required this.title,
    required this.color,
    required this.children,
    this.actionIcon,
    this.onAction,
    this.tabs = const [],
    this.tab = 0,
    this.onTab,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: color,
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (actionIcon != null)
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        child: IconButton(
                          icon: Icon(actionIcon, color: color),
                          onPressed: onAction,
                        ),
                      ),
                  ],
                ),
                if (tabs.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (var i = 0; i < tabs.length; i++)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => onTab?.call(i),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: i == tab ? Colors.white : Colors.black26,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                tabs[i],
                                style: TextStyle(
                                  color: i == tab
                                      ? AppColors.ink
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: children,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class AppCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  const AppCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Color actionColor;
  const SectionHeader(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.actionColor = AppColors.home,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(action!, style: TextStyle(color: actionColor)),
          ),
      ],
    ),
  );
}

/// Small tinted tile with icon + label (Quick Access / Quick Add).
class QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const QuickTile(this.icon, this.label, this.color, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Icon(icon, color: color, size: 30),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  const ProgressBar(this.value, this.color, {super.key});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: LinearProgressIndicator(
      value: value,
      minHeight: 8,
      color: color,
      backgroundColor: Colors.black12,
    ),
  );
}
