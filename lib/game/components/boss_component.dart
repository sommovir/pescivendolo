/// Contratto che i futuri nemici "boss" dovranno implementare.
///
/// Gli attacchi speciali degli alleati (es. il cleanup di Marmo Carpa o
/// l'attacco elettrico di Exabiss) normalmente distruggono all'istante
/// qualunque cosa colpiscono, convertendola in punti. Contro un boss,
/// invece, devono limitarsi a infliggere danno parziale senza ucciderlo:
/// qualunque componente che implementa questa interfaccia viene quindi
/// riconosciuto ed escluso dalla distruzione istantanea.
///
/// Non esiste ancora nessun boss nel gioco: questa interfaccia prepara solo
/// il terreno per quando verrà aggiunto.
abstract class BossComponent {
  /// Infligge danno parziale al boss (non lo distrugge mai direttamente).
  void takeAllySpecialDamage(double amount);
}
