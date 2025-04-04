import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:pescivendolo_game/game/fish_game.dart';

class Hud extends PositionComponent with HasGameRef<FishGame> {
  late TextComponent _scoreText;
  late TextComponent _livesText;
  late HealthBarComponent _healthBar;
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Create score text component
    _scoreText = TextComponent(
      text: 'Punteggio: 0',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      position: Vector2(20, 20),
    );
    
    // Create lives text component
    _livesText = TextComponent(
      text: 'Vite: 3',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      position: Vector2(20, 50),
    );
    
    // Create health bar component
    _healthBar = HealthBarComponent(
      position: Vector2(20, 80),
      barWidth: 200,
      barHeight: 20,
    );
    
    // Add components to HUD
    add(_scoreText);
    add(_livesText);
    add(_healthBar);
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Update text with current score and lives
    _scoreText.text = 'Punteggio: ${gameRef.score}';
    _livesText.text = 'Vite: ${gameRef.lives}';
    
    // Update health bar
    _healthBar.health = gameRef.health;
  }
}

class HealthBarComponent extends PositionComponent {
  double health = 100;
  final double barWidth;
  final double barHeight;
  
  HealthBarComponent({
    required Vector2 position,
    required this.barWidth,
    required this.barHeight,
  }) : super(position: position, size: Vector2(barWidth, barHeight));
  
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    // Draw background (empty health bar)
    final backgroundPaint = Paint()
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(
      Rect.fromLTWH(0, 0, barWidth, barHeight),
      backgroundPaint,
    );
    
    // Draw health bar
    final healthPaint = Paint()
      ..style = PaintingStyle.fill;
    
    // Cambia il colore in base alla salute
    if (health > 60) {
      healthPaint.color = Colors.green;
    } else if (health > 30) {
      healthPaint.color = Colors.orange;
    } else {
      healthPaint.color = Colors.red;
    }
    
    // Disegna la barra della vita proporzionale alla salute attuale
    canvas.drawRect(
      Rect.fromLTWH(0, 0, barWidth * (health / 100), barHeight),
      healthPaint,
    );
    
    // Disegna il bordo della barra della vita
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawRect(
      Rect.fromLTWH(0, 0, barWidth, barHeight),
      borderPaint,
    );
    
    // Aggiungi testo per mostrare la percentuale di vita
    final textPaint = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
    
    textPaint.render(
      canvas,
      'Vita: ${health.toInt()}%',
      Vector2(barWidth / 2 - 30, barHeight / 2 - 7),
    );
  }
}
