/*
    Author: Djinn
    Description: Stellt gespeicherte Fahrzeugzustände wieder her.
*/

if (!isServer) exitWith {};

if (isNil "TAG_PersistentVehicles") exitWith {
    diag_log "[PERSISTENCE] FEHLER: TAG_PersistentVehicles fehlt.";
};

if (isNil "TAG_SaveData") exitWith {
    diag_log "[PERSISTENCE] FEHLER: TAG_SaveData fehlt.";
};

private _destroyed = TAG_SaveData getOrDefault [
    "DestroyedVehicles",
    []
];

private _states = TAG_SaveData getOrDefault [
    "Vehicles",
    createHashMap
];

{
    private _id = _x;
    private _vehicle = _y;

    if (
        !isNull _vehicle
        && {!(_id in _destroyed)}
        && {_id in _states}
    ) then {

        private _state = _states get _id;

        // Position und Ausrichtung
        _vehicle setPosATL (_state get "Position");

        _vehicle setVectorDirAndUp (
            _state get "VectorDirAndUp"
        );

        // Gesamtschaden und einzelne Trefferpunkte
        _vehicle setDamage (_state get "Damage");

        {
            _vehicle setHitPointDamage _x;
        } forEach (_state getOrDefault ["HitPoints", []]);

        // Treibstoff
        _vehicle setFuel (_state get "Fuel");

        // Laderauminventar wiederherstellen
        clearWeaponCargoGlobal _vehicle;
        clearMagazineCargoGlobal _vehicle;
        clearItemCargoGlobal _vehicle;
        clearBackpackCargoGlobal _vehicle;

        private _cargo = _state getOrDefault [
            "WeaponCargo",
            [[], []]
        ];

        {
            _vehicle addWeaponCargoGlobal [
                _x,
                (_cargo select 1) select _forEachIndex
            ];
        } forEach (_cargo select 0);

        _cargo = _state getOrDefault [
            "MagazineCargo",
            [[], []]
        ];

        {
            _vehicle addMagazineCargoGlobal [
                _x,
                (_cargo select 1) select _forEachIndex
            ];
        } forEach (_cargo select 0);

        _cargo = _state getOrDefault [
            "ItemCargo",
            [[], []]
        ];

        {
            _vehicle addItemCargoGlobal [
                _x,
                (_cargo select 1) select _forEachIndex
            ];
        } forEach (_cargo select 0);

        _cargo = _state getOrDefault [
            "BackpackCargo",
            [[], []]
        ];

        {
            _vehicle addBackpackCargoGlobal [
                _x,
                (_cargo select 1) select _forEachIndex
            ];
        } forEach (_cargo select 0);

        // Turmmunition wiederherstellen
        private _turretMagazines = _state getOrDefault [
            "TurretMagazines",
            []
        ];

        private _turretPaths = [];

        {
            _turretPaths pushBackUnique (_x select 1);
        } forEach _turretMagazines;

        private _nonLocalIndex = _turretPaths findIf {
            !(_vehicle turretLocal _x)
        };

        if (_nonLocalIndex >= 0) then {

            diag_log format [
                "[PERSISTENCE] WARNUNG: Turmmunition nicht wiederhergestellt, Turm nicht lokal. Fahrzeug=%1 | Turm=%2",
                _id,
                _turretPaths select _nonLocalIndex
            ];

        } else {

            // Magazine der betroffenen Türme entfernen
            {
                _vehicle removeAllMagazinesTurret _x;
            } forEach _turretPaths;

            // Gespeicherte Magazine einzeln hinzufügen
            {
                _x params [
                    "_magazineClass",
                    "_turretPath",
                    "_ammoCount"
                ];

                _vehicle addMagazineTurret [
                    _magazineClass,
                    _turretPath,
                    _ammoCount
                ];

                ["applyVehicleStates", format [
                    "Turmmunition wiederhergestellt | Fahrzeug=%1 | Magazin=%2 | Turm=%3 | Munition=%4",
                    _id,
                    _magazineClass,
                    _turretPath,
                    _ammoCount
                ]] call TAG_fnc_debugLog;

            } forEach _turretMagazines;

            ["applyVehicleStates", format [
                "Turmmunition nach Wiederherstellung | Fahrzeug=%1 | Magazine=%2",
                _id,
                magazinesAllTurrets [_vehicle, true]
            ]] call TAG_fnc_debugLog;
        };

        // Pylonenmunition wiederherstellen
        private _pylonMagazines = _state getOrDefault [
            "PylonMagazines",
            []
        ];

        {
            _x params [
                "_pylonIndex",
                "_magazineClass",
                "_ammoCount"
            ];

            private _currentPylonMagazines = getPylonMagazines _vehicle;
            private _currentMagazine = _currentPylonMagazines param [
                _pylonIndex - 1,
                ""
            ];

            if (_currentMagazine isEqualTo _magazineClass) then {

                _vehicle setAmmoOnPylon [
                    _pylonIndex,
                    _ammoCount
                ];

                ["applyVehicleStates", format [
                    "Pylonenmunition wiederhergestellt | Fahrzeug=%1 | Pylon=%2 | Magazin=%3 | Munition=%4",
                    _id,
                    _pylonIndex,
                    _magazineClass,
                    _ammoCount
                ]] call TAG_fnc_debugLog;

            } else {

                diag_log format [
                    "[PERSISTENCE] WARNUNG: Pylon-Magazin stimmt nicht überein | Fahrzeug=%1 | Pylon=%2 | Gespeichert=%3 | Aktuell=%4",
                    _id,
                    _pylonIndex,
                    _magazineClass,
                    _currentMagazine
                ];
            };
        } forEach _pylonMagazines;

        ["applyVehicleStates", format [
            "Fahrzeugzustand wiederhergestellt | Fahrzeug=%1 | Schaden=%2 | Treibstoff=%3",
            _id,
            damage _vehicle,
            fuel _vehicle
        ]] call TAG_fnc_debugLog;
    };
} forEach TAG_PersistentVehicles;