/*
    Author: Djinn

    Description:
    Nimmt Task-Statusmeldungen von Clients entgegen
    und speichert sie zentral in TAG_SaveData.

    Akzeptiert alle tatsächlich existierenden Tasks.
*/

if (!isServer) exitWith {};

params [
    ["_taskId", "", [""]],
    ["_taskState", "", [""]]
];

if (_taskId isEqualTo "") exitWith {};

private _validStates = [
    "CREATED",
    "ASSIGNED",
    "AUTOASSIGNED",
    "SUCCEEDED",
    "FAILED",
    "CANCELED"
];

if !(_taskState in _validStates) exitWith {
    diag_log format [
        "[PERSISTENCE][TASK] WARNUNG: Ungültiger Status ignoriert: %1 | %2",
        _taskId,
        _taskState
    ];
};

// Nur tatsächlich existierende Tasks akzeptieren.
if !([_taskId] call BIS_fnc_taskExists) exitWith {
    diag_log format [
        "[PERSISTENCE][TASK] WARNUNG: Statusmeldung für nicht existierenden Task ignoriert: %1",
        _taskId
    ];
};

private _tasks = TAG_SaveData getOrDefault [
    "Tasks",
    createHashMap
];

private _oldState = _tasks getOrDefault [
    _taskId,
    ""
];

if (_oldState isEqualTo _taskState) exitWith {};

_tasks set [_taskId, _taskState];
TAG_SaveData set ["Tasks", _tasks];

// Aktuellen Stand an alle Clients verteilen.
TAG_TaskStates = _tasks;
publicVariable "TAG_TaskStates";

[] call TAG_fnc_saveCampaign;

["reportTaskState", format [
    "Status gespeichert | ID=%1 | Status=%2",
    _taskId,
    _taskState
]] call TAG_fnc_debugLog;