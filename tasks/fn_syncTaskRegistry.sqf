/*
    Author: Djinn
    Description:
    Gleicht existierende Tasks mit den persistenten Kampagnendaten ab.
    Neue Tasks werden registriert und ihre Definition auf Created=true
    gesetzt, sofern eine passende Definition existiert.

    Ausführung: Server
*/

if (!isServer) exitWith {};

if (isNil "TAG_SaveData") exitWith {
    diag_log "[PERSISTENCE][TASK] FEHLER: TAG_SaveData ist nicht initialisiert.";
};

["syncTaskRegistry", "Task-Register-Abgleich gestartet."] call TAG_fnc_debugLog;

// ------------------------------------------------------------
// 1. Existierende Task-IDs ermitteln
// ------------------------------------------------------------

private _taskIds = [];

{
    private _varName = _x;

    if (
        (count _varName) >= 3
        && {(_varName select [0, 1]) isEqualTo "@"}
        && {(_varName select [(count _varName) - 2, 2]) isEqualTo ".0"}
    ) then {
        private _taskId = missionNamespace getVariable [_varName, ""];

        if (
            _taskId isEqualType ""
            && {_taskId != ""}
            && {!(_taskId in _taskIds)}
            && {[_taskId] call BIS_fnc_taskExists}
        ) then {
            _taskIds pushBack _taskId;
        };
    };
} forEach allVariables missionNamespace;

// ------------------------------------------------------------
// 2. Task-Status speichern, ohne vorhandene Status zu überschreiben
// ------------------------------------------------------------

private _tasks = TAG_SaveData getOrDefault [
    "Tasks",
    createHashMap
];

private _definitions = TAG_SaveData getOrDefault [
    "TaskDefinitions",
    createHashMap
];

private _dataChanged = false;

{
    private _taskId = _x;

    if (isNil {_tasks get _taskId}) then {
        private _state = _taskId call BIS_fnc_taskState;

        _tasks set [_taskId, _state];
        _dataChanged = true;

        ["syncTaskRegistry", format [
            "Neuer Task registriert | ID=%1 | Status=%2",
            _taskId,
            _state
        ]] call TAG_fnc_debugLog;
    };

    // Nur eine bereits bekannte Definition aktualisieren.
    private _definition = _definitions getOrDefault [
        _taskId,
        createHashMap
    ];

    if (count _definition > 0) then {
        if !(_definition getOrDefault ["Created", false]) then {
            _definition set ["Created", true];
            _definitions set [_taskId, _definition];
            _dataChanged = true;

            ["syncTaskRegistry", format [
                "Erstellung gespeichert | ID=%1 | Created=true",
                _taskId
            ]] call TAG_fnc_debugLog;
        };
    };

} forEach _taskIds;

TAG_SaveData set ["Tasks", _tasks];
TAG_SaveData set ["TaskDefinitions", _definitions];

TAG_TaskStates = _tasks;
publicVariable "TAG_TaskStates";

// ------------------------------------------------------------
// 3. Neu erkannte Tasks protokollieren
// ------------------------------------------------------------

private _knownTaskIds = missionNamespace getVariable [
    "TAG_KnownTaskIds",
    []
];

private _scanInitialized = missionNamespace getVariable [
    "TAG_TaskScanInitialized",
    false
];

if (!_scanInitialized) then {

    missionNamespace setVariable ["TAG_KnownTaskIds", _taskIds];
    missionNamespace setVariable ["TAG_TaskScanInitialized", true];

    ["syncTaskRegistry", format [
        "Erster Abgleich abgeschlossen | Bestand=%1",
        count _taskIds
    ]] call TAG_fnc_debugLog;

} else {

    private _newTaskIds = _taskIds select {
        !(_x in _knownTaskIds)
    };

    {
        ["syncTaskRegistry", format [
            "Neu erkannt | ID=%1 | Status=%2",
            _x,
            _x call BIS_fnc_taskState
        ]] call TAG_fnc_debugLog;

        _knownTaskIds pushBackUnique _x;
    } forEach _newTaskIds;

    missionNamespace setVariable [
        "TAG_KnownTaskIds",
        _knownTaskIds
    ];

    ["syncTaskRegistry", format [
        "Abgleich abgeschlossen | Aktuell=%1 | Neu=%2 | Bekannt=%3",
        count _taskIds,
        count _newTaskIds,
        count _knownTaskIds
    ]] call TAG_fnc_debugLog;
};

publicVariable "TAG_KnownTaskIds";

if (_dataChanged) then {
    [] call TAG_fnc_saveCampaign;
};

// Aktuelle Task-Definitionen an alle Clients veröffentlichen.
TAG_TaskDefinitions = _definitions;
publicVariable "TAG_TaskDefinitions";

["syncTaskRegistry", "Task-Register-Abgleich beendet."] call TAG_fnc_debugLog;