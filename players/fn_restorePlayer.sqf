
/*
    Author: Djinn
    Description:
        Stellt den gespeicherten Zustand einer persistenten
        Spielereinheit lokal auf dem besitzenden Client wieder her.

        _restorePosition = true:
            Gespeicherte Position und Ausrichtung wiederherstellen.

        _restorePosition = false:
            Respawn-Position der Mission beibehalten.
*/

if (!hasInterface) exitWith {};

params [
    ["_unit", objNull, [objNull]],
    ["_position", [], [[]]],
    ["_vectorDirAndUp", [], [[]]],
    ["_loadout", [], [[]]],
    ["_restorePosition", true, [true]]
];

if (isNull _unit) exitWith {
    diag_log "[PERSISTENCE] FEHLER: Wiederherstellung abgebrochen, Einheit ist null.";
};

if (!local _unit) exitWith {
    diag_log format [
        "[PERSISTENCE] FEHLER: Wiederherstellung abgebrochen, Einheit ist nicht lokal | Einheit=%1",
        _unit
    ];
};

if !(_unit isKindOf "CAManBase" && {isPlayer _unit}) exitWith {
    diag_log "[PERSISTENCE] FEHLER: Wiederherstellung abgebrochen, Einheit ist kein Spieler.";
};

if (_restorePosition && {count _position != 3}) exitWith {
    diag_log "[PERSISTENCE] FEHLER: Ungültige gespeicherte Position.";
};

if (_restorePosition && {count _vectorDirAndUp != 2}) exitWith {
    diag_log "[PERSISTENCE] FEHLER: Ungültige gespeicherte Ausrichtung.";
};

if (_loadout isEqualTo []) exitWith {
    diag_log "[PERSISTENCE] FEHLER: Gespeichertes Loadout fehlt.";
};

["restorePlayer", format [
    "Wiederherstellung gestartet | Einheit=%1 | PositionWiederherstellen=%2 | GespeichertePosition=%3",
    vehicleVarName _unit,
    _restorePosition,
    _position
]] call TAG_fnc_debugLog;

// Position und Ausrichtung nur beim normalen Beitritt wiederherstellen.
if (_restorePosition) then {

    _unit setPosATL _position;

    _unit setVectorDirAndUp [
        _vectorDirAndUp select 0,
        _vectorDirAndUp select 1
    ];

};

// Ausrüstung einschließlich Waffen, Aufsätzen und Munition wiederherstellen.
_unit setUnitLoadout _loadout;

// Gespeicherte Verletzungen nicht übernehmen.
_unit setDamage 0;

["restorePlayer", format [
    "Spielerzustand wiederhergestellt | Einheit=%1 | PositionWiederherstellen=%2 | Position=%3 | Gesundheit=100%%",
    vehicleVarName _unit,
    _restorePosition,
    getPosATL _unit
]] call TAG_fnc_debugLog;
