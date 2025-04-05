import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'package:pescivendolo_game/game/fish_game.dart';

class Hud extends PositionComponent with HasGameRef<FishGame> {
  late TextComponent _scoreText;
  late HealthBar _healthBar;
  
  Hud() : super(priority: 20); // Alta priorità per essere disegnato sopra tutto
  
  @override
  Future<void> onLoad() async {
    // Posiziona l'HUD nella parte superiore dello schermo
    position = Vector2(10, 10);
    
    // Crea il componente testo per il punteggio
    _scoreText = TextComponent(
      text: 'Punteggio: 0',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              blurRadius: 4,
              color: Colors.black,
              offset: Offset(2, 2),
            ),
          ],
        ),
      ),
    );
    add(_scoreText);
    
    // Crea la barra della salute sotto il punteggio
    _healthBar = HealthBar(
      position: Vector2(0, 30),
      size: Vector2(200, 20),
    );
    add(_healthBar);
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Aggiorna il testo del punteggio
    _scoreText.text = 'Punteggio: ${gameRef.score}';
    
    // Aggiorna la barra della salute
    _healthBar.updateHealth(gameRef.health);
  }
}

class HealthBar extends PositionComponent with HasGameRef {
  final Paint _backgroundPaint = Paint()..color = Colors.grey.shade800;
  final Paint _healthPaint = Paint()..color = Colors.green;
  final Paint _damagePaint = Paint()..color = Colors.red;
  final Paint _borderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  
  double _currentHealth = 100;
  double _displayHealth = 100; // Valore visualizzato con animazione
  double _previousHealth = 100; // Valore precedente per l'animazione
  
  // Effetto di brillantezza per la barra della salute
  final Paint _glowPaint = Paint()
    ..color = Colors.white.withOpacity(0.5)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  
  // Variabili per l'effetto di pulsazione
  double _pulseEffect = 0;
  bool _isPulsing = false;
  double _pulseTimer = 0;
  final double _pulseDuration = 0.5;
  
  HealthBar({
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size);
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Animazione fluida della barra della salute
    if (_displayHealth != _currentHealth) {
      // Velocità di animazione proporzionale alla differenza
      double animSpeed = (_currentHealth - _displayHealth).abs() * 2 * dt;
      animSpeed = min(animSpeed, 5.0); // Limita la velocità massima
      animSpeed = max(animSpeed, 0.5); // Garantisci una velocità minima
      
      if (_displayHealth < _currentHealth) {
        _displayHealth = min(_displayHealth + animSpeed, _currentHealth);
      } else {
        _displayHealth = max(_displayHealth - animSpeed, _currentHealth);
      }
    }
    
    // Gestisci l'effetto di pulsazione
    if (_isPulsing) {
      _pulseTimer -= dt;
      _pulseEffect = sin(_pulseTimer * 10) * 0.2 + 0.8; // Varia tra 0.6 e 1.0
      
      if (_pulseTimer <= 0) {
        _isPulsing = false;
        _pulseEffect = 1.0;
      }
    }
  }
  
  void updateHealth(double newHealth) {
    if (newHealth != _currentHealth) {
      _previousHealth = _currentHealth;
      _currentHealth = newHealth;
      
      // Debug log per tracciare gli aggiornamenti della barra della salute
      print("HealthBar: aggiornamento salute da $_previousHealth a $_currentHealth");
      
      // Attiva l'effetto di pulsazione
      _isPulsing = true;
      _pulseTimer = _pulseDuration;
      
      // Genera particelle in base al cambiamento della salute
      if (newHealth < _previousHealth) {
        // Danno subito - particelle rosse
        _createDamageParticles();
      } else {
        // Salute recuperata - particelle verdi
        _createHealParticles();
      }
    }
  }
  
  void _createDamageParticles() {
    final random = Random();
    final particleCount = ((_previousHealth - _currentHealth) * 0.5).ceil();
    
    for (int i = 0; i < particleCount; i++) {
      final particle = Particle.generate(
        count: 1,
        lifespan: 0.8,
        generator: (i) => AcceleratedParticle(
          acceleration: Vector2(0, 100),
          speed: Vector2(
            random.nextDouble() * 100 - 50,
            random.nextDouble() * -100 - 50,
          ),
          position: Vector2(
            size.x * (_currentHealth / 100) + random.nextDouble() * 10,
            size.y / 2,
          ),
          child: CircleParticle(
            radius: 2 + random.nextDouble() * 3,
            paint: Paint()..color = Colors.red.withOpacity(0.7),
          ),
        ),
      );
      
      // Aggiungi il sistema di particelle al genitore
      final particleSystem = ParticleSystemComponent(
        particle: particle,
      );
      parent?.add(particleSystem);
    }
  }
  
  void _createHealParticles() {
    final random = Random();
    final particleCount = ((_currentHealth - _previousHealth) * 0.5).ceil();
    
    for (int i = 0; i < particleCount; i++) {
      final particle = Particle.generate(
        count: 1,
        lifespan: 1.0,
        generator: (i) => AcceleratedParticle(
          acceleration: Vector2(0, -20),
          speed: Vector2(
            random.nextDouble() * 40 - 20,
            random.nextDouble() * -60 - 20,
          ),
          position: Vector2(
            size.x * (_currentHealth / 100) - random.nextDouble() * 10,
            size.y / 2,
          ),
          child: ComputedParticle(
            renderer: (canvas, particle) {
              final color = Color.lerp(
                Colors.green,
                Colors.lightGreenAccent,
                particle.progress,
              )!.withOpacity(1 - particle.progress);
              
              canvas.drawCircle(
                Offset.zero,
                3 + random.nextDouble() * 2 * (1 - particle.progress),
                Paint()..color = color,
              );
            },
          ),
        ),
      );
      
      // Aggiungi il sistema di particelle al genitore
      final particleSystem = ParticleSystemComponent(
        particle: particle,
      );
      parent?.add(particleSystem);
    }
  }
  
  @override
  void render(Canvas canvas) {
    // Assicurati che la barra sia sempre visibile
    final backgroundRect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRRect(
      RRect.fromRectAndRadius(backgroundRect, const Radius.circular(5)),
      _backgroundPaint,
    );
    
    // Disegna la barra della salute attuale (animata)
    // Assicurati che healthWidth non sia mai negativo
    final healthWidth = max(0.0, size.x * (_displayHealth / 100));
    final healthRect = Rect.fromLTWH(0, 0, healthWidth, size.y);
    
    // Calcola il colore della barra in base alla percentuale di salute
    final healthColor = Color.lerp(
      Colors.red,
      Colors.green,
      _displayHealth / 100,
    )!;
    
    // Applica l'effetto di pulsazione
    _healthPaint.color = healthColor.withOpacity(_pulseEffect);
    
    // Disegna la barra della salute con angoli arrotondati
    canvas.drawRRect(
      RRect.fromRectAndRadius(healthRect, const Radius.circular(5)),
      _healthPaint,
    );
    
    // Aggiungi un effetto di brillantezza sulla parte superiore della barra
    final glowPath = Path()
      ..moveTo(2, 2)
      ..lineTo(healthWidth - 2, 2)
      ..lineTo(healthWidth - 10, size.y * 0.3)
      ..lineTo(10, size.y * 0.3)
      ..close();
    
    canvas.drawPath(glowPath, Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill);
    
    // Disegna il bordo della barra
    canvas.drawRRect(
      RRect.fromRectAndRadius(backgroundRect, const Radius.circular(5)),
      _borderPaint,
    );
    
    // Aggiungi segni di graduazione sulla barra
    final dashPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1;
    
    for (int i = 1; i < 10; i++) {
      final x = size.x * (i / 10);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.y),
        dashPaint,
      );
    }
    
    // Disegna il testo della percentuale di salute
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${_displayHealth.toInt()}%',
        style: TextStyle(
          color: _displayHealth > 50 ? Colors.white : Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(
              blurRadius: 2,
              color: Colors.black,
              offset: Offset(1, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.x - textPainter.width) / 2,
        (size.y - textPainter.height) / 2,
      ),
    );
  }
}
