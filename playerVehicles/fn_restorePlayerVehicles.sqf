/*
    Author: Djinn

    Description:
    Stellt gespeicherte Spielerfahrzeuge wieder her.
    Zerstörte Fahrzeuge ohne Respawn-Freigabe werden entfernt.

    Ausführung: Server
*/

if (!isServer) exitWith {};

if (isNil "TAG_PersistentPlayerVehicles") exitWith {
    diag_log "[PERSISTENCE][PVEH] FEHLER: TAG_PersistentPlayerVehicles fehlt.";
};

if (isNil "TAG_SaveData") exitWith {
    diag_log "[PERSISTENCE][PVEH] FEHLER: TAG_SaveData fehlt.";
};

private _states = TAG_SaveData getOrDefault [
    "PlayerVehicles",
    createHashMap
];

{
    private _id = _x;
    private _entry = _y;

    private _vehicle = _entry getOrDefault [
        "Vehicle",
        objNull
    ];

    if (isNull _vehicle) then {

        diag_log format [
            "[PERSISTENCE][PVEH] WARNUNG: Registriertes Fahrzeugobjekt fehlt | ID=%1",
            _id
        ];

    } else {

        private _state = _states getOrDefault [
            _id,
            createHashMap
        ];

        // Ohne gespeicherten Zustand das Editor-Fahrzeug beibehalten.
        if (count _state isEqualTo 0) then {

            ["restorePlayerVehicles", format [
                "Kein gespeicherter Zustand | ID=%1 | Editor-Zustand bleibt erhalten",
                _id
            ]] call TAG_fnc_debugLog;

        } else {

            private _status = _state getOrDefault [
                "Status",
                ""
            ];

            private _respawn = _state getOrDefault [
                "Respawn",
                _entry getOrDefault ["Respawn", false]
            ];

            // Zerstörtes Fahrzeug ohne Respawn-Freigabe als Wrack wiederherstellen.
            // Der bestehende Respawn-Zweig bleibt unverändert.
            if (
                _status isEqualTo "DESTROYED"
                && {!_respawn}
            ) then {

                private _position = _state getOrDefault [
                    "Position",
                    []
                ];

                private _vectors = _state getOrDefault [
                    "VectorDirAndUp",
                    []
                ];

                if (
                    count _position == 3
                    && {count _vectors == 2}
                ) then {

                    // Position und Ausrichtung des Wracks wiederherstellen.
                    _vehicle setPosATL _position;
                    _vehicle setVectorDirAndUp _vectors;

                    // ACE-Cook-off vor der Zerstörung deaktivieren.
                    _vehicle setVariable [
                        "ace_cookoff_enable",
                        false,
                        true
                    ];

                    // Direkt als Wrack herstellen, ohne Reparatur-Zwischenschritt.
                    _vehicle setDamage [1, false];

                    ["restorePlayerVehicles", format [
                        "Spielerfahrzeug als Wrack wiederhergestellt | ID=%1 | Position=%2 | Ausrichtung=%3",
                        _id,
                        _position,
                        _vectors
                    ]] call TAG_fnc_debugLog;

                } else {

                    diag_log format [
                        "[PERSISTENCE][PVEH] FEHLER: Wrackdaten unvollständig; Fahrzeug bleibt unverändert | ID=%1 | Position=%2 | Ausrichtung=%3",
                        _id,
                        _position,
                        _vectors
                    ];
                };

            } else {

                // Für eine Wiederherstellung müssen die Kerndaten existieren.
                private _position = _state getOrDefault [
                    "Position",
                    []
                ];

                private _vectors = _state getOrDefault [
                    "VectorDirAndUp",
                    []
                ];

                if (
                    !(_status in ["ACTIVE", "DESTROYED"])
                    || {count _position != 3}
                    || {count _vectors != 2}
                ) then {

                    diag_log format [
                        "[PERSISTENCE][PVEH] WARNUNG: Ungültiger oder unvollständiger Zustand; Fahrzeug bleibt unverändert | ID=%1 | Status=%2",
                        _id,
                        _status
                    ];

                } else {

                    // Fahrzeugposition und Ausrichtung wiederherstellen.
                    _vehicle setPosATL _position;
                    _vehicle setVectorDirAndUp _vectors;

                    // Schaden und Trefferpunkt-Schäden wiederherstellen.
                    _vehicle setDamage 0;

                    private _hitPoints = _state getOrDefault [
                        "HitPoints",
                        []
                    ];

                    {
                        _x params [
                            "_hitPointName",
                            "_hitPointDamage"
                        ];

                        _vehicle setHitPointDamage [
                            _hitPointName,
                            _hitPointDamage
                        ];
                    } forEach _hitPoints;

                    private _damage = _state getOrDefault [
                        "Damage",
                        0
                    ];

                    _vehicle setDamage _damage;

                    // Treibstoff wiederherstellen.
                    _vehicle setFuel (
                        _state getOrDefault [
                            "Fuel",
                            1
                        ]
                    );

                    // Turmmunition wiederherstellen.
                    private _turretMagazines = _state getOrDefault [
                        "TurretMagazines",
                        []
                    ];

                    ["restorePlayerVehicles", format [
                        "Gespeicherte Turmmunition | ID=%1 | Daten=%2",
                        _id,
                        str _turretMagazines
                    ]] call TAG_fnc_debugLog;

                    // Betroffene Turmpfade ermitteln.
                    private _turretPaths = [];

                    {
                        private _turretPath = _x select 1;

                        if !(_turretPath in _turretPaths) then {
                            _turretPaths pushBack _turretPath;
                        };
                    } forEach _turretMagazines;

                    // Magazine je Turm ersetzen.
                    {
                        private _turretPath = _x;

                        _vehicle removeAllMagazinesTurret _turretPath;

                        {
                            _x params [
                                "_magazineClass",
                                "_savedTurretPath",
                                "_ammoCount"
                            ];

                            if (_savedTurretPath isEqualTo _turretPath) then {
                                _vehicle addMagazineTurret [
                                    _magazineClass,
                                    _turretPath,
                                    _ammoCount
                                ];

                                ["restorePlayerVehicles", format [
                                    "Turmmagazin hinzugefügt | ID=%1 | Magazin=%2 | Turm=%3 | Munition=%4",
                                    _id,
                                    _magazineClass,
                                    _turretPath,
                                    _ammoCount
                                ]] call TAG_fnc_debugLog;
                            };
                        } forEach _turretMagazines;

                    } forEach _turretPaths;

                    // Tatsächlichen Zustand nach dem Hinzufügen protokollieren.
                    ["restorePlayerVehicles", format [
                        "Turmmunition nach Wiederherstellung | ID=%1 | Daten=%2",
                        _id,
                        str (magazinesAllTurrets [_vehicle, true])
                    ]] call TAG_fnc_debugLog;

                    // Pylonenmunition wiederherstellen.
                    private _pylonMagazines = _state getOrDefault [
                        "PylonMagazines",
                        []
                    ];

                    ["restorePlayerVehicles", format [
                        "Gespeicherte Pylonendaten | ID=%1 | Daten=%2",
                        _id,
                        str _pylonMagazines
                    ]] call TAG_fnc_debugLog;

                    {
                        _x params [
                            "_pylonIndex",
                            "_magazineClass",
                            "_ammoCount"
                        ];

                        // Pylon-Konfiguration und gespeicherten Munitionsstand setzen.
                        _vehicle setPylonLoadOut [
                            _pylonIndex,
                            _magazineClass,
                            true,
                            [_ammoCount, 1]
                        ];

                        ["restorePlayerVehicles", format [
                            "Pylon gesetzt | ID=%1 | Index=%2 | Magazin=%3 | Gespeicherte Munition=%4 | Tatsächlich=%5",
                            _id,
                            _pylonIndex,
                            _magazineClass,
                            _ammoCount,
                            _vehicle ammoOnPylon _pylonIndex
                        ]] call TAG_fnc_debugLog;

                    } forEach _pylonMagazines;

                    ["restorePlayerVehicles", format [
                        "Pylonen nach Wiederherstellung | ID=%1 | Magazine=%2",
                        _id,
                        str (getPylonMagazines _vehicle)
                    ]] call TAG_fnc_debugLog;

                    // Inventar wiederherstellen.
                    clearWeaponCargoGlobal _vehicle;
                    clearMagazineCargoGlobal _vehicle;
                    clearItemCargoGlobal _vehicle;
                    clearBackpackCargoGlobal _vehicle;

                    private _weaponCargo = _state getOrDefault [
                        "WeaponCargo",
                        [[], []]
                    ];

                    {
                        _vehicle addWeaponCargoGlobal [
                            _x,
                            (_weaponCargo select 1) select _forEachIndex
                        ];
                    } forEach (_weaponCargo select 0);

                    private _magazineCargo = _state getOrDefault [
                        "MagazineCargo",
                        [[], []]
                    ];

                    {
                        _vehicle addMagazineCargoGlobal [
                            _x,
                            (_magazineCargo select 1) select _forEachIndex
                        ];
                    } forEach (_magazineCargo select 0);

                    private _itemCargo = _state getOrDefault [
                        "ItemCargo",
                        [[], []]
                    ];

                    {
                        _vehicle addItemCargoGlobal [
                            _x,
                            (_itemCargo select 1) select _forEachIndex
                        ];
                    } forEach (_itemCargo select 0);

                    private _backpackCargo = _state getOrDefault [
                        "BackpackCargo",
                        [[], []]
                    ];

                    {
                        _vehicle addBackpackCargoGlobal [
                            _x,
                            (_backpackCargo select 1) select _forEachIndex
                        ];
                    } forEach (_backpackCargo select 0);

                    ["restorePlayerVehicles", format [
                        "Fahrzeug wiederhergestellt | ID=%1 | Status=%2 | Respawn=%3 | Position=%4",
                        _id,
                        _status,
                        _respawn,
                        _position
                    ]] call TAG_fnc_debugLog;
                };
            };
        };
    };
} forEach TAG_PersistentPlayerVehicles;

["restorePlayerVehicles", "Wiederherstellung abgeschlossen."] call TAG_fnc_debugLog;