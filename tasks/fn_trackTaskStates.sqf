/*
    Author: Djinn

    Description:
    Erkennt Task-Statusänderungen auf dem Client.
    Die Überwachung beginnt erst nach der Wiederherstellung.
    Task-IDs werden dynamisch vom Server übernommen.
*/

if (!hasInterface) exitWith {};

waitUntil {
    sleep 1;
    !isNull player
};

// Auf Abschluss der Task-Wiederherstellung warten.
waitUntil {
    sleep 0.2;
    !isNil "TAG_TaskRestoreComplete"
    && {TAG_TaskRestoreComplete}
};

private _lastStates = createHashMap;

["trackTaskStates", "Clientüberwachung gestartet."] call TAG_fnc_debugLog;

while {hasInterface} do {

    // Die Liste kann während der Mission erweitert werden.
    private _taskIds = missionNamespace getVariable [
        "TAG_KnownTaskIds",
        []
    ];

    {
        private _taskId = _x;

        if ([_taskId] call BIS_fnc_taskExists) then {

            private _state = _taskId call BIS_fnc_taskState;

            private _lastState = _lastStates getOrDefault [
                _taskId,
                ""
            ];

            if (_lastState isEqualTo "") then {

                // Task wird von der Überwachung erstmals erkannt.
                // Den tatsächlichen Zustand übernehmen, niemals zurücksetzen.
                _lastStates set [_taskId, _state];

                private _savedState = TAG_TaskStates getOrDefault [
                    _taskId,
                    ""
                ];

                if (
                    _savedState != ""
                    && {!(_state isEqualTo _savedState)}
                ) then {

                    ["trackTaskStates", format [
                        "Abweichender Zustand bei Neuerkennung | ID=%1 | Gespeichert=%2 | Aktuell=%3",
                        _taskId,
                        _savedState,
                        _state
                    ]] call TAG_fnc_debugLog;

                    [_taskId, _state] remoteExecCall [
                        "TAG_fnc_reportTaskState",
                        2
                    ];

                } else {

                    ["trackTaskStates", format [
                        "Ausgangszustand übernommen | ID=%1 | Status=%2",
                        _taskId,
                        _state
                    ]] call TAG_fnc_debugLog;
                };

            } else {

                if !(_state isEqualTo _lastState) then {

                    _lastStates set [_taskId, _state];

                    ["trackTaskStates", format [
                        "Statusänderung erkannt | ID=%1 | Status=%2",
                        _taskId,
                        _state
                    ]] call TAG_fnc_debugLog;

                    [_taskId, _state] remoteExecCall [
                        "TAG_fnc_reportTaskState",
                        2
                    ];
                };
            };
        };

    } forEach _taskIds;

    sleep 1;
};