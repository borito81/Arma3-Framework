if (!hasInterface) exitWith {};

// ============================================================
// MISSIONSPEZIFISCHE SPIELER-EINSTELLUNGEN
// ============================================================
// Hier Einstellungen ergänzen, die für den Spieler gelten.
// 
// Beispiele:
// - 
// - 
//
// ============================================================
// --> von hier


// --> bis hier
// ============================================================
// PERSISTENZFRAMEWORK – NICHT ENTFERNEN
// ============================================================
params ["_player", "_didJIP"];
[_player, _didJIP] call TAG_fnc_initializePlayerPersistence;