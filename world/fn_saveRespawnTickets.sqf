/*
    Author: Djinn

    Description:
    Erfasst die aktuellen Respawn-Ticketstände aller Fraktionen
    und legt sie in TAG_SaveData ab.

    Ausführung: Server
*/

if (!isServer) exitWith {};

if (isNil "TAG_SaveData") exitWith {
    diag_log "[PERSISTENCE][TICKETS] FEHLER: TAG_SaveData ist nicht initialisiert.";
};

private _tickets = createHashMap;

{
    private _side = _x;
    private _sideName = str _side;

    private _count = [
        _side
    ] call BIS_fnc_respawnTickets;

    if (_count >= 0) then {

        _tickets set [
            _sideName,
            _count
        ];

        ["saveRespawnTickets", format [
            "Bestand erfasst | Fraktion=%1 | Tickets=%2",
            _sideName,
            _count
        ]] call TAG_fnc_debugLog;

    } else {

        diag_log format [
            "[PERSISTENCE][TICKETS] WARNUNG: Kein gültiger Ticketbestand eingerichtet | Fraktion=%1 | Rückgabe=%2",
            _sideName,
            _count
        ];
    };

} forEach [
    west,
    east,
    independent,
    civilian
];

TAG_SaveData set [
    "RespawnTickets",
    _tickets
];

["saveRespawnTickets", "Ticketstände in TAG_SaveData aktualisiert."] call TAG_fnc_debugLog;

["saveRespawnTickets", format [
    "Vor Kampagnenspeicherung | Daten=%1",
    str (TAG_SaveData get "RespawnTickets")
]] call TAG_fnc_debugLog;

// Ticketstände dauerhaft speichern.
[] call TAG_fnc_saveCampaign;