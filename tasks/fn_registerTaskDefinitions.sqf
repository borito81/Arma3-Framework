/*
    Author: Djinn
    Description:
    Erkennt Eden-Task-Erstellungsmodule automatisch und registriert
    deren Definitionen. Erzeugt selbst keine Tasks.

    Unterstützte Owner-Werte:
    1 = Gruppe
    3 = alle spielbaren Einheiten
*/

if (!isServer) exitWith {};

["registerTaskDefinitions", "Automatische Definitionssuche gestartet."] call TAG_fnc_debugLog;

private _modules = allMissionObjects "ModuleTaskCreate_F";
private _registered = 0;
private _skipped = 0;

{
    private _module = _x;

    private _taskId = _module getVariable ["id", ""];
    private _title = _module getVariable ["title", ""];
    private _description = _module getVariable ["description", ""];
    private _owner = _module getVariable ["owner", -1];
    private _state = _module getVariable ["state", "ASSIGNED"];
    private _hasDestination = (_module getVariable ["destination", 0]) == 1;

    if (_taskId isEqualTo "" || {_title isEqualTo ""}) then {
        diag_log format [
            "[PERSISTENCE][TASK] WARNUNG: Modul übersprungen: ID oder Titel fehlt | Modul=%1",
            vehicleVarName _module
        ];

        _skipped = _skipped + 1;

    } else {

        private _ownerType = "";
        private _ownerId = "";
        private _ownerIds = [];

        switch (_owner) do {
        case 1: {
            private _syncedUnits = synchronizedObjects _module select {
                _x isKindOf "CAManBase"
            };

            private _groups = [];

            {
                private _group = group _x;

                if (!isNull _group) then {
                    _groups pushBackUnique _group;
                };
            } forEach _syncedUnits;

            private _resolvedOwnerIds = [];
            private _ownerResolutionFailed = false;

            {
                private _targetGroup = _x;

                private _groupVars = allVariables missionNamespace select {
                    _x select [0, 11] isEqualTo "player_grp_"
                    && {
                        (missionNamespace getVariable [_x, grpNull])
                            isEqualTo _targetGroup
                    }
                };

                if (count _groupVars == 1) then {
                    _resolvedOwnerIds pushBack (_groupVars select 0);
                } else {
                    _ownerResolutionFailed = true;

                    diag_log format [
                        "[PERSISTENCE][TASK] WARNUNG: Gruppenvariable nicht eindeutig | Task=%1 | Treffer=%2",
                        _taskId,
                        count _groupVars
                    ];
                };
            } forEach _groups;

            if (
                !_ownerResolutionFailed
                && {count _resolvedOwnerIds == count _groups}
                && {count _resolvedOwnerIds > 0}
            ) then {
                _ownerIds = _resolvedOwnerIds;
                _ownerId = _ownerIds select 0;

                if (count _ownerIds == 1) then {
                    _ownerType = "GROUP";
                } else {
                    _ownerType = "GROUPS";
                };
            };
        };

            case 3: {
                _ownerType = "ALL_PLAYABLE_UNITS";
                _ownerId = "ALL_PLAYABLE_UNITS";
            };

            default {
                diag_log format [
                    "[PERSISTENCE][TASK] WARNUNG: Nicht unterstützter Owner-Wert | ID=%1 | Owner=%2",
                    _taskId,
                    _owner
                ];
            };
        };

        if (_ownerType isEqualTo "") then {

            diag_log format [
                "[PERSISTENCE][TASK] WARNUNG: Definition übersprungen: Owner nicht eindeutig | ID=%1 | Owner=%2",
                _taskId,
                _owner
            ];

            _skipped = _skipped + 1;

        } else {

            private _destination = [];

            if (_hasDestination) then {
                _destination = getPosATL _module;
            };

            private _result = [
                _taskId,
                _ownerType,
                _ownerId,
                [
                    _title,
                    _description,
                    _description
                ],
                _destination,
                _state,
                _ownerIds
            ] call TAG_fnc_registerTaskDefinition;

            if (_result) then {
                _registered = _registered + 1;
            } else {
                _skipped = _skipped + 1;
            };

            ["registerTaskDefinitions", format [
                "Modul verarbeitet | ID=%1 | OwnerType=%2 | OwnerId=%3 | OwnerIds=%4 | Ziel=%5 | Ergebnis=%6",
                _taskId,
                _ownerType,
                _ownerId,
                _ownerIds,
                _destination,
                _result
            ]] call TAG_fnc_debugLog;
        };
    };

} forEach _modules;