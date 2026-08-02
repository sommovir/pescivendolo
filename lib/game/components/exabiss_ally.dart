import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:pescivendolo_game/game/ally_manager.dart';
import 'package:pescivendolo_game/game/ally_rewards.dart';
import 'package:pescivendolo_game/game/audio_manager.dart';
import 'package:pescivendolo_game/game/enemy_danger.dart';
import 'package:pescivendolo_game/game/fish_game.dart';
import 'package:pescivendolo_game/game/components/boss_component.dart';
import 'package:pescivendolo_game/game/components/coin_pickup.dart';
import 'package:pescivendolo_game/game/components/enemy_fish.dart';
import 'package:pescivendolo_game/game/components/jellyfish_enemy.dart';
import 'package:pescivendolo_game/game/components/electric_eel_enemy.dart';
import 'package:pescivendolo_game/game/components/octopus_enemy.dart';
import 'package:pescivendolo_game/game/components/player_fish.dart';
import 'package:pescivendolo_game/game/components/sapphire_fish.dart';
import 'package:pescivendolo_game/game/components/swordfish_enemy.dart';
import 'package:pescivendolo_game/game/components/orca_enemy.dart';
import 'package:pescivendolo_game/game/components/treasure_pickup.dart';
import 'package:pescivendolo_game/game/components/whale_powerup.dart';

enum _ExabissState { idle, advancing, telegraphing, attacking, retreating }

/// Alleato "Exabiss": un enorme mostro marino che si piazza sul lato
/// sinistro dello schermo. Ogni tanto (a intervalli casuali) avanza fino a
/// un punto casuale entro metà schermo, "carica" per un istante mostrando
/// in anticipo il cono che sta per colpire (come la murena elettrica) e
/// poi scatena un potente attacco elettrico ad ampio raggio davanti a sé,
/// mangiando (nemici, tesori, pesci amici — esattamente come Marmo Carpa,
/// vedi ally_rewards.dart) tutto ciò che si trova nel cono, poi si ritira.
///
/// A differenza della versione precedente NON è invulnerabile: ha una
/// barra HP proporzionata al suo costo (4 volte quella di Marmo Carpa) e
/// perde HP per ogni cosa ostile che lo tocca (distruggendola comunque),
/// oltre a rigenerarsi lentamente nel tempo.
class ExabissAlly extends PositionComponent with CollisionCallbacks, HasGameRef<FishGame> {
  // --- Parametri tarabili -----------------------------------------------
  static const double _idleX = 90; // si piazza visibile sul lato sinistro
  static const double advanceSpeed = 220.0;
  static const double retreatSpeed = 180.0;
  static const double telegraphDuration = 1.0; // tempo di "carica" prima di colpire
  static const double attackDuration = 0.6; // durata del flash dopo il colpo
  static const double minIdleInterval = 8.0;
  static const double maxIdleInterval = 15.0;
  static const double coneLength = 550.0; // gittata molto vasta
  static const double coneStartHalfHeightFactor = 0.28; // vicino a Exabiss (frazione di size.y)
  static const double coneEndHalfHeight = 320.0; // molto largo a fine gittata
  static const double bossDamagePerAttack = 350.0;

  static const double maxHp = 20000.0; // 4 volte Marmo Carpa (5000): costa 4 volte di più (2000 vs 500)
  static const double regenPerSecond = 40.0; // rigenerazione lenta e passiva
  static const double contactDamagePerPoint = 60.0; // danno subito per punto di pericolosità di chi lo tocca

  static const double _swayAmplitude = 18.0; // leggero movimento avanti/indietro da fermo
  static const double _swaySpeed = 1.3;

  // Dimensione del mostro: +50% rispetto alla versione precedente (560x373),
  // mantenendo il rapporto 1536x1024 dello sprite.
  static final Vector2 _bodySize = Vector2(840, 560);

  double hp = maxHp;

  _ExabissState _state = _ExabissState.idle;
  double _idleTimer = 0;
  double _swayPhase = 0;
  double _targetX = 0;
  double _telegraphTimer = 0;
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

    // Attivo: così rileva il contatto con nemici (hitbox passive), che lo
    // feriscono ma vengono comunque distrutti (vedi onCollision).
    add(RectangleHitbox(
      size: Vector2(size.x * 0.8, size.y * 0.75),
      position: Vector2(size.x * 0.1, size.y * 0.12),
    )..collisionType = CollisionType.active);

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

      if (hp <= 0) {
        developer.log('ExabissAlly: distrutto, di nuovo acquistabile');
        AllyManager.consumePurchase(AllyType.exabiss);
        removeFromParent();
        return;
      }

      // Rigenerazione lenta e passiva.
      hp = min(maxHp, hp + regenPerSecond * dt);

      switch (_state) {
        case _ExabissState.idle:
          _idleTimer -= dt;
          // Leggero movimento avanti/indietro sulla posizione di riposo:
          // prima era completamente statico da fermo.
          _swayPhase += dt * _swaySpeed;
          position.x = _idleX + sin(_swayPhase) * _swayAmplitude;
          if (_idleTimer <= 0) {
            _targetX = 60 + _random.nextDouble() * (gameRef.size.x * 0.5 - 60);
            _state = _ExabissState.advancing;
            developer.log('ExabissAlly: avanza verso x=$_targetX');
          }
          break;

        case _ExabissState.advancing:
          _moveToward(_targetX, advanceSpeed, dt, onArrived: () {
            _state = _ExabissState.telegraphing;
            _telegraphTimer = telegraphDuration;
            developer.log('ExabissAlly: carica l\'attacco, cono in anteprima');
          });
          break;

        case _ExabissState.telegraphing:
          // Ferma, mostra il cono che sta per colpire (vedi render):
          // dà al giocatore il tempo di reagire prima del vero danno.
          _telegraphTimer -= dt;
          if (_telegraphTimer <= 0) {
            _state = _ExabissState.attacking;
            _attackTimer = attackDuration;
            _unleashElectricAttack();
          }
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
            _swayPhase = 0;
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

  // --- Geometria del cono di attacco --------------------------------------

  Vector2 get _coneApex => Vector2(position.x + size.x * 0.75, position.y - size.y / 2 + size.y * 0.45);

  double get _coneStartHalfHeight => size.y * coneStartHalfHeightFactor;

  bool _isInCone(Vector2 targetPosition) {
    final apex = _coneApex;
    final dx = targetPosition.x - apex.x;
    if (dx < 0 || dx > coneLength) return false;
    final frac = dx / coneLength;
    final halfHeightAtDx = _coneStartHalfHeight + (coneEndHalfHeight - _coneStartHalfHeight) * frac;
    final dy = (targetPosition.y - apex.y).abs();
    return dy <= halfHeightAtDx;
  }

  void _unleashElectricAttack() {
    try {
      developer.log('ExabissAlly: attacco elettrico nel cono!');
      _electricFlash = attackDuration * 0.7;
      AudioManager.playSoundEffect(AudioManager.electroShockFile, volume: 0.8);

      // Mangia tutto ciò che si trova nel cono, con lo stesso trattamento
      // (ricompensa + testo fluttuante) di Marmo Carpa: nemici, tesori,
      // monetine, PesceZaffiro, polipetto, balena.
      final candidates = <PositionComponent>[
        ...gameRef.children.whereType<EnemyFish>(),
        ...gameRef.children.whereType<JellyfishEnemy>(),
        ...gameRef.children.whereType<ElectricEelEnemy>(),
        ...gameRef.children.whereType<SwordfishEnemy>(),
        ...gameRef.children.whereType<OrcaEnemy>(),
        ...gameRef.children.whereType<OctopusEnemy>(),
        ...gameRef.children.whereType<WhalePowerup>(),
        ...gameRef.children.whereType<CoinPickup>(),
        ...gameRef.children.whereType<TreasurePickup>(),
        ...gameRef.children.whereType<SapphireFish>(),
      ];
      for (final target in candidates) {
        if (_isInCone(target.position)) {
          allyConsume(gameRef, target);
        }
      }

      // Un boss (quando esisterà) subisce solo danno parziale, mai la
      // distruzione istantanea.
      for (final component in gameRef.children) {
        if (component is BossComponent && component is PositionComponent) {
          if (_isInCone(component.position)) {
            (component as BossComponent).takeAllySpecialDamage(bossDamagePerAttack);
          }
        }
      }
    } catch (e, stackTrace) {
      developer.log('Errore in ExabissAlly._unleashElectricAttack: $e\n$stackTrace');
    }
  }

  // --- Danno subito al contatto --------------------------------------------

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    try {
      super.onCollision(intersectionPoints, other);
      if (other is PlayerFish) return; // il giocatore può stargli vicino senza interagire

      if (other is BossComponent) {
        developer.log('ExabissAlly: contatto con un boss, danno reciproco');
        (other as BossComponent).takeAllySpecialDamage(bossDamagePerAttack * 0.3);
        hp -= 300;
        return;
      }

      // I pesci che curano (polipetto, pesce verde), quando sbattono
      // contro Exabiss, lo curano invece di essere "mangiati": la stessa
      // cura che darebbero al giocatore, moltiplicata per 5. Sul
      // giocatore continuano a curare al valore normale (x1), invariato.
      if (other is OctopusEnemy) {
        hp = min(maxHp, hp + other.healAmount * 5);
        developer.log('ExabissAlly: curato dal polipetto (+${other.healAmount * 5} hp)');
        other.removeFromParent();
        return;
      }
      if (other is EnemyFish && !other.isDangerous) {
        hp = min(maxHp, hp + other.healAmount * 5);
        developer.log('ExabissAlly: curato dal pesce verde (+${other.healAmount * 5} hp)');
        other.removeFromParent();
        return;
      }

      // Tutto il resto che lo tocca lo ferisce (se ostile) e viene comunque
      // "mangiato", con la stessa ricompensa che darebbe al giocatore.
      final hostile = isHostileEnemy(other);
      final points = hostile ? dangerPoints(other) : 0;
      final result = allyConsume(gameRef, other);
      if (!result.consumed) return;

      if (hostile) {
        hp -= points * contactDamagePerPoint;
      }
    } catch (e, stackTrace) {
      developer.log('Errore in ExabissAlly.onCollision: $e\n$stackTrace');
    }
  }

  @override
  void render(Canvas canvas) {
    if (_state == _ExabissState.telegraphing) {
      _renderConeTelegraph(canvas);
    }

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
    _renderHpBar(canvas);
  }

  /// Anteprima del cono che sta per colpire, mostrata durante la "carica":
  /// dà al giocatore (e a tutto ciò che sta nel cono) il tempo di reagire
  /// prima del vero danno, come il raggio d'allerta della murena elettrica.
  void _renderConeTelegraph(Canvas canvas) {
    final apexLocal = Offset(size.x * 0.75, size.y * 0.45);
    final pulse = 0.35 + sin(_telegraphTimer * 12) * 0.15;

    final path = Path()
      ..moveTo(apexLocal.dx, apexLocal.dy)
      ..lineTo(apexLocal.dx + coneLength, apexLocal.dy - coneEndHalfHeight)
      ..lineTo(apexLocal.dx + coneLength, apexLocal.dy + coneEndHalfHeight)
      ..close();

    canvas.drawPath(
      path,
      Paint()..color = Colors.cyanAccent.withOpacity(pulse * 0.5),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.cyanAccent.withOpacity(pulse + 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
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

  /// Effetto elettrico procedurale (fulmine a zig-zag) mostrato dopo il
  /// colpo, sull'intera gittata del cono appena scatenato.
  void _renderElectricBolt(Canvas canvas) {
    final startX = size.x * 0.75;
    final endX = startX + coneLength;
    final midY = size.y * 0.45;

    Path buildBolt() {
      final path = Path()..moveTo(startX, midY);
      double x = startX;
      while (x < endX) {
        x += 16 + _random.nextDouble() * 18;
        final progress = (x - startX) / (endX - startX);
        final spread = _coneStartHalfHeight + (coneEndHalfHeight - _coneStartHalfHeight) * progress;
        final y = midY + (_random.nextDouble() * 2 - 1) * spread * 0.6;
        path.lineTo(x, y);
      }
      return path;
    }

    final glowPaint = Paint()
      ..color = Colors.lightBlueAccent.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final corePaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (int i = 0; i < 3; i++) {
      final bolt = buildBolt();
      canvas.drawPath(bolt, glowPaint);
      canvas.drawPath(bolt, corePaint);
    }
  }

  /// Barra HP, abbastanza ampia da riflettere l'alto valore/costo di
  /// Exabiss (4 volte quella di Marmo Carpa).
  void _renderHpBar(Canvas canvas) {
    const barWidth = 280.0;
    const barHeight = 10.0;
    final barsY = -22.0;
    final barsX = (size.x - barWidth) / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(barsX, barsY, barWidth, barHeight), const Radius.circular(4)),
      Paint()..color = Colors.black.withOpacity(0.45),
    );

    final hpFraction = (hp / maxHp).clamp(0.0, 1.0);
    final hpColor = Color.lerp(Colors.redAccent, Colors.lightBlueAccent, hpFraction)!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barsX, barsY, barWidth * hpFraction, barHeight),
        const Radius.circular(4),
      ),
      Paint()..color = hpColor,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(barsX, barsY, barWidth, barHeight), const Radius.circular(4)),
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }
}
