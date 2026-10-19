
/*
    Author: Djinn

    Description:
    Ereignisbasierte Überwachung besiegter Gegnergruppen.
    Kein permanenter Prüfzyklus.
*/

if (!isServer) exitWith {};

if (isNil "TAG_PersistentGroups") exitWith {
    diag_log "[PERSISTENCE] FEHLER: TAG_PersistentGroups fehlt.";
};

if (isNil "TAG_SaveData") exitWith {
    diag_log "[PERSISTENCE] FEHLER: TAG_SaveData fehlt.";
};

if (!isNil "TAG_TrackDestroyedGroups_EHID") exitWith {
    diag_log "[PERSISTENCE] WARNUNG: Gruppenüberwachung ist bereits registriert.";
};

TAG_TrackDestroyedGroups_EHID = addMissionEventHandler [
    "EntityKilled",
    {
        params ["_killed", "_killer", "_instigator"];

        if (isNull _killed) exitWith {};

        private _killedGroup = group _killed;
        if (isNull _killedGroup) exitWith {};

        private _groupID = "";

        {
            if (_y isEqualTo _killedGroup) exitWith {
                _groupID = _x;
            };
        } forEach TAG_PersistentGroups;

        if (_groupID isEqualTo "") exitWith {};

        private _destroyedGroups = +(
            TAG_SaveData getOrDefault ["DestroyedGroups", []]
        );

        if (_groupID in _destroyedGroups) exitWith {};

        private _units = units _killedGroup;
        private _aliveCount = { alive _x } count _units;

        ["trackDestroyedGroups", format [
            "Gruppenprüfung | ID=%1 | Einheiten=%2 | Lebend=%3",
            _groupID,
            count _units,
            _aliveCount
        ]] call TAG_fnc_debugLog;

        if (_aliveCount == 0) then {

            _destroyedGroups pushBack _groupID;

            TAG_SaveData set [
                "DestroyedGroups",
                _destroyedGroups
            ];

            diag_log format [
                "[PERSISTENCE] GRUPPE BESIEGT: %1",
                _groupID
            ];

            [] call TAG_fnc_saveCampaign;

            ["trackDestroyedGroups", format [
                "Besiegte Gruppe gespeichert | ID=%1",
                _groupID
            ]] call TAG_fnc_debugLog;
        };
    }
];

["trackDestroyedGroups", format [
    "Ereignisbasierte Gruppenüberwachung registriert | Gruppen=%1",
    count TAG_PersistentGroups
]] call TAG_fnc_debugLog;
