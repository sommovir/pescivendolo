import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:pescivendolo_game/game/fish_game.dart';

class Hud extends PositionComponent with HasGameRef<FishGame> {
  late TextComponent _scoreText;
  late TextComponent _livesText;
  
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
    
    // Add text components to HUD
    add(_scoreText);
    add(_livesText);
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Update text with current score and lives
    _scoreText.text = 'Punteggio: ${gameRef.score}';
    _livesText.text = 'Vite: ${gameRef.lives}';
  }
}
