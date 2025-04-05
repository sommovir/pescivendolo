import 'dart:math';
import 'dart:ui';
import 'dart:developer' as dev;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'package:pescivendolo_game/game/fish_game.dart';

class Hud extends PositionComponent with HasGameRef<FishGame> {
  late TextComponent _scoreText;
  late HealthBar _healthBar;
  late InvulnerabilityBar _invulnerabilityBar;
  
  Hud() : super(priority: 100); // Priorità aumentata da 20 a 100 per essere sicuri che sia disegnato sopra tutto
  
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
    
    // Crea la barra dell'invulnerabilità sotto la barra della salute
    _invulnerabilityBar = InvulnerabilityBar(
      position: Vector2(0, 55), // Posizionata sotto la barra della salute
      size: Vector2(200, 15),   // Leggermente più piccola della barra della salute
    );
    add(_invulnerabilityBar);
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    try {
      // Controllo di sicurezza per garantire che la barra sia sempre visibile
      if (!_healthBar.isMounted || !_invulnerabilityBar.isMounted) {
        dev.log('Hud: ripristino componenti mancanti');
        // Se la barra della salute non è più montata, la ricrea
        if (!_healthBar.isMounted) {
          _healthBar = HealthBar(
            position: Vector2(0, 30),
            size: Vector2(200, 20),
          );
          add(_healthBar);
        }
        
        // Se la barra dell'invulnerabilità non è più montata, la ricrea
        if (!_invulnerabilityBar.isMounted) {
          _invulnerabilityBar = InvulnerabilityBar(
            position: Vector2(0, 55),
            size: Vector2(200, 15),
          );
          add(_invulnerabilityBar);
        }
      }
    } catch (e) {
      dev.log('Hud: errore durante il controllo di sicurezza', error: e);
    }
    
    // Aggiorna il testo del punteggio
    _scoreText.text = 'Punteggio: ${gameRef.score}';
    
    // Aggiorna la barra della salute
    _healthBar.updateHealth(gameRef.health);
    
    // Aggiorna la barra dell'invulnerabilità
    _invulnerabilityBar.updateInvulnerability(
      gameRef.invulnerabilityCharge,
      gameRef.invulnerabilityTimer,
      gameRef.isPlayerInvulnerable
    );
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
      print("HealthBar: salute cambiata da $_currentHealth a $newHealth");
      
      _previousHealth = _currentHealth;
      _currentHealth = newHealth;
      
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
    // Forza sempre il disegno dello sfondo della barra
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

class InvulnerabilityBar extends PositionComponent with HasGameRef {
  final Paint _backgroundPaint = Paint()..color = Colors.grey.shade800.withOpacity(0.7);
  final Paint _chargePaint = Paint()..color = Colors.amber;
  final Paint _borderPaint = Paint()
    ..color = Colors.amber.shade800
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  
  double _currentCharge = 0;
  double _displayCharge = 0; // Valore visualizzato con animazione
  double _invulnerabilityTimer = 0;
  bool _isInvulnerable = false;
  
  // Effetto di brillantezza per la barra dell'invulnerabilità
  final Paint _glowPaint = Paint()
    ..color = Colors.amber.withOpacity(0.5)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  
  // Variabili per l'effetto di pulsazione
  double _pulseEffect = 0;
  bool _isPulsing = false;
  double _pulseTimer = 0;
  final double _pulseDuration = 0.5;
  
  InvulnerabilityBar({
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size);
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Animazione fluida della barra dell'invulnerabilità
    if (_displayCharge != _currentCharge) {
      // Velocità di animazione proporzionale alla differenza
      double animSpeed = (_currentCharge - _displayCharge).abs() * 3 * dt;
      animSpeed = min(animSpeed, 10.0); // Limita la velocità massima
      animSpeed = max(animSpeed, 1.0);  // Garantisci una velocità minima
      
      if (_displayCharge < _currentCharge) {
        _displayCharge = min(_displayCharge + animSpeed, _currentCharge);
      } else {
        _displayCharge = max(_displayCharge - animSpeed, _currentCharge);
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
  
  void updateInvulnerability(double chargeValue, double timerValue, bool isInvulnerable) {
    if (chargeValue != _currentCharge || isInvulnerable != _isInvulnerable) {
      double previousCharge = _currentCharge;
      _currentCharge = chargeValue;
      _isInvulnerable = isInvulnerable;
      _invulnerabilityTimer = timerValue;
      
      // Attiva l'effetto di pulsazione se c'è un cambiamento significativo
      if ((chargeValue - previousCharge).abs() > 5 || isInvulnerable != _isInvulnerable) {
        _isPulsing = true;
        _pulseTimer = _pulseDuration;
      }
    } else {
      _invulnerabilityTimer = timerValue;
    }
  }
  
  @override
  void render(Canvas canvas) {
    if (_isInvulnerable || _currentCharge > 0) {
      // Disegna lo sfondo della barra solo se è visibile
      final backgroundRect = Rect.fromLTWH(0, 0, size.x, size.y);
      canvas.drawRRect(
        RRect.fromRectAndRadius(backgroundRect, const Radius.circular(5)),
        _backgroundPaint,
      );
      
      // Disegna la barra di carica/timer
      double barWidth;
      if (_isInvulnerable) {
        // Durante l'invulnerabilità, mostra il timer
        barWidth = size.x * (_invulnerabilityTimer / 10.0); // 10 secondi è la durata massima
      } else {
        // Altrimenti mostra la carica
        barWidth = size.x * (_displayCharge / 100);
      }
      
      // Assicurati che barWidth non sia negativo
      barWidth = max(0.0, barWidth);
      
      final chargeRect = Rect.fromLTWH(0, 0, barWidth, size.y);
      
      // Colora la barra in base allo stato
      if (_isInvulnerable) {
        // Effetto pulsante dorato durante l'invulnerabilità
        _chargePaint.color = Colors.amber.withOpacity(0.7 + sin(DateTime.now().millisecondsSinceEpoch * 0.005) * 0.3);
      } else {
        // Gradazione di colore in base alla percentuale di carica
        _chargePaint.color = Color.lerp(
          Colors.amber.shade300,
          Colors.amber.shade700,
          _displayCharge / 100,
        )!.withOpacity(0.7 + _pulseEffect * 0.3);
      }
      
      // Disegna la barra dell'invulnerabilità con angoli arrotondati
      canvas.drawRRect(
        RRect.fromRectAndRadius(chargeRect, const Radius.circular(5)),
        _chargePaint,
      );
      
      // Aggiungi un effetto di brillantezza sulla parte superiore della barra
      final glowPath = Path()
        ..moveTo(2, 2)
        ..lineTo(barWidth - 2, 2)
        ..lineTo(barWidth - 5, size.y * 0.3)
        ..lineTo(5, size.y * 0.3)
        ..close();
      
      canvas.drawPath(glowPath, Paint()
        ..color = Colors.amber.withOpacity(0.5)
        ..style = PaintingStyle.fill);
      
      // Disegna il bordo della barra
      canvas.drawRRect(
        RRect.fromRectAndRadius(backgroundRect, const Radius.circular(5)),
        _borderPaint,
      );
      
      // Mostra il timer durante l'invulnerabilità
      if (_isInvulnerable) {
        final secondsLeft = _invulnerabilityTimer.ceil();
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${secondsLeft}s',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
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
      } else if (_displayCharge > 0) {
        // Mostra la percentuale di carica
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${_displayCharge.toInt()}%',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
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
        
        // Assicurati che il testo non vada fuori dalla barra di carica
        double textX = (barWidth - textPainter.width) / 2;
        if (textX + textPainter.width > barWidth) {
          textX = max(0, barWidth - textPainter.width);
        }
        
        textPainter.paint(
          canvas,
          Offset(
            textX,
            (size.y - textPainter.height) / 2,
          ),
        );
      }
    }
  }
}
