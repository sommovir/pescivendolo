import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Componente per lo sfondo acquatico del gioco
class WaterBackgroundComponent extends Component {
  @override
  Future<void> onLoad() async {
    final gradient = FullScreenGradientComponent();
    add(gradient);
    return super.onLoad();
  }
}

/// Componente che crea un gradiente per simulare l'ambiente subacqueo
class FullScreenGradientComponent extends PositionComponent {
  // Vernice per il gradiente
  final Paint _gradientPaint = Paint();
  
  @override
  Future<void> onLoad() async {
    // Questa componente deve coprire tutto lo schermo e stare in background
    priority = -1;
    return super.onLoad();
  }
  
  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    
    // Adatta la dimensione al gioco
    size = gameSize;
    
    // Crea un gradiente verticale che simula l'acqua con effetto di profondità
    _gradientPaint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF1A7AA0),  // Blu chiaro in alto
        Color(0xFF0E4568),  // Blu più scuro in basso
      ],
      stops: [0.0, 1.0],
    ).createShader(
      Rect.fromLTWH(0, 0, gameSize.x, gameSize.y),
    );
  }
  
  @override
  void render(Canvas canvas) {
    // Disegna il background a tutto schermo
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      _gradientPaint,
    );
    
    // Aggiungi un leggero effetto "nebbia" in basso per simulare la profondità
    final fogPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Color(0x44032B45),  // Leggera nebbia blu scuro
        ],
        stops: [0.6, 1.0],
      ).createShader(
        Rect.fromLTWH(0, 0, size.x, size.y),
      );
    
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      fogPaint,
    );
    
    // Effetto raggi solari dall'alto
    final sunrayPaint = Paint()
      ..color = const Color(0x11FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 100.0;
    
    // Disegna alcuni raggi solari
    for (int i = 0; i < 5; i++) {
      final xPos = size.x * (0.1 + i * 0.2);
      canvas.drawLine(
        Offset(xPos, 0),
        Offset(xPos + 100, size.y),
        sunrayPaint,
      );
    }
  }
}
