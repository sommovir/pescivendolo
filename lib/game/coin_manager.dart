import 'dart:html' as html;
import 'dart:developer' as developer;

/// Gestisce la valuta del gioco (monete), usata per comprare gli alleati.
///
/// Persistita nel localStorage del browser (il gioco è Flutter Web-only,
/// come il resto del progetto, quindi usiamo direttamente dart:html invece
/// di un package multipiattaforma), ma il saldo viene azzerato a ogni game
/// over/retry (vedi [resetCoins], chiamato da FishGame.reset()): le monete
/// vanno guadagnate e spese entro la stessa partita, non risparmiate tra
/// una partita e l'altra.
///
/// Le monete si guadagnano raccogliendo le monetine che cadono dall'alto
/// (CoinPickup) e i tesori semi-statici (TreasurePickup) durante la partita.
class CoinManager {
  static const String _storageKey = 'pescivendolo_coins';

  static int _coins = 0;
  static bool _loaded = false;

  static int get coins {
    _ensureLoaded();
    return _coins;
  }

  static void _ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    try {
      final stored = html.window.localStorage[_storageKey];
      _coins = stored != null ? int.tryParse(stored) ?? 0 : 0;
      developer.log('CoinManager: caricate $_coins monete');
    } catch (e, stackTrace) {
      developer.log('Errore in CoinManager._ensureLoaded: $e\n$stackTrace');
      _coins = 0;
    }
  }

  static void _save() {
    try {
      html.window.localStorage[_storageKey] = _coins.toString();
    } catch (e, stackTrace) {
      developer.log('Errore in CoinManager._save: $e\n$stackTrace');
    }
  }

  static void addCoins(int amount) {
    if (amount <= 0) return;
    _ensureLoaded();
    _coins += amount;
    _save();
    developer.log('CoinManager: +$amount monete (totale $_coins)');
  }

  /// Tenta di spendere [amount] monete. Ritorna true se il saldo era
  /// sufficiente e la spesa è andata a buon fine.
  static bool spendCoins(int amount) {
    _ensureLoaded();
    if (_coins < amount) return false;
    _coins -= amount;
    _save();
    developer.log('CoinManager: -$amount monete (totale $_coins)');
    return true;
  }

  /// Azzera il saldo: chiamato a ogni game over/retry, così le monete
  /// vanno guadagnate e spese entro la partita in corso.
  static void resetCoins() {
    _ensureLoaded();
    _coins = 0;
    _save();
    developer.log('CoinManager: saldo azzerato');
  }
}
