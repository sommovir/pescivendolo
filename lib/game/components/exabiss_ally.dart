import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:pescivendolo_game/game/audio_manager.dart';
import 'package:pescivendolo_game/game/fish_game.dart';
import 'package:pescivendolo_game/game/enemy_danger.dart';
import 'package:pescivendolo_game/game/components/boss_component.dart';
import 'package:pescivendolo_game/game/components/enemy_fish.dart';
import 'package:pescivendolo_game/game/components/jellyfish_enemy.dart';
import 'package:pescivendolo_game/game/components/electric_eel_enemy.dart';
import 'package:pescivendolo_game/game/components/swordfish_enemy.dart';
import 'package:pescivendolo_game/game/components/orca_enemy.dart';

enum _ExabissState { idle, advancing, attacking, retreating }

/// Alleato "Exabiss": un enorme mostro marino che si piazza sul lato
/// sinistro dello schermo. Ogni tanto (a intervalli casuali) avanza fino a
/// un punto casuale entro metà schermo e scatena un potente attacco
/// elettrico ad area davanti a sé, distruggendo (e convertendo in punti)
/// tutto ciò che incontra, poi si ritira.
///
/// È invulnerabile: non ha HP proprie, a differenza di Marmo Carpa.
///
/// L'attacco elettrico è disegnato via Canvas (procedurale): nessuno sprite
/// dedicato per l'attacco è ancora disponibile.
class ExabissAlly extends PositionComponent with HasGameRef<FishGame> {
  // --- Parametri tarabili -----------------------------------------------
  static const double _idleX = 90; // si piazza visibile sul lato sinistro
  static const double advanceSpeed = 220.0;
  static const double retreatSpeed = 180.0;
  static const double attackDuration = 0.6;
  static const double minIdleInterval = 8.0;
  static const double maxIdleInterval = 15.0;
  static const double attackAreaWidth = 260.0; // larghezza area colpita davanti a sé
  static const double bossDamagePerAttack = 350.0;

  // Dimensione del mostro: enorme, mantenendo il rapporto 1536x1024 dello sprite
  static final Vector2 _bodySize = Vector2(560, 373);

  _ExabissState _state = _ExabissState.idle;
  double _idleTimer = 0;
  double _targetX = 0;
  double _attackTimer = 0;
  double _electricFlash = 0;
  final Random _random = Random();

  Sprite? _sprite;

  final Paint _bodyPaint = Paint()..color = const Color(0xFF16324F);
  final Paint _finPaint = Paint()..color = const Color(0xFF1E4A73);
  final Paint _eyePaint = Paint()..color = Colors.amberAccent;

  ExabissAlly({required double posY})
      : super(position: Vector2(_idleX, posY), size: _bodySize, anchor: Anchor.center) {
    developer.log('ExabissAlly: costruttore chiamato');
    _resetIdleTimer();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final image = await gameRef.images.load('Exabiss.png');
      _sprite = Sprite(image);
    } catch (e, stackTrace) {
      developer.log('ExabissAlly: sprite non disponibile, uso il placeholder: $e\n$stackTrace');
    }
  }

  void _resetIdleTimer() {
    _idleTimer = minIdleInterval + _random.nextDouble() * (maxIdleInterval - minIdleInterval);
  }

  @override
  void update(double dt) {
    try {
      super.update(dt);
      switch (_state) {
        case _ExabissState.idle:
          _idleTimer -= dt;
          if (_idleTimer <= 0) {
            _targetX = 60 + _random.nextDouble() * (gameRef.size.x * 0.5 - 60);
            _state = _ExabissState.advancing;
            developer.log('ExabissAlly: avanza verso x=$_targetX');
          }
          break;

        case _ExabissState.advancing:
          _moveToward(_targetX, advanceSpeed, dt, onArrived: () {
            _state = _ExabissState.attacking;
            _attackTimer = attackDuration;
            _unleashElectricAttack();
          });
          break;

        case _ExabissState.attacking:
          _attackTimer -= dt;
          if (_electricFlash > 0) _electricFlash = max(0, _electricFlash - dt);
          if (_attackTimer <= 0) {
            _state = _ExabissState.retreating;
          }
          break;

        case _ExabissState.retreating:
          _moveToward(_idleX, retreatSpeed, dt, onArrived: () {
            _state = _ExabissState.idle;
            _resetIdleTimer();
          });
          break;
      }
    } catch (e, stackTrace) {
      developer.log('Errore in ExabissAlly.update: $e\n$stackTrace');
    }
  }

  void _moveToward(double targetX, double speed, double dt, {required VoidCallback onArrived}) {
    final dx = targetX - position.x;
    final step = speed * dt;
    if (dx.abs() <= step) {
      position.x = targetX;
      onArrived();
    } else {
      position.x += step * dx.sign;
    }
  }

  void _unleashElectricAttack() {
    try {
      developer.log('ExabissAlly: attacco elettrico!');
      _electricFlash = attackDuration * 0.7;
      AudioManager.playSoundEffect(AudioManager.electroShockFile, volume: 0.8);

      final areaLeft = position.x + size.x * 0.3;
      final areaRight = areaLeft + attackAreaWidth;

      final targets = <Component>[
        ...gameRef.children.whereType<EnemyFish>(),
        ...gameRef.children.whereType<JellyfishEnemy>(),
        ...gameRef.children.whereType<ElectricEelEnemy>(),
        ...gameRef.children.whereType<SwordfishEnemy>(),
        ...gameRef.children.whereType<OrcaEnemy>(),
      ];
      for (final target in targets) {
        final tx = (target as PositionComponent).position.x;
        if (tx >= areaLeft && tx <= areaRight) {
          gameRef.increaseScore(dangerPoints(target));
          target.removeFromParent();
        }
      }

      // Un boss (quando esisterà) subisce solo danno parziale, mai la
      // distruzione istantanea.
      for (final component in gameRef.children) {
        if (component is BossComponent && component is PositionComponent) {
          final bx = component.position.x;
          if (bx >= areaLeft && bx <= areaRight) {
            (component as BossComponent).takeAllySpecialDamage(bossDamagePerAttack);
          }
        }
      }
    } catch (e, stackTrace) {
      developer.log('Errore in ExabissAlly._unleashElectricAttack: $e\n$stackTrace');
    }
  }

  @override
  void render(Canvas canvas) {
    final sprite = _sprite;
    if (sprite != null) {
      sprite.render(canvas, size: size);
    } else {
      _renderPlaceholderBody(canvas);
    }

    if (_electricFlash > 0) {
      _renderElectricBolt(canvas);
    }

    super.render(canvas);
  }

  /// Corpo di riserva, usato solo se lo sprite non dovesse caricarsi.
  void _renderPlaceholderBody(Canvas canvas) {
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.y * 0.1, size.x * 0.8, size.y * 0.8),
      const Radius.circular(28),
    );
    canvas.drawRRect(bodyRect, _bodyPaint);

    // Coda
    final tailPath = Path()
      ..moveTo(size.x * 0.8, size.y * 0.25)
      ..lineTo(size.x, size.y * 0.0)
      ..lineTo(size.x, size.y)
      ..lineTo(size.x * 0.8, size.y * 0.75)
      ..close();
    canvas.drawPath(tailPath, _finPaint);

    // Cresta dorsale
    for (final dx in [0.25, 0.4, 0.55]) {
      final finPath = Path()
        ..moveTo(size.x * dx, size.y * 0.1)
        ..lineTo(size.x * (dx + 0.05), 0)
        ..lineTo(size.x * (dx + 0.1), size.y * 0.1)
        ..close();
      canvas.drawPath(finPath, _finPaint);
    }

    // Occhio
    canvas.drawCircle(Offset(size.x * 0.13, size.y * 0.42), size.y * 0.08, _eyePaint);
    canvas.drawCircle(Offset(size.x * 0.13, size.y * 0.42), size.y * 0.04, Paint()..color = Colors.black);
  }

  /// Effetto elettrico procedurale (fulmine a zig-zag), in attesa di un
  /// eventuale sprite/animazione dedicata per l'attacco.
  void _renderElectricBolt(Canvas canvas) {
    final startX = size.x * 0.75;
    final endX = startX + attackAreaWidth;
    final midY = size.y * 0.45;

    Path buildBolt() {
      final path = Path()..moveTo(startX, midY);
      double x = startX;
      while (x < endX) {
        x += 12 + _random.nextDouble() * 14;
        final y = midY + (_random.nextDouble() * 50 - 25);
        path.lineTo(x, y);
      }
      return path;
    }

    final glowPaint = Paint()
      ..color = Colors.lightBlueAccent.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final corePaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (int i = 0; i < 2; i++) {
      final bolt = buildBolt();
      canvas.drawPath(bolt, glowPaint);
      canvas.drawPath(bolt, corePaint);
    }
  }
}
