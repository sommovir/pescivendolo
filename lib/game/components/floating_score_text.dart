import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

/// Testo che sale e sfuma, mostrato per dare un feedback immediato di
/// monete/punti/vita guadagnati (es. "+10" dorato per le monete, "+5p" blu
/// per i punti, "+10hp" verde per la cura).
///
/// Il fade è gestito manualmente in [update] rigenerando il TextPaint:
/// TextComponent non implementa OpacityProvider in questa versione di
/// Flame, quindi OpacityEffect lancia un'eccezione non gestita a runtime
/// (bloccando l'intero game loop) se applicato direttamente qui.
class FloatingScoreText extends TextComponent {
  static const double _duration = 1.0;
  static const double _fadeStartAt = 0.4;

  static const Color coinColor = Color(0xFFFFD700); // dorato: monete
  static const Color pointsColor = Color(0xFF4FA8FF); // blu: punti
  static const Color healColor = Color(0xFF4CE05A); // verde: vita curata
  static const Color damageColor = Color(0xFFFF5252); // rosso: vita persa
  static const Color ammoColor = Color(0xFF7FD8FF); // azzurro: munizioni fascio energetico

  final Color _color;
  double _elapsed = 0;

  FloatingScoreText({
    required Vector2 position,
    required String text,
    Color color = coinColor,
  })  : _color = color,
        super(
          text: text,
          position: position,
          anchor: Anchor.center,
          priority: 500,
          textRenderer: _paintFor(color, 1.0),
        );

  static TextPaint _paintFor(Color color, double alpha) {
    return TextPaint(
      style: TextStyle(
        color: color.withOpacity(alpha),
        fontSize: 26,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(color: Colors.black87.withOpacity(alpha), blurRadius: 4, offset: const Offset(1, 1)),
        ],
      ),
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      MoveByEffect(
        Vector2(0, -55),
        EffectController(duration: _duration, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;

    if (_elapsed >= _fadeStartAt) {
      final fadeProgress = ((_elapsed - _fadeStartAt) / (_duration - _fadeStartAt)).clamp(0.0, 1.0);
      textRenderer = _paintFor(_color, 1.0 - fadeProgress);
    }

    if (_elapsed >= _duration) {
      removeFromParent();
    }
  }
}
