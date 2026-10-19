/*
    Author: Djinn

    Description:
    Speichert die Alpha-Werte aller Editor-Marker mit dem
    Namenspräfix "mrk_persist_" in TAG_SaveData.

    Ausführung: Server
*/

if (!isServer) exitWith {};

if (isNil "TAG_SaveData") exitWith {
    diag_log "[PERSISTENCE][MARKER] FEHLER: TAG_SaveData ist nicht initialisiert.";
};

private _markerStates = createHashMap;
private _savedCount = 0;

{
    private _markerName = _x;

    if ((_markerName find "mrk_persist_") isEqualTo 0) then {
        private _alpha = markerAlpha _markerName;

        _markerStates set [
            _markerName,
            _alpha
        ];

        _savedCount = _savedCount + 1;
    };

} forEach allMapMarkers;

TAG_SaveData set [
    "MarkerStates",
    _markerStates
];

["saveMarkerStates", format [
    "Markerzustände erfasst | Anzahl=%1 | Daten=%2",
    _savedCount,
    str _markerStates
]] call TAG_fnc_debugLog;

[] call TAG_fnc_saveCampaign;