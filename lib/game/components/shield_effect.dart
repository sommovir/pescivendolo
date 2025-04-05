import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:developer' as developer;

/// Effetto visivo di scudo dorato che circonda il giocatore durante l'invulnerabilità
class ShieldEffect extends PositionComponent with HasGameRef {
  double radius;
  final double duration;
  
  // Variabili per l'animazione
  final Paint _shieldPaint = Paint()
    ..color = Colors.amber.withOpacity(0.4)
    ..style = PaintingStyle.fill;
  
  final Paint _borderPaint = Paint()
    ..color = Colors.amber
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;
  
  // Effetto di pulsazione
  double _pulseEffect = 1.0;
  double _pulseTimer = 0.0;
  final double _pulsePeriod = 1.0; // Un ciclo di pulsazione dura 1 secondo
  
  final Random _random = Random();
  Timer? _particleTimer;
  
  ShieldEffect({
    required this.radius,
    required this.duration,
  }) : super(
    anchor: Anchor.center,
  );
  
  @override
  Future<void> onLoad() async {
    try {
      size = Vector2(radius * 2, radius * 2); // Imposta la dimensione in base al raggio
      
      // Assicura che sia posizionato al centro del componente parent
      position = Vector2.zero();
      
      // Aggiungi particelle periodicamente
      _particleTimer = Timer(
        0.2, // Ogni 0.2 secondi
        onTick: _addParticles,
        repeat: true,
        autoStart: true,
      );
      
      developer.log('ShieldEffect: effetto scudo inizializzato con raggio $radius e durata $duration secondi');
      return super.onLoad();
    } catch (e, stackTrace) {
      developer.log('ERRORE in ShieldEffect.onLoad: $e\n$stackTrace');
      rethrow;
    }
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    try {
      // Aggiorna l'effetto di pulsazione
      _pulseTimer += dt;
      if (_pulseTimer >= _pulsePeriod) {
        _pulseTimer -= _pulsePeriod;
      }
      
      // Pulsazione sinusoidale tra 0.7 e 1.0
      _pulseEffect = 0.7 + 0.3 * sin(_pulseTimer / _pulsePeriod * 2 * pi);
      
      // Aggiorna il timer delle particelle
      _particleTimer?.update(dt);
      
      // Variazone leggera del colore
      double colorShift = sin(_pulseTimer * 3) * 0.1; // Ridotto da 0.2 a 0.1 per evitare valori negativi
      
      // Usa max e min per garantire che l'opacità sia sempre nell'intervallo [0.0, 1.0]
      double shieldOpacity = max(0.0, min(1.0, 0.4 * _pulseEffect - colorShift));
      double borderOpacity = max(0.0, min(1.0, 0.8 * _pulseEffect + colorShift));
      
      _shieldPaint.color = Colors.amber.withOpacity(shieldOpacity);
      _borderPaint.color = Colors.amber.withOpacity(borderOpacity);
    } catch (e, stackTrace) {
      developer.log('ERRORE in ShieldEffect.update: $e\n$stackTrace');
    }
  }
  
  @override
  void render(Canvas canvas) {
    try {
      final center = Offset(size.x, size.y);
      
      // Disegna il cerchio principale semi-trasparente
      canvas.drawCircle(
        center,
        radius * _pulseEffect,
        _shieldPaint,
      );
      
      // Disegna il bordo luminoso
      canvas.drawCircle(
        center,
        radius * _pulseEffect,
        _borderPaint,
      );
      
      // Aggiungi un effetto di bagliore
      final glowPaint = Paint()
        ..color = Colors.amber.withOpacity(0.3 * _pulseEffect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      
      canvas.drawCircle(
        center,
        radius * _pulseEffect * 0.9,
        glowPaint,
      );
      
      super.render(canvas);
    } catch (e, stackTrace) {
      developer.log('ERRORE in ShieldEffect.render: $e\n$stackTrace');
    }
  }
  
  void _addParticles() {
    try {
      // Numero casuale di particelle da 1 a 3
      final particleCount = 1 + _random.nextInt(3);
      
      for (int i = 0; i < particleCount; i++) {
        // Posizione casuale sul perimetro dello scudo
        final angle = _random.nextDouble() * 2 * pi;
        final spawnDistance = radius * 0.9;
        final spawnX = size.x + cos(angle) * spawnDistance;
        final spawnY = size.y + sin(angle) * spawnDistance;
        
        // Crea una particella che orbita attorno al giocatore
        final particle = ParticleSystemComponent(
          particle: Particle.generate(
            count: 1,
            lifespan: 1.5,
            generator: (i) => AcceleratedParticle(
              acceleration: Vector2(0, 0),
              speed: Vector2(
                cos(angle + pi/2) * 20, // Movimento tangenziale
                sin(angle + pi/2) * 20,
              ),
              position: Vector2(spawnX, spawnY),
              child: CircleParticle(
                radius: 2 + _random.nextDouble() * 3,
                paint: Paint()..color = Colors.amber.withOpacity(0.7),
              ),
            ),
          ),
        );
        
        add(particle);
        
        // Rimuovi la particella dopo la sua durata
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (isMounted && particle.isMounted) {
            particle.removeFromParent();
          }
        });
      }
    } catch (e, stackTrace) {
      developer.log('ERRORE in ShieldEffect._addParticles: $e\n$stackTrace');
    }
  }
}
