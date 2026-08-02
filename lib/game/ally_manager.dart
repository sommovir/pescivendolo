import 'dart:html' as html;
import 'dart:developer' as developer;
import 'package:pescivendolo_game/game/coin_manager.dart';

enum AllyType { marmoCarpa, exabiss }

class AllyInfo {
  final AllyType type;
  final String displayName;
  final int cost;

  const AllyInfo({required this.type, required this.displayName, required this.cost});
}

/// Gestisce lo sblocco (acquisto) permanente degli alleati e la loro
/// persistenza tra una partita e l'altra.
class AllyManager {
  static const String _storageKeyPrefix = 'pescivendolo_ally_owned_';

  static const Map<AllyType, AllyInfo> allies = {
    AllyType.marmoCarpa: AllyInfo(type: AllyType.marmoCarpa, displayName: 'Marmo Carpa', cost: 500),
    AllyType.exabiss: AllyInfo(type: AllyType.exabiss, displayName: 'Exabiss', cost: 2000),
  };

  static final Map<AllyType, bool> _owned = {};
  static bool _loaded = false;

  static void _ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    try {
      for (final type in AllyType.values) {
        final stored = html.window.localStorage['$_storageKeyPrefix${type.name}'];
        _owned[type] = stored == 'true';
      }
      developer.log('AllyManager: alleati posseduti caricati: $_owned');
    } catch (e, stackTrace) {
      developer.log('Errore in AllyManager._ensureLoaded: $e\n$stackTrace');
    }
  }

  static bool isOwned(AllyType type) {
    _ensureLoaded();
    return _owned[type] ?? false;
  }

  /// Tenta di acquistare l'alleato [type]. Ritorna true se l'acquisto è
  /// andato a buon fine (monete sufficienti e non già posseduto).
  static bool buy(AllyType type) {
    _ensureLoaded();
    if (isOwned(type)) return false;

    final info = allies[type]!;
    if (!CoinManager.spendCoins(info.cost)) {
      developer.log('AllyManager: monete insufficienti per ${info.displayName}');
      return false;
    }

    _owned[type] = true;
    try {
      html.window.localStorage['$_storageKeyPrefix${type.name}'] = 'true';
    } catch (e, stackTrace) {
      developer.log('Errore in AllyManager.buy (salvataggio): $e\n$stackTrace');
    }
    developer.log('AllyManager: ${info.displayName} acquistato');
    return true;
  }

  /// Segna [type] come non più posseduto: usato quando un alleato "si
  /// consuma" lasciando la partita (es. Marmo Carpa che esce dallo schermo),
  /// così torna acquistabile dal negozio.
  static void consumePurchase(AllyType type) {
    _ensureLoaded();
    _owned[type] = false;
    try {
      html.window.localStorage.remove('$_storageKeyPrefix${type.name}');
    } catch (e, stackTrace) {
      developer.log('Errore in AllyManager.consumePurchase: $e\n$stackTrace');
    }
    developer.log('AllyManager: ${allies[type]!.displayName} consumato, di nuovo acquistabile');
  }
}
