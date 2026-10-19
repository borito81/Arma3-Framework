/*
    Author: Djinn
    Description:
    Stellt gespeicherte Task-Zustände wieder her.
    Fehlende Tasks werden anhand ihrer persistenten Definition
    rekonstruiert, sofern Created=true gespeichert ist.
*/

if (!hasInterface) exitWith {};

TAG_TaskRestoreComplete = false;

// ------------------------------------------------------------
// 1. Auf Spieler, Task-Status und Definitionen warten
// ------------------------------------------------------------

waitUntil {
    sleep 1;
    !isNull player
    && {!isNil "TAG_TaskStates"}
    && {!isNil "TAG_TaskDefinitions"}
};

private _taskIds = keys TAG_TaskStates;

["restoreTaskStates", format [
    "Wiederherstellung gestartet | Tasks=%1 | Definitionen=%2",
    count _taskIds,
    count TAG_TaskDefinitions
]] call TAG_fnc_debugLog;

// ------------------------------------------------------------
// 2. Gespeicherte Tasks prüfen und gegebenenfalls erstellen
// ------------------------------------------------------------

{
    private _taskId = _x;

    private _savedState = TAG_TaskStates getOrDefault [
        _taskId,
        ""
    ];

    private _definition = TAG_TaskDefinitions getOrDefault [
        _taskId,
        createHashMap
    ];

    if (_savedState != "") then {

        // Task fehlt: Definition prüfen und Task gegebenenfalls erstellen.
        if !([_taskId] call BIS_fnc_taskExists) then {

            private _created = _definition getOrDefault [
                "Created",
                false
            ];

            if (_created) then {

                private _ownerType = _definition getOrDefault [
                    "OwnerType",
                    ""
                ];

                private _ownerId = _definition getOrDefault [
                    "OwnerId",
                    ""
                ];

                private _ownerIds = _definition getOrDefault [
                    "OwnerIds",
                    []
                ];

                private _description = _definition getOrDefault [
                    "Description",
                    []
                ];

                private _destination = _definition getOrDefault [
                    "Destination",
                    []
                ];

                private _initialState = _definition getOrDefault [
                    "InitialState",
                    "CREATED"
                ];

                private _owner = objNull;

                switch (_ownerType) do {

                    case "ALL_PLAYABLE_UNITS": {
                        _owner = true;
                    };

                    case "GROUP": {
                        _owner = missionNamespace getVariable [
                            _ownerId,
                            grpNull
                        ];
                    };

                    case "GROUPS": {
                        if (_ownerIds isEqualTo []) then {
                            _ownerIds = [_ownerId];
                        };

                        private _resolvedGroups = _ownerIds apply {
                            missionNamespace getVariable [_x, grpNull]
                        };

                        if (
                            count _resolvedGroups > 1
                            && {
                                _resolvedGroups findIf {isNull _x} == -1
                            }
                        ) then {
                            _owner = _resolvedGroups;
                        };
                    };

                    default {
                        diag_log format [
                            "[PERSISTENCE][TASK] WARNUNG: Nicht unterstützter Owner-Typ | ID=%1 | OwnerType=%2",
                            _taskId,
                            _ownerType
                        ];
                    };
                };

                if (
                    (_owner isEqualType true && {_owner})
                    || {(_owner isEqualType grpNull) && {!isNull _owner}}
                    || {(_owner isEqualType []) && {count _owner > 1}}
                ) then {

                    if (count _description == 3) then {

                        // Gespeicherte Struktur:
                        // [Titel, Kurzbeschreibung, Langbeschreibung]
                        //
                        // BIS_fnc_taskCreate erwartet:
                        // [Beschreibung, Titel, Marker]

                        private _taskDescription = [
                            _description select 1,
                            _description select 0,
                            _description select 2
                        ];

                        private _taskDestination = objNull;

                        if (_destination isEqualType []) then {
                            if (count _destination >= 2) then {
                                _taskDestination = _destination;
                            };
                        };

                        private _result = [
                            _owner,
                            _taskId,
                            _taskDescription,
                            _taskDestination,
                            _initialState,
                            -1,
                            false
                        ] call BIS_fnc_taskCreate;

                        ["restoreTaskStates", format [
                            "Task rekonstruiert | ID=%1 | Ergebnis=%2",
                            _taskId,
                            _result
                        ]] call TAG_fnc_debugLog;

                    } else {

                        diag_log format [
                            "[PERSISTENCE][TASK] WARNUNG: Ungültige Beschreibung | ID=%1",
                            _taskId
                        ];
                    };

                } else {

                    diag_log format [
                        "[PERSISTENCE][TASK] WARNUNG: Owner konnte nicht aufgelöst werden | ID=%1 | Typ=%2 | ID=%3",
                        _taskId,
                        _ownerType,
                        _ownerId
                    ];
                };

            } else {

                diag_log format [
                    "[PERSISTENCE][TASK] WARNUNG: Nicht erstellt: Created=false oder Definition fehlt | ID=%1",
                    _taskId
                ];
            };
        };

        // ----------------------------------------------------
        // 3. Auf den Task warten und gespeicherten Status setzen
        // ----------------------------------------------------

        private _endTime = time + 30;

        waitUntil {
            sleep 0.5;
            time > _endTime
            || {[_taskId] call BIS_fnc_taskExists}
        };

        if ([_taskId] call BIS_fnc_taskExists) then {

            [_taskId, _savedState, false] call BIS_fnc_taskSetState;

            ["restoreTaskStates", format [
                "Zustand wiederhergestellt | ID=%1 | Status=%2",
                _taskId,
                _savedState
            ]] call TAG_fnc_debugLog;

        } else {

            diag_log format [
                "[PERSISTENCE][TASK] WARNUNG: Wiederherstellung fehlgeschlagen | ID=%1 | Status=%2",
                _taskId,
                _savedState
            ];
        };
    };

} forEach _taskIds;

// ------------------------------------------------------------
// 4. Wiederherstellung abschließen
// ------------------------------------------------------------

TAG_TaskRestoreComplete = true;

["restoreTaskStates", "Wiederherstellung abgeschlossen; Überwachung darf starten."] call TAG_fnc_debugLog;