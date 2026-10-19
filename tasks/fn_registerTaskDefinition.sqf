/*
    Author: Djinn
    Description:
    Registriert oder aktualisiert eine persistente Task-Definition.
    Die Registrierung erfolgt zentral auf dem Server.

    Parameter:
    0: Task-ID (String)
    1: Owner-Typ ("GROUP", "SIDE", "PLAYER" oder "ALL_PLAYABLE_UNITS")
    2: Owner-ID
    3: Beschreibung [Titel, Kurzbeschreibung, Langbeschreibung]
    4: Zielposition als Array oder [] ohne Ziel
    5: Initialstatus (Standard: "ASSIGNED")
*/

if (!isServer) exitWith {
    diag_log "[PERSISTENCE][TASK] WARNUNG: Registrierung muss auf dem Server erfolgen.";
    false
};

params [
["_taskId", "", [""]],
["_ownerType", "GROUP", [""]],
["_ownerId", "", [""]],
["_description", [], [[]]],
["_destination", [], [[]]],
["_initialState", "ASSIGNED", [""]],
["_ownerIds", [], [[]]]
];

if (_taskId isEqualTo "" || {_ownerId isEqualTo ""}) exitWith {
    diag_log "[PERSISTENCE][TASK] FEHLER: Registrierung abgebrochen: Task-ID oder Owner-ID fehlt.";
    false
};

if !(_ownerType in [
"GROUP",
"GROUPS",
"SIDE",
"PLAYER",
"ALL_PLAYABLE_UNITS"
]) exitWith {
diag_log format [
"[PERSISTENCE][TASK] FEHLER: Ungültiger Owner-Typ: %1",
_ownerType
];
false
};

if (_ownerType in ["GROUP", "GROUPS"]) then {
    if (_ownerIds isEqualTo []) then {
        _ownerIds = [_ownerId];
    };

    _ownerIds = _ownerIds arrayIntersect _ownerIds;

    if (
        count _ownerIds == 0
        || {_ownerIds findIf {_x isEqualTo ""} >= 0}
        || {_ownerType isEqualTo "GROUPS" && {count _ownerIds < 2}}
    ) exitWith {
        diag_log format [
            "[PERSISTENCE][TASK] FEHLER: Ungültige Gruppen-Owner | ID=%1 | OwnerIds=%2",
            _taskId,
            _ownerIds
        ];
        false
    };

    _ownerId = _ownerIds select 0;
};

if (count _description != 3) exitWith {
    diag_log format [
        "[PERSISTENCE][TASK] FEHLER: Ungültige Beschreibung für %1",
        _taskId
    ];
    false
};

private _validStates = [
    "CREATED",
    "ASSIGNED",
    "AUTOASSIGNED",
    "SUCCEEDED",
    "FAILED",
    "CANCELED"
];

if !(_initialState in _validStates) exitWith {
    diag_log format [
        "[PERSISTENCE][TASK] FEHLER: Ungültiger Initialstatus für %1: %2",
        _taskId,
        _initialState
    ];
    false
};

// Vorhandene Definitionen übernehmen.
private _definitions = TAG_SaveData getOrDefault [
    "TaskDefinitions",
    createHashMap
];

private _oldDefinition = _definitions getOrDefault [
    _taskId,
    createHashMap
];

// Definition aktualisieren, aber persistente Laufzeitdaten erhalten.
private _created = _oldDefinition getOrDefault [
    "Created",
    false
];

private _definition = createHashMapFromArray [
    ["OwnerType", _ownerType],
    ["OwnerId", _ownerId],
    ["OwnerIds", _ownerIds],
    ["Description", _description],
    ["Destination", _destination],
    ["InitialState", _initialState],
    ["Created", _created]
];

// Zusätzliche bestehende Felder erhalten, sofern vorhanden.
{
    if (_x != "Created"
        && {_x != "OwnerType"}
        && {_x != "OwnerId"}
        && {_x != "OwnerIds"}
        && {_x != "Description"}
        && {_x != "Destination"}
        && {_x != "InitialState"}) then {
        _definition set [_x, _oldDefinition get _x];
    };
} forEach keys _oldDefinition;

_definitions set [_taskId, _definition];
TAG_SaveData set ["TaskDefinitions", _definitions];

[] call TAG_fnc_saveCampaign;

["registerTaskDefinition", format [
    "Definition registriert | ID=%1 | OwnerType=%2 | OwnerId=%3 | Created=%4",
    _taskId,
    _ownerType,
    _ownerId,
    _created
]] call TAG_fnc_debugLog;

true