import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'dart:developer' as developer;
import 'package:pescivendolo_game/game/fish_game.dart';

/// "PesceZaffiro": pesce commestibile raro, un po' più grande dei pesci
/// verdi normali. Dà molti più punti e 50 monete quando catturato, ma è
/// più difficile da prendere: si muove a velocità media in direzioni
/// casuali che cambiano di continuo, e ogni tanto entra in una breve
/// "frenesia" in cui diventa molto più veloce e cambia direzione ancora
/// più spesso.
class SapphireFish extends SpriteComponent with CollisionCallbacks, HasGameRef<FishGame> {
  // --- Ricompensa e rarità (tarabili) ------------------------------------
  // Casuali a ogni esemplare: tanti punti e un bottino di monete molto
  // variabile, per rendere ogni cattura una piccola sorpresa.
  static const int _minScorePoints = 100;
  static const int _maxScorePoints = 250;
  static const int _minCoinsReward = 50;
  static const int _maxCoinsReward = 800;

  late final int scorePoints;
  late final int coinsReward;

  // --- Movimento (tarabile) ----------------------------------------------
  static const double _baseSpeed = 90.0; // velocità media
  static const double _frenzySpeedMultiplier = 2.3;
  static const double _minDirectionInterval = 0.8;
  static const double _maxDirectionInterval = 2.0;
  static const double _frenzyDirectionInterval = 0.3; // cambi direzione più frequenti
  static const double _frenzyChancePerSecond = 0.12; // probabilità di entrare in frenesia
  static const double _minFrenzyDuration = 1.5;
  static const double _maxFrenzyDuration = 3.5;

  /// True una volta che questo esemplare è già stato catturato: evita di
  /// assegnare punti/monete due volte se Flame registra più di una
  /// collisione nello stesso frame prima che la rimozione abbia effetto.
  bool captured = false;

  final Random _random = Random();
  Vector2 _velocity = Vector2.zero();
  double _directionTimer = 0;
  bool _frenzied = false;
  double _frenzyTimer = 0;

  SapphireFish({required Vector2 position})
      : super(size: Vector2(90, 60), position: position) {
    // Poco più grande di un pesce verde normale (70x40 / 70x50).
    scorePoints = _minScorePoints + _random.nextInt(_maxScorePoints - _minScorePoints + 1);
    coinsReward = _minCoinsReward + _random.nextInt(_maxCoinsReward - _minCoinsReward + 1);
    developer.log('SapphireFish: costruttore chiamato (punti=$scorePoints, monete=$coinsReward)');
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    developer.log('SapphireFish: onLoad iniziato');
    try {
      await super.onLoad();

      final spriteImage = await gameRef.images.load('pescezaffiropiccino.png');
      sprite = Sprite(spriteImage);

      add(RectangleHitbox(
        size: Vector2(size.x * 0.8, size.y * 0.65),
        position: Vector2(size.x * 0.1, size.y * 0.17),
      )..collisionType = CollisionType.passive);

      // Parte già in frenesia in un caso su quattro, per varietà.
      if (_random.nextDouble() < 0.25) {
        _startFrenzy();
      }
      _pickNewDirection();

      developer.log('SapphireFish: onLoad completato con successo');
    } catch (e, stackTrace) {
      developer.log('Errore in SapphireFish.onLoad: $e\n$stackTrace');
    }
  }

  void _startFrenzy() {
    _frenzied = true;
    _frenzyTimer = _minFrenzyDuration + _random.nextDouble() * (_maxFrenzyDuration - _minFrenzyDuration);
  }

  void _pickNewDirection() {
    final angle = _random.nextDouble() * pi * 2;
    final speed = _baseSpeed * (_frenzied ? _frenzySpeedMultiplier : 1.0);
    _velocity = Vector2(cos(angle), sin(angle)) * speed;
    // Leggera tendenza verso sinistra, così prima o poi attraversa comunque lo schermo.
    _velocity.x -= 15;

    _directionTimer = _frenzied
        ? _frenzyDirectionInterval
        : _minDirectionInterval + _random.nextDouble() * (_maxDirectionInterval - _minDirectionInterval);
  }

  @override
  void update(double dt) {
    try {
      super.update(dt);

      if (_frenzied) {
        _frenzyTimer -= dt;
        if (_frenzyTimer <= 0) {
          _frenzied = false;
          _pickNewDirection();
        }
      } else if (_random.nextDouble() < _frenzyChancePerSecond * dt) {
        // Ogni tanto, in modo imprevedibile, scatta la frenesia.
        _startFrenzy();
        _pickNewDirection();
      }

      _directionTimer -= dt;
      if (_directionTimer <= 0) {
        _pickNewDirection();
      }

      position += _velocity * dt;

      // Rimbalza sui bordi superiore/inferiore invece di uscire dallo schermo
      if (position.y < size.y / 2) {
        position.y = size.y / 2;
        _velocity.y = _velocity.y.abs();
      } else if (position.y > gameRef.size.y - size.y / 2) {
        position.y = gameRef.size.y - size.y / 2;
        _velocity.y = -_velocity.y.abs();
      }

      // Rimuovi se esce lateralmente dallo schermo
      if (position.x < -size.x || position.x > gameRef.size.x + size.x) {
        removeFromParent();
      }
    } catch (e, stackTrace) {
      developer.log('Errore in SapphireFish.update: $e\n$stackTrace');
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    try {
      super.onCollision(intersectionPoints, other);
      // La cattura è gestita in PlayerFish.onCollision
    } catch (e, stackTrace) {
      developer.log('Errore in SapphireFish.onCollision: $e\n$stackTrace');
    }
  }
}
