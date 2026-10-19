/*
    Author: Djinn
    Description: Registriert persistente Spielereinheiten
                 anhand ihrer Editor-Variablennamen.
*/

if (!isServer) exitWith {};

TAG_PersistentPlayers = createHashMap;

private _registered = 0;

{
    private _varName = vehicleVarName _x;

    if (_varName find "player_" isEqualTo 0) then {

        TAG_PersistentPlayers set [
            _varName,
            _x
        ];

        _registered = _registered + 1;

        ["registerPlayers", format [
            "Spielerrolle registriert | Variable=%1 | Klasse=%2",
            _varName,
            typeOf _x
        ]] call TAG_fnc_debugLog;
    };

} forEach allUnits;

["registerPlayers", format [
    "Spielerregistrierung abgeschlossen | Registrierte Rollen=%1",
    _registered
]] call TAG_fnc_debugLog;