/*
    Author: Djinn

    Description:
    Zentralisiert die lokale Initialisierung des
    Persistenzframeworks.

    Ausführung: Lokal beim Spieler
*/

params [
["_player", objNull],
["_didJIP", false]
];

if (!hasInterface) exitWith {};

diag_log format [
"[PERSISTENCE] Spielerinitialisierung gestartet | Spieler=%1 | JIP=%2 | Einheit=%3",
name _player,
_didJIP,
vehicleVarName _player
];

// Auf die vom Server veröffentlichte Debug-Konfiguration warten.
waitUntil {
    sleep 0.1;

    !isNil "TAG_DebugPersistence"
    && {!isNil "TAG_Debug_trackTaskStates"}
    && {!isNil "TAG_Debug_restoreTaskStates"}
    && {!isNil "TAG_Debug_initializePlayerPersistence"}
};

// Debug-Konfiguration lokal setzen.
// Die Konfigurationsfunktion muss dafür zwischen Server und Client
// unterscheiden und darf publicVariable nur auf dem Server ausführen.
[] call TAG_fnc_configurePersistenceDebug;

// Spielerzustand nach abgeschlossener Serverinitialisierung anfordern.
[] spawn {

    // Warten, bis die lokale Spielereinheit existiert.
    waitUntil {
        sleep 0.1;
        !isNull player
    };

    // Warten, bis der Server seine Persistenz initialisiert hat.
    waitUntil {
        sleep 0.1;
        !isNil "TAG_PersistenceReady"
        && {TAG_PersistenceReady}
    };

    private _unit = player;
    private _roleId = vehicleVarName _unit;

    if !((_roleId find "player_") isEqualTo 0) exitWith {
        diag_log format [
            "[PERSISTENCE] WARNUNG: Keine persistente Spielerrolle erkannt | Einheit=%1",
            _roleId
        ];
    };

    ["initializePlayerPersistence", format [
        "Spieler beigetreten | Rolle=%1 | Anfrage wird gesendet",
        _roleId
    ]] call TAG_fnc_debugLog;

    // Host-Spieler direkt behandeln, entfernte Clients fragen den Server.
    if (isServer) then {
        [_unit, _roleId] call TAG_fnc_requestRestorePlayer;
    } else {
        [_unit, _roleId] remoteExecCall [
            "TAG_fnc_requestRestorePlayer",
            2
        ];
    };
};

// Task-Tracking und Task-Wiederherstellung starten.
[] spawn TAG_fnc_trackTaskStates;
[] spawn TAG_fnc_restoreTaskStates;

// Diary Restore
[] spawn {
    sleep 45;

    waitUntil {
        sleep 0.25;
        !isNull player
    };

    [] remoteExecCall [
        "TAG_fnc_requestRestoreDiaryEntries",
        2
    ];
};


// Respawn-Ticketbestand nach einem Spieler-Respawn speichern.
[] spawn {

    // Warten, bis die Spielereinheit existiert.
    waitUntil {
        sleep 0.1;
        !isNull player
    };

    player addEventHandler ["Respawn", {

        params [
            "_newUnit",
            "_oldUnit"
        ];

        ["initializePlayerPersistence", format [
            "Respawn erkannt | Spieler=%1 | Warte auf Ticketabzug.",
            vehicleVarName _newUnit
        ]] call TAG_fnc_debugLog;

        // Arma den Respawn und Ticketabzug abschließen lassen.
        [] spawn {

            sleep 1;

            // Ticketbestand auf dem Server erfassen und speichern.
            if (isServer) then {

                [] call TAG_fnc_saveRespawnTickets;

            } else {

                [] remoteExecCall [
                    "TAG_fnc_saveRespawnTickets",
                    2
                ];
            };
        };
    }];

    ["initializePlayerPersistence", "Respawn-Handler für Tickets registriert."] call TAG_fnc_debugLog;
};