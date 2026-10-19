/*
    Author: Djinn
    Description:
        Stellt beim Respawn den dauerhaft gespeicherten Spielerzustand
        wieder her.

        Die Auswahl des Loadouts erfolgt in TAG_fnc_requestRestorePlayer:
        - Aktivierte Death-Loadout-Wiederherstellung: temporäres Loadout
        - Deaktivierte Death-Loadout-Wiederherstellung: dauerhaftes Loadout
*/

if (!hasInterface) exitWith {};

private _newUnit = _this select 0;

if !(_newUnit isEqualType objNull) exitWith {
    diag_log "[PERSISTENCE] FEHLER: onPlayerRespawn erhielt kein gültiges Einheitenobjekt.";
};

[] spawn {

    // Warten, bis die neue Spielereinheit lokal verfügbar ist.
    waitUntil {
        sleep 0.1;
        !isNull player && {local player}
    };

    // Warten, bis der Server die Persistenz initialisiert hat.
    waitUntil {
        sleep 0.1;
        !isNil "TAG_PersistenceReady"
        && {TAG_PersistenceReady}
    };

    private _unit = player;
    private _roleId = vehicleVarName _unit;

    if !((_roleId find "player_") isEqualTo 0) exitWith {
        diag_log format [
            "[PERSISTENCE] WARNUNG: Respawn ohne erkannte persistente Rolle | Einheit=%1",
            _roleId
        ];
    };

    private _restoreDeathLoadout = missionNamespace getVariable [
        "TAG_RestoreLoadoutOnRespawn",
        false
    ];

    if (_restoreDeathLoadout) then {

        ["onPlayerRespawn", format [
            "Wiederherstellung angefordert | Temporäres Death-Loadout bevorzugt | Rolle=%1",
            _roleId
        ]] call TAG_fnc_debugLog;

    } else {

        ["onPlayerRespawn", format [
            "Wiederherstellung angefordert | Dauerhaft gespeichertes Loadout verwenden | Rolle=%1",
            _roleId
        ]] call TAG_fnc_debugLog;
    };

    // Die Wiederherstellung wird in beiden Fällen angefordert.
    // fn_requestRestorePlayer.sqf entscheidet über das Loadout.
    if (isServer) then {

        [_unit, _roleId] call TAG_fnc_requestRestorePlayer;

    } else {

        [_unit, _roleId] remoteExecCall [
            "TAG_fnc_requestRestorePlayer",
            2
        ];
    };
};