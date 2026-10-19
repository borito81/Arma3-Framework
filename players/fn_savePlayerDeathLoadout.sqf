/*
    Author: Djinn
    Description: Speichert das Loadout einer persistenten Spielerrolle
                 temporär beim Tod.
                 Der dauerhafte Spielerzustand wird nicht verändert.
*/

if (!isServer) exitWith {};

params [
    ["_unit", objNull, [objNull]],
    ["_roleId", "", [""]],
    ["_loadout", [], [[]]]
];

if (isNull _unit) exitWith {
    diag_log "[PERSISTENCE] WARNUNG: Death-Loadout abgelehnt | Einheit ist null";
};

// Nur persistente Spielerrollen zulassen.
if !((_roleId find "player_") isEqualTo 0) exitWith {
    diag_log format [
        "[PERSISTENCE] WARNUNG: Ungültige Rollenkennung | Rolle=%1",
        _roleId
    ];
};

// Rollenname muss zur gestorbenen Einheit passen.
if !(_roleId isEqualTo vehicleVarName _unit) exitWith {
    diag_log format [
        "[PERSISTENCE] WARNUNG: Rollenname stimmt nicht mit Einheit überein | Rolle=%1 | Einheit=%2",
        _roleId,
        vehicleVarName _unit
    ];
};

// Bei Remote-Aufrufen muss der Aufrufer Besitzer der Einheit sein.
private _remoteOwner = remoteExecutedOwner;

if (
    _remoteOwner > 0
    && {owner _unit != _remoteOwner}
) exitWith {
    diag_log format [
        "[PERSISTENCE] WARNUNG: Death-Loadout abgelehnt | Rolle=%1 | RemoteOwner=%2 | UnitOwner=%3",
        _roleId,
        _remoteOwner,
        owner _unit
    ];
};

// Temporären Speicher initialisieren, falls noch nicht vorhanden.
if (isNil "TAG_DeathLoadouts") then {
    TAG_DeathLoadouts = createHashMap;
};

// Ausschließlich im Arbeitsspeicher speichern.
// TAG_SaveData und die dauerhafte Sicherung bleiben unverändert.
TAG_DeathLoadouts set [
    _roleId,
    _loadout
];

["savePlayerDeathLoadout", format [
    "Death-Loadout temporär gespeichert | Rolle=%1",
    _roleId
]] call TAG_fnc_debugLog;