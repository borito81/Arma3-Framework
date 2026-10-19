/*
    Author: Djinn

    Description:
    Stellt die gespeicherten Alpha-Werte der Editor-Marker
    mit dem Namenspräfix "mrk_persist_" wieder her.

    Ausführung: Server
*/

if (!isServer) exitWith {};

if (isNil "TAG_SaveData") exitWith {
    diag_log "[PERSISTENCE][MARKER] FEHLER: TAG_SaveData ist nicht initialisiert.";
};

private _markerStates = TAG_SaveData getOrDefault [
    "MarkerStates",
    createHashMap
];

private _restoredCount = 0;
private _missingCount = 0;

{
    private _markerName = _x;
    private _savedAlpha = _markerStates get _markerName;

    if (_markerName in allMapMarkers) then {

        if (
            _savedAlpha isEqualType 0
            && {_savedAlpha >= 0}
            && {_savedAlpha <= 1}
        ) then {

            _markerName setMarkerAlpha _savedAlpha;
            _restoredCount = _restoredCount + 1;

            ["restoreMarkerStates", format [
                "Marker wiederhergestellt | Name=%1 | Alpha=%2",
                _markerName,
                _savedAlpha
            ]] call TAG_fnc_debugLog;

        } else {

            diag_log format [
                "[PERSISTENCE][MARKER] WARNUNG: Ungültiger gespeicherter Alpha-Wert | Name=%1 | Wert=%2",
                _markerName,
                _savedAlpha
            ];
        };

    } else {

        _missingCount = _missingCount + 1;

        diag_log format [
            "[PERSISTENCE][MARKER] WARNUNG: Gespeicherter Marker existiert nicht in der Mission | Name=%1",
            _markerName
        ];
    };

} forEach keys _markerStates;

["restoreMarkerStates", format [
    "Wiederherstellung abgeschlossen | Wiederhergestellt=%1 | Fehlend=%2",
    _restoredCount,
    _missingCount
]] call TAG_fnc_debugLog;