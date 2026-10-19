/*
    Author: Djinn
    Description: Speichert Position, Ausrichtung und Ausrüstung
                 aller aktuell besetzten persistenten Spielereinheiten.
*/

if (!isServer) exitWith {};

if (isNil "TAG_PersistentPlayers") exitWith {
    diag_log "[PERSISTENCE] FEHLER: TAG_PersistentPlayers fehlt.";
};

if (isNil "TAG_SaveData") exitWith {
    diag_log "[PERSISTENCE] FEHLER: TAG_SaveData fehlt.";
};

private _players = TAG_SaveData getOrDefault [
    "Players",
    createHashMap
];

private _savedCount = 0;
private _skippedCount = 0;

["savePlayers", format [
    "Spielerspeicherung gestartet | Registrierte Rollen=%1",
    count TAG_PersistentPlayers
]] call TAG_fnc_debugLog;

{
    private _roleId = _x;
    private _unit = _y;

    if (
        !isNull _unit
        && {isPlayer _unit}
        && {alive _unit}
    ) then {

        private _state = createHashMapFromArray [
            ["Position", getPosATL _unit],
            ["VectorDirAndUp", [
                vectorDir _unit,
                vectorUp _unit
            ]],
            ["Loadout", getUnitLoadout _unit]
        ];

        _players set [
            _roleId,
            _state
        ];

        _savedCount = _savedCount + 1;

        ["savePlayers", format [
            "Spielerzustand gespeichert | Rolle=%1 | Position=%2",
            _roleId,
            getPosATL _unit
        ]] call TAG_fnc_debugLog;

    } else {

        _skippedCount = _skippedCount + 1;

        diag_log format [
            "[PERSISTENCE] WARNUNG: Spielerrolle nicht aktualisiert | Rolle=%1 | Grund=%2",
            _roleId,
            if (isNull _unit) then {
                "Einheit nicht vorhanden"
            } else {
                if (!isPlayer _unit) then {
                    "Kein Spieler zugewiesen"
                } else {
                    "Einheit ist nicht am Leben"
                }
            }
        ];
    };

} forEach TAG_PersistentPlayers;

// Alle bisher gespeicherten Rollen beibehalten.
TAG_SaveData set [
    "Players",
    _players
];

// Kampagnendaten dauerhaft speichern.
[] call TAG_fnc_saveCampaign;

["savePlayers", format [
    "Spielerspeicherung abgeschlossen | Aktualisiert=%1 | Übersprungen=%2 | Gespeicherte Rollen insgesamt=%3",
    _savedCount,
    _skippedCount,
    count _players
]] call TAG_fnc_debugLog;