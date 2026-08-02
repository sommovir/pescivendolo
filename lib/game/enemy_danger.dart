import 'package:flame/components.dart';
import 'package:pescivendolo_game/game/components/enemy_fish.dart';
import 'package:pescivendolo_game/game/components/jellyfish_enemy.dart';
import 'package:pescivendolo_game/game/components/electric_eel_enemy.dart';
import 'package:pescivendolo_game/game/components/swordfish_enemy.dart';
import 'package:pescivendolo_game/game/components/orca_enemy.dart';

/// Punti assegnati quando un nemico viene "ucciso" invece che mangiato
/// normalmente (scudo di invulnerabilità, alleati), in base alla sua
/// pericolosità. Valori centralizzati qui così restano coerenti ovunque:
/// tarati sulla percentuale di danno che il nemico infliggerebbe
/// normalmente al giocatore.
int dangerPoints(Component enemy) {
  if (enemy is OrcaEnemy) return 10; // morso: 35% vita
  if (enemy is SwordfishEnemy) return 8; // carica: 40% vita
  if (enemy is ElectricEelEnemy) return 6; // scarica: 20% vita
  if (enemy is JellyfishEnemy) return 4; // puntura: 10% vita
  if (enemy is EnemyFish) return enemy.isDangerous ? 2 : 1;
  return 1;
}
