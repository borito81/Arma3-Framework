/*
    Author: Djinn
    Description: Speichert das Loadout beim Tod einer persistenten Rolle.
*/

if (!hasInterface) exitWith {};

private _oldUnit = _this select 0;
private _newUnit = _this select 1;

if !(_oldUnit isEqualType objNull) exitWith {
    diag_log "[PERSISTENCE] FEHLER: onPlayerKilled erhielt kein Objekt als ersten Parameter.";
};

if !(_newUnit isEqualType objNull) exitWith {
    diag_log "[PERSISTENCE] FEHLER: onPlayerKilled erhielt kein Objekt als zweiten Parameter.";
};

if !(missionNamespace getVariable ["TAG_SaveLoadoutOnDeath", false]) exitWith {};

private _roleId = vehicleVarName _oldUnit;

if !((_roleId find "player_") isEqualTo 0) exitWith {
    diag_log format [
        "[PERSISTENCE] WARNUNG: Tod ohne erkannte persistente Rolle | Rolle=%1",
        _roleId
    ];
};

private _loadout = getUnitLoadout _oldUnit;

["onPlayerKilled", format [
    "Tod erkannt | Rolle=%1 | Loadout wird übermittelt",
    _roleId
]] call TAG_fnc_debugLog;

if (isServer) then {
    [_oldUnit, _roleId, _loadout] call TAG_fnc_savePlayerDeathLoadout;
} else {
    [_oldUnit, _roleId, _loadout] remoteExecCall [
        "TAG_fnc_savePlayerDeathLoadout",
        2
    ];
};