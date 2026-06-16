import 'package:flutter/material.dart';

import '../../services/audio_service.dart';

/// A chunky, cartoon-styled menu button with a coloured glow. Plays a click
/// SFX and supports an optional leading icon.
class MenuButton extends StatelessWidget {
  const MenuButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = const Color(0xFF6A2CB5),
    this.icon,
    this.enabled = true,
    this.subtitle,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;
  final IconData? icon;
  final bool enabled;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled
            ? () {
                AudioService.instance.click();
                onTap();
              }
            : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[color, color.withOpacity(0.6)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: <BoxShadow>[
              BoxShadow(color: color.withOpacity(0.5), blurRadius: 16, offset: const Offset(0, 6)),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(width: 12),
              ],
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  if (subtitle != null)
                    Text(subtitle!, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
