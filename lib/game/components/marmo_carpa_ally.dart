import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:pescivendolo_game/game/fish_game.dart';
import 'package:pescivendolo_game/game/ally_manager.dart';
import 'package:pescivendolo_game/game/coin_manager.dart';
import 'package:pescivendolo_game/game/enemy_danger.dart';
import 'package:pescivendolo_game/game/components/boss_component.dart';
import 'package:pescivendolo_game/game/components/enemy_fish.dart';
import 'package:pescivendolo_game/game/components/jellyfish_enemy.dart';
import 'package:pescivendolo_game/game/components/electric_eel_enemy.dart';
import 'package:pescivendolo_game/game/components/swordfish_enemy.dart';
import 'package:pescivendolo_game/game/components/orca_enemy.dart';

/// Alleato "Marmo Carpa": un pesce corazzato che avanza lentamente davanti
/// al giocatore, distruggendo (e convertendo in punti) tutto ciò che gli
/// sbatte contro. Accumula energia con ogni distruzione e, a energia
/// massima, scatena un attacco "terra" che ripulisce lo schermo da tutti i
/// nemici presenti, convertendoli in punti.
///
/// Usa lo sprite reale MarmoCarpa.webp quando disponibile; in caso di
/// mancato caricamento ricade su un placeholder disegnato via Canvas
/// (vedi [render]).
class MarmoCarpaAlly extends PositionComponent with CollisionCallbacks, HasGameRef<FishGame> {
  // --- Parametri tarabili -----------------------------------------------
  static const double maxHp = 5000.0;
  static const double advanceSpeed = 12.0; // px/s: avanza lentamente
  static const double maxEnergy = 100.0;
  static const double hpLostPerImpact = 15.0; // HP persi ad ogni nemico distrutto
  static const double hpLostAgainstBoss = 40.0; // HP persi colpendo un boss
  static const double bossImpactDamage = 120.0; // danno inflitto a un boss per contatto
  static const double bossUltimateDamage = 400.0; // danno inflitto a un boss dall'attacco terra

  // Dimensione del corpo: doppia rispetto alla versione precedente (192x144).
  static final Vector2 _bodySize = Vector2(384, 288);

  double hp = maxHp;
  double energy = 0.0;

  double _shakeCooldown = 0;
  double _ultimateFlashTimer = 0;

  Sprite? _sprite;

  final Paint _bodyPaint = Paint()..color = const Color(0xFF6B4226);
  final Paint _finPaint = Paint()..color = const Color(0xFF8B5A2B);
  final Paint _eyePaint = Paint()..color = Colors.white;
  final Paint _pupilPaint = Paint()..color = Colors.black;

  MarmoCarpaAlly({required Vector2 position})
      : super(position: position, size: _bodySize, anchor: Anchor.center) {
    developer.log('MarmoCarpaAlly: costruttore chiamato');
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Attivo, non passivo: TUTTI i nemici hanno hitbox passive (collidono
    // solo col player, che è l'unico componente attivo). Con Marmo Carpa
    // passivo anche lui, Flame scartava la coppia passivo-passivo e le
    // collisioni non venivano mai rilevate: era il motivo per cui sembrava
    // "non funzionare" e nulla gli sbatteva mai davvero contro.
    add(RectangleHitbox(
      size: Vector2(size.x * 0.85, size.y * 0.7),
      position: Vector2(size.x * 0.075, size.y * 0.15),
    )..collisionType = CollisionType.active);

    try {
      final image = await gameRef.images.load('MarmoCarpa.webp');
      _sprite = Sprite(image);
    } catch (e, stackTrace) {
      developer.log('MarmoCarpaAlly: sprite non disponibile, uso il placeholder: $e\n$stackTrace');
    }
  }

  @override
  void update(double dt) {
    try {
      super.update(dt);

      if (hp <= 0) {
        developer.log('MarmoCarpaAlly: distrutto');
        removeFromParent();
        return;
      }

      // Avanza lentamente verso destra, senza limiti: se esce del tutto
      // dallo schermo l'acquisto si considera consumato (vedi sotto).
      position.x += advanceSpeed * dt;
      if (position.x - size.x / 2 > gameRef.size.x) {
        developer.log('MarmoCarpaAlly: uscito dallo schermo, di nuovo acquistabile');
        AllyManager.consumePurchase(AllyType.marmoCarpa);
        removeFromParent();
        return;
      }

      if (_ultimateFlashTimer > 0) {
        _ultimateFlashTimer = max(0, _ultimateFlashTimer - dt);
      }
      if (_shakeCooldown > 0) {
        _shakeCooldown -= dt;
      }
    } catch (e, stackTrace) {
      developer.log('Errore in MarmoCarpaAlly.update: $e\n$stackTrace');
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    try {
      super.onCollision(intersectionPoints, other);
      _handleImpact(other);
    } catch (e, stackTrace) {
      developer.log('Errore in MarmoCarpaAlly.onCollision: $e\n$stackTrace');
    }
  }

  void _handleImpact(PositionComponent other) {
    // Il controllo sul boss va fatto per primo e indipendentemente dal tipo
    // concreto: un futuro nemico boss non erediterà necessariamente da
    // nessuna delle classi nemico esistenti.
    if (other is BossComponent) {
      developer.log('MarmoCarpaAlly: contatto con un boss, danno parziale');
      (other as BossComponent).takeAllySpecialDamage(bossImpactDamage);
      hp -= hpLostAgainstBoss;
      return;
    }

    if (other is! EnemyFish &&
        other is! JellyfishEnemy &&
        other is! ElectricEelEnemy &&
        other is! SwordfishEnemy &&
        other is! OrcaEnemy) {
      return; // ignora il giocatore, altri alleati, bolle, ecc.
    }

    final points = dangerPoints(other);
    gameRef.increaseScore(points);
    final coins = _coinsFor(other);
    if (coins > 0) CoinManager.addCoins(coins);
    hp -= hpLostPerImpact;
    energy = min(maxEnergy, energy + points * 2.5);
    other.removeFromParent();

    if (energy >= maxEnergy) {
      _triggerEarthAttack();
    }
  }

  /// Monete guadagnate distruggendo [enemy]: più il nemico è pericoloso,
  /// più monete rende, oltre ai punti (sempre assegnati tramite
  /// [dangerPoints]) — così il tipo di nemico decide se il guadagno è "solo"
  /// punti simbolici o anche una ricompensa in monete più sostanziosa.
  int _coinsFor(Component enemy) {
    if (enemy is OrcaEnemy) return 15;
    if (enemy is SwordfishEnemy) return 8;
    if (enemy is ElectricEelEnemy) return 5;
    if (enemy is JellyfishEnemy) return 3;
    if (enemy is EnemyFish) return enemy.isDangerous ? 2 : 1;
    return 0;
  }

  /// Attacco terra: pulisce lo schermo da tutti i nemici, convertendoli in
  /// punti (i boss subiscono solo danno, non vengono uccisi).
  void _triggerEarthAttack() {
    developer.log('MarmoCarpaAlly: attacco terra! cleanup totale');
    energy = 0;
    _ultimateFlashTimer = 0.4;
    _shakeScreen();

    final targets = <Component>[
      ...gameRef.children.whereType<EnemyFish>(),
      ...gameRef.children.whereType<JellyfishEnemy>(),
      ...gameRef.children.whereType<ElectricEelEnemy>(),
      ...gameRef.children.whereType<SwordfishEnemy>(),
      ...gameRef.children.whereType<OrcaEnemy>(),
    ];
    for (final target in targets) {
      gameRef.increaseScore(dangerPoints(target));
      final coins = _coinsFor(target);
      if (coins > 0) CoinManager.addCoins(coins);
      target.removeFromParent();
    }

    // I boss (quando esisteranno) subiscono solo danno parziale, mai la
    // distruzione istantanea: qualunque componente implementi
    // BossComponent viene riconosciuto qui a prescindere dal tipo
    // concreto, quindi non serve toccare questo file quando ne aggiungeremo uno.
    for (final component in gameRef.children) {
      if (component is BossComponent) {
        (component as BossComponent).takeAllySpecialDamage(bossUltimateDamage);
      }
    }
  }

  void _shakeScreen() {
    if (_shakeCooldown > 0) return;
    _shakeCooldown = 0.6;
    final random = Random();
    final viewfinder = gameRef.camera.viewfinder;
    viewfinder.add(
      MoveByEffect(
        Vector2(random.nextDouble() * 16 - 8, random.nextDouble() * 16 - 8),
        EffectController(duration: 0.04, alternate: true, repeatCount: 8),
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final glow = _ultimateFlashTimer > 0
        ? (Paint()..color = Colors.orangeAccent.withOpacity(0.5 * (_ultimateFlashTimer / 0.4)))
        : null;

    final sprite = _sprite;
    if (sprite != null) {
      sprite.render(canvas, size: size);
      if (glow != null) {
        canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), glow);
      }
    } else {
      _renderPlaceholderBody(canvas, glow);
    }

    super.render(canvas);
    _renderBars(canvas);
  }

  /// Corpo di riserva, usato solo se lo sprite non dovesse caricarsi.
  void _renderPlaceholderBody(Canvas canvas, Paint? glow) {
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.y * 0.15, size.x * 0.85, size.y * 0.7),
      const Radius.circular(18),
    );
    canvas.drawRRect(bodyRect, _bodyPaint);

    // Coda
    final tailPath = Path()
      ..moveTo(size.x * 0.85, size.y * 0.2)
      ..lineTo(size.x, size.y * 0.02)
      ..lineTo(size.x, size.y * 0.98)
      ..lineTo(size.x * 0.85, size.y * 0.8)
      ..close();
    canvas.drawPath(tailPath, _finPaint);

    // Pinna dorsale
    final finPath = Path()
      ..moveTo(size.x * 0.35, size.y * 0.15)
      ..lineTo(size.x * 0.45, 0)
      ..lineTo(size.x * 0.55, size.y * 0.15)
      ..close();
    canvas.drawPath(finPath, _finPaint);

    // Occhio
    canvas.drawCircle(Offset(size.x * 0.15, size.y * 0.4), size.y * 0.09, _eyePaint);
    canvas.drawCircle(Offset(size.x * 0.15, size.y * 0.4), size.y * 0.045, _pupilPaint);

    if (glow != null) {
      canvas.drawRRect(bodyRect.inflate(6), glow);
    }
  }

  void _renderBars(Canvas canvas) {
    const barWidth = 100.0;
    const barHeight = 6.0;
    final barsY = -18.0;
    final barsX = (size.x - barWidth) / 2;

    // Barra HP
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(barsX, barsY, barWidth, barHeight), const Radius.circular(3)),
      Paint()..color = Colors.black.withOpacity(0.4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barsX, barsY, barWidth * (hp / maxHp).clamp(0.0, 1.0), barHeight),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.redAccent,
    );

    // Barra energia
    final energyY = barsY - 8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(barsX, energyY, barWidth, barHeight), const Radius.circular(3)),
      Paint()..color = Colors.black.withOpacity(0.4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barsX, energyY, barWidth * (energy / maxEnergy).clamp(0.0, 1.0), barHeight),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.amber,
    );
  }
}
