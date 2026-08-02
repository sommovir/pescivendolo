import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'dart:developer' as developer;
import 'package:pescivendolo_game/game/fish_game.dart';

/// Monetina che cade dall'alto fluttuando leggermente da un lato all'altro,
/// finché non scompare "nell'abisso" in fondo allo schermo se non viene
/// raccolta (nessuna penalità, semplicemente persa).
///
/// Esistono due tagli, entrambi generati da [FishGame]:
/// - monetina_1.png: valore 1, più piccola
/// - monetina2.png: valore 10
class CoinPickup extends SpriteComponent with CollisionCallbacks, HasGameRef<FishGame> {
  final int value;
  final String assetName;

  /// True una volta raccolta: evita di assegnare le monete due volte se
  /// Flame registra più collisioni nello stesso frame prima della rimozione.
  bool collected = false;

  final double _baseX;
  double _fallSpeed = 0;
  double _swayPhase = 0;
  double _swayAmplitude = 0;

  CoinPickup({
    required Vector2 position,
    required this.value,
    required this.assetName,
    required double size,
  })  : _baseX = position.x,
        super(size: Vector2.all(size), position: position) {
    developer.log('CoinPickup: costruttore chiamato (valore $value)');
    anchor = Anchor.center;

    // La velocità di caduta è per lo più lenta, ma ogni tanto (25% dei
    // casi) una monetina cade a velocità media.
    final random = Random();
    final isMediumSpeed = random.nextDouble() < 0.25;
    _fallSpeed = isMediumSpeed
        ? 70 + random.nextDouble() * 45 // media
        : 25 + random.nextDouble() * 25; // lenta

    _swayPhase = random.nextDouble() * pi * 2;
    _swayAmplitude = 12 + random.nextDouble() * 18;
  }

  @override
  Future<void> onLoad() async {
    try {
      await super.onLoad();
      final image = await gameRef.images.load(assetName);
      sprite = Sprite(image);
      // Raggio di raccolta pari al disegno della moneta: va toccata
      // realmente dal pesce, non raccolta a distanza.
      add(CircleHitbox(
        radius: size.x * 0.5,
        position: size / 2,
        anchor: Anchor.center,
      )..collisionType = CollisionType.passive);
    } catch (e, stackTrace) {
      developer.log('Errore in CoinPickup.onLoad: $e\n$stackTrace');
    }
  }

  @override
  void update(double dt) {
    try {
      super.update(dt);

      _swayPhase += dt * 2;
      position.y += _fallSpeed * dt;
      position.x = _baseX + sin(_swayPhase) * _swayAmplitude;

      // Scompare "nell'abisso" se raggiunge il fondo dello schermo senza
      // essere stata raccolta.
      if (position.y > gameRef.size.y + size.y) {
        removeFromParent();
      }
    } catch (e, stackTrace) {
      developer.log('Errore in CoinPickup.update: $e\n$stackTrace');
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    try {
      super.onCollision(intersectionPoints, other);
      // La raccolta è gestita in PlayerFish.onCollision
    } catch (e, stackTrace) {
      developer.log('Errore in CoinPickup.onCollision: $e\n$stackTrace');
    }
  }
}
