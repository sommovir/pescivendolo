import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math';

/// Componente per le bolle che decorano lo sfondo del gioco
class BubbleComponent extends PositionComponent {
  // Velocità verticale della bolla
  final double speed;
  // Opacità iniziale (le bolle svaniscono gradualmente)
  double opacity = 0.7;
  // Colore della bolla (leggermente azzurro)
  final Paint _paint = Paint()..color = Colors.lightBlue.withOpacity(0.7);
  
  // Random per variare il movimento
  final Random _random = Random();
  
  BubbleComponent({
    required Vector2 position,
    required this.speed,
    required Vector2 size,
  }) : super(position: position, size: size);
  
  @override
  Future<void> onLoad() async {
    // Assegna un'opacità casuale tra 0.5 e 0.9
    opacity = 0.5 + _random.nextDouble() * 0.4;
    _paint.color = Colors.lightBlue.withOpacity(opacity);
    return super.onLoad();
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Muovi la bolla verso l'alto
    position.y -= speed * dt;
    
    // Aggiungi un piccolo movimento laterale ondulatorio
    position.x += sin(position.y / 20) * dt * 5;
    
    // Riduci gradualmente l'opacità
    opacity -= dt * 0.1;
    _paint.color = Colors.lightBlue.withOpacity(opacity);
    
    // Rimuovi la bolla quando diventa troppo trasparente
    if (opacity <= 0) {
      removeFromParent();
    }
  }
  
  @override
  void render(Canvas canvas) {
    // Disegna la bolla con un gradiente radiale
    final Offset center = Offset(size.x / 2, size.y / 2);
    final Rect rect = Rect.fromCenter(
      center: center,
      width: size.x,
      height: size.y,
    );
    
    // Crea un gradiente radiale per rendere la bolla più realistica
    final gradient = RadialGradient(
      center: Alignment.topLeft,
      radius: 1.0,
      colors: [
        Colors.white.withOpacity(opacity),
        Colors.lightBlue.withOpacity(opacity * 0.7),
      ],
      stops: const [0.1, 1.0],
    );
    
    final Paint gradientPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    
    // Disegna il cerchio della bolla
    canvas.drawCircle(center, size.x / 2, gradientPaint);
    
    // Aggiungi un riflesso di luce nella bolla
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(opacity * 0.8)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(center.dx - size.x * 0.2, center.dy - size.y * 0.2),
      size.x * 0.15,
      highlightPaint,
    );
  }
}
