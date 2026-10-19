
/*
    Author: Djinn
    Description:
        Prüft eine Wiederherstellungsanfrage und übermittelt den
        gespeicherten Spielerzustand an den zuständigen Client.

        Beim ersten Beitritt werden Position und Ausrichtung aus
        der dauerhaften Sicherung wiederhergestellt.

        Beim Respawn bleibt die vom Missionssystem festgelegte
        Spawnposition erhalten.

        TAG_RestoreLoadoutOnRespawn = true:
            Temporäres Death-Loadout verwenden, sofern vorhanden.

        TAG_RestoreLoadoutOnRespawn = false:
            Ausschließlich das dauerhaft gespeicherte Loadout verwenden.

        Das temporäre Death-Loadout wird niemals in TAG_SaveData
        übernommen.
*/

if (!isServer) exitWith {};

params [
    ["_unit", objNull, [objNull]],
    ["_roleId", "", [""]]
];

// ------------------------------------------------------------
// 1. Grundlegende Validierung
// ------------------------------------------------------------

if (isNull _unit) exitWith {
    diag_log "[PERSISTENCE] FEHLER: Restore-Anfrage ohne gültige Einheit.";
};

private _remoteOwner = remoteExecutedOwner;

// Bei Remote-Aufrufen darf ein Client nur seine eigene Einheit anfragen.
if (
    _remoteOwner > 0
    && {owner _unit != _remoteOwner}
) exitWith {
    diag_log format [
        "[PERSISTENCE] WARNUNG: Restore-Anfrage abgelehnt | Rolle=%1 | RemoteOwner=%2 | UnitOwner=%3",
        _roleId,
        _remoteOwner,
        owner _unit
    ];
};

// Rollenname muss zur Einheit passen.
if !(_roleId isEqualTo vehicleVarName _unit) exitWith {
    diag_log format [
        "[PERSISTENCE] WARNUNG: Rollenname stimmt nicht mit Einheit überein | Angefragt=%1 | Einheit=%2",
        _roleId,
        vehicleVarName _unit
    ];
};

// Nur persistente Spielerrollen zulassen.
if !((_roleId find "player_") isEqualTo 0) exitWith {
    diag_log format [
        "[PERSISTENCE] WARNUNG: Ungültige persistente Rollenkennung | Rolle=%1",
        _roleId
    ];
};

// ------------------------------------------------------------
// 2. Registrierung prüfen und Respawn erkennen
// ------------------------------------------------------------

private _registeredUnit = TAG_PersistentPlayers getOrDefault [
    _roleId,
    objNull
];

if (isNull _registeredUnit) exitWith {
    diag_log format [
        "[PERSISTENCE] WARNUNG: Rolle ist nicht registriert | Rolle=%1",
        _roleId
    ];
};

// WICHTIG:
// Die Respawn-Erkennung muss vor der Aktualisierung erfolgen.
// Ist bereits eine andere Einheit registriert, wurde die
// ursprüngliche Spielereinheit durch den Respawn ersetzt.
private _isRespawn = !(_registeredUnit isEqualTo _unit);

private _registrationValid = true;

if (_isRespawn) then {

    private _validNewUnit =
        isPlayer _unit
        && {
            _remoteOwner isEqualTo 0
            || {owner _unit isEqualTo _remoteOwner}
        };

    if (_validNewUnit) then {

        TAG_PersistentPlayers set [
            _roleId,
            _unit
        ];

        ["requestRestorePlayer", format [
            "Registrierte Einheit nach Respawn aktualisiert | Rolle=%1",
            _roleId
        ]] call TAG_fnc_debugLog;

    } else {

        _registrationValid = false;

        diag_log format [
            "[PERSISTENCE] WARNUNG: Neue Rolleneinheit abgelehnt | Rolle=%1 | Einheit=%2",
            _roleId,
            _unit
        ];
    };
};

if (!_registrationValid) exitWith {
    diag_log format [
        "[PERSISTENCE] WARNUNG: Wiederherstellung abgebrochen | Rolle=%1",
        _roleId
    ];
};

// Position nur beim ersten Beitritt wiederherstellen.
// Beim Respawn bleibt der Spawnpunkt der Mission erhalten.
private _restorePosition = !_isRespawn;

// ------------------------------------------------------------
// 3. Dauerhaften Spielerzustand abrufen
// ------------------------------------------------------------

private _players = TAG_SaveData getOrDefault [
    "Players",
    createHashMap
];

if !(_roleId in _players) exitWith {
    diag_log format [
        "[PERSISTENCE] FEHLER: Kein gespeicherter Spielerzustand vorhanden | Rolle=%1",
        _roleId
    ];
};

private _state = _players get _roleId;

private _position = _state getOrDefault [
    "Position",
    []
];

private _vectorDirAndUp = _state getOrDefault [
    "VectorDirAndUp",
    []
];

private _persistentLoadout = _state getOrDefault [
    "Loadout",
    []
];

// Positionsdaten nur prüfen, wenn sie tatsächlich angewendet werden.
if (
    _restorePosition
    && {
        count _position != 3
        || {count _vectorDirAndUp != 2}
    }
) exitWith {
    diag_log format [
        "[PERSISTENCE] FEHLER: Gespeicherte Position oder Ausrichtung ungültig | Rolle=%1",
        _roleId
    ];
};

if !(_persistentLoadout isEqualType []) exitWith {
    diag_log format [
        "[PERSISTENCE] FEHLER: Dauerhaftes Loadout hat einen ungültigen Datentyp | Rolle=%1",
        _roleId
    ];
};

if (_persistentLoadout isEqualTo []) exitWith {
    diag_log format [
        "[PERSISTENCE] FEHLER: Kein dauerhaftes Loadout vorhanden | Rolle=%1",
        _roleId
    ];
};

// ------------------------------------------------------------
// 4. Zu verwendendes Loadout auswählen
// ------------------------------------------------------------

// Standardmäßig immer das dauerhaft gespeicherte Loadout verwenden.
private _loadout = _persistentLoadout;

private _restoreDeathLoadout = missionNamespace getVariable [
    "TAG_RestoreLoadoutOnRespawn",
    false
];

private _deathLoadouts = missionNamespace getVariable [
    "TAG_DeathLoadouts",
    createHashMap
];

private _usedDeathLoadout = false;

// Das temporäre Death-Loadout darf nur verwendet werden,
// wenn die Wiederherstellung beim Respawn aktiviert ist.
if (_restoreDeathLoadout) then {

    if (_roleId in _deathLoadouts) then {

        private _deathLoadout = _deathLoadouts get _roleId;

        if (
            _deathLoadout isEqualType []
            && {!(_deathLoadout isEqualTo [])}
        ) then {

            _loadout = _deathLoadout;
            _usedDeathLoadout = true;

            ["requestRestorePlayer", format [
                "Temporäres Death-Loadout wird angewendet | Rolle=%1",
                _roleId
            ]] call TAG_fnc_debugLog;

        } else {

            diag_log format [
                "[PERSISTENCE] WARNUNG: Temporäres Death-Loadout ungültig | Dauerhaftes Loadout wird verwendet | Rolle=%1",
                _roleId
            ];
        };

    } else {

        ["requestRestorePlayer", format [
            "Kein temporäres Death-Loadout vorhanden | Dauerhaftes Loadout wird verwendet | Rolle=%1",
            _roleId
        ]] call TAG_fnc_debugLog;
    };

} else {

    ["requestRestorePlayer", format [
        "Death-Loadout-Wiederherstellung deaktiviert | Dauerhaftes Loadout wird verwendet | Rolle=%1",
        _roleId
    ]] call TAG_fnc_debugLog;
};

// ------------------------------------------------------------
// 5. Wiederherstellung an den zuständigen Client übermitteln
// ------------------------------------------------------------

private _args = [
    _unit,
    _position,
    _vectorDirAndUp,
    _loadout,
    _restorePosition
];

// Beim lokal gesteuerten Host-Spieler direkt ausführen.
if (local _unit && {hasInterface}) then {

    _args call TAG_fnc_restorePlayer;

} else {

    _args remoteExecCall [
        "TAG_fnc_restorePlayer",
        owner _unit
    ];
};

["requestRestorePlayer", format [
    "Wiederherstellung ausgelöst | Rolle=%1 | Respawn=%2 | PositionWiederherstellen=%3 | DeathLoadoutVerwendet=%4",
    _roleId,
    _isRespawn,
    _restorePosition,
    _usedDeathLoadout
]] call TAG_fnc_debugLog;
