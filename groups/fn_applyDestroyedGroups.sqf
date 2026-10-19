
/*
    Author: Djinn

    Description:
    Entfernt alle Gruppen, die laut Savegame
    bereits vollständig besiegt wurden.
*/

if (!isServer) exitWith {};

if (isNil "TAG_SaveData") exitWith {
    diag_log "[PERSISTENCE] FEHLER: TAG_SaveData fehlt.";
};

if (isNil "TAG_PersistentGroups") exitWith {
    diag_log "[PERSISTENCE] FEHLER: TAG_PersistentGroups fehlt.";
};

private _destroyedGroups =
    TAG_SaveData getOrDefault ["DestroyedGroups", []];

{
    private _groupID = _x;

    private _group = TAG_PersistentGroups getOrDefault [
        _groupID,
        grpNull
    ];

    if (!isNull _group) then {

        {
            deleteVehicle _x;
        } forEach units _group;

        deleteGroup _group;

        ["applyDestroyedGroups", format [
            "Gruppe entfernt | ID=%1",
            _groupID
        ]] call TAG_fnc_debugLog;

    } else {

        diag_log format [
            "[PERSISTENCE] WARNUNG: Gruppe nicht gefunden: %1",
            _groupID
        ];
    };

} forEach _destroyedGroups;
