/*
    Author: Djinn

    Description:
    Stellt die übergebenen Respawn-Ticketstände aller Fraktionen
    wieder her.

    Die Funktion speichert nicht selbst auf der Festplatte.
    Sie dient zunächst zum Testen der Wiederherstellung.

    Ausführung: Server
*/

if (!isServer) exitWith {};

params [
    ["_savedTickets", createHashMap, [createHashMap]]
];

{
    private _side = _x;
    private _sideName = str _side;

    private _savedCount = _savedTickets getOrDefault [
        _sideName,
        -1
    ];

    if (
        _savedCount isEqualType 0
        && {_savedCount >= 0}
    ) then {

        private _currentCount = [
            _side
        ] call BIS_fnc_respawnTickets;

        // Aktuellen Bestand vollständig abbauen.
        if (_currentCount != 0) then {
            [
                _side,
                -_currentCount
            ] call BIS_fnc_respawnTickets;
        };

        // Gespeicherten Bestand wiederherstellen.
        [
            _side,
            _savedCount
        ] call BIS_fnc_respawnTickets;

        private _restoredCount = [
            _side
        ] call BIS_fnc_respawnTickets;

        ["restoreRespawnTickets", format [
            "Bestand wiederhergestellt | Fraktion=%1 | Vorher=%2 | Gespeichert=%3 | Aktuell=%4",
            _sideName,
            _currentCount,
            _savedCount,
            _restoredCount
        ]] call TAG_fnc_debugLog;

    } else {

        diag_log format [
            "[PERSISTENCE][TICKETS] WARNUNG: Kein gültiger Testwert vorhanden | Fraktion=%1",
            _sideName
        ];
    };

} forEach [
    west,
    east,
    independent,
    civilian
];