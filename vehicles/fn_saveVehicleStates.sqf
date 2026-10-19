/*
    Author: Djinn
    Description: Speichert den Zustand registrierter Fahrzeuge.
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
        && {alive _vehicle}
        && {!(_id in _destroyed)}
    ) then {

        // Trefferpunkt-Schaden speichern
        private _hitPointData = [];
        private _hitPoints = getAllHitPointsDamage _vehicle;

        if !(_hitPoints isEqualTo []) then {
            private _names = _hitPoints select 0;
            private _damages = _hitPoints select 2;

            {
                _hitPointData pushBack [
                    _x,
                    _damages select _forEachIndex
                ];
            } forEach _names;
        };

        // Turmmunition auslesen
        private _turretMagazines = magazinesAllTurrets [
            _vehicle,
            true
        ];

        ["saveVehicleStates", format [
            "Fahrzeug=%1 | Klasse=%2 | Turmmagazine Rohdaten=%3",
            _id,
            typeOf _vehicle,
            _turretMagazines
        ]] call TAG_fnc_debugLog;

        {
            ["saveVehicleStates", format [
                "Turmmagazin | Fahrzeug=%1 | Magazin=%2 | Turmpfad=%3 | Restmunition=%4",
                _id,
                _x param [0, "UNBEKANNT"],
                _x param [1, []],
                _x param [2, -1]
            ]] call TAG_fnc_debugLog;
        } forEach _turretMagazines;

        // Pylonenmunition auslesen
        private _pylonMagazines = [];
        private _pylonClasses = getPylonMagazines _vehicle;

        {
            private _pylonIndex = _forEachIndex + 1;
            private _ammoCount = _vehicle ammoOnPylon _pylonIndex;

            _pylonMagazines pushBack [
                _pylonIndex,
                _x,
                _ammoCount
            ];

            ["saveVehicleStates", format [
                "Pylon | Fahrzeug=%1 | Index=%2 | Magazin=%3 | Restmunition=%4",
                _id,
                _pylonIndex,
                _x,
                _ammoCount
            ]] call TAG_fnc_debugLog;

        } forEach _pylonClasses;

        // Fahrzeugzustand zusammenstellen
        private _state = createHashMapFromArray [
            ["Class", typeOf _vehicle],
            ["Position", getPosATL _vehicle],
            ["VectorDirAndUp", [vectorDir _vehicle, vectorUp _vehicle]],
            ["Damage", damage _vehicle],
            ["HitPoints", _hitPointData],
            ["Fuel", fuel _vehicle],
            ["TurretMagazines", _turretMagazines],
            ["PylonMagazines", _pylonMagazines],
            ["WeaponCargo", getWeaponCargo _vehicle],
            ["MagazineCargo", getMagazineCargo _vehicle],
            ["ItemCargo", getItemCargo _vehicle],
            ["BackpackCargo", getBackpackCargo _vehicle]
        ];
        
        // Besatzungszuordnung ausschließlich für dynamische Fahrzeuge speichern.

        if (
            _id isEqualType ""
            && { (count _id) >= 7 }
            && { (_id select [0, 7]) isEqualTo "DYNVEH_" }
        ) then {

            private _savedCrew = [];

            {
                _x params [
                    "_unit",
                    "_role",
                    "_cargoIndex",
                    "_turretPath",
                    "_personTurret"
                ];

                if (!isNull _unit) then {

                    private _unitID = _unit getVariable [
                        "TAG_DynamicUnitUID",
                        ""
                    ];

                    if (_unitID isEqualTo "") then {

                        diag_log format [
                            "[PERSISTENCE] WARNUNG: Besatzungsmitglied ohne dynamische UnitID | Fahrzeug=%1 | Einheit=%2 | Rolle=%3",
                            _id,
                            _unit,
                            _role
                        ];

                    } else {

                        _savedCrew pushBack (
                            createHashMapFromArray [
                                ["UnitID", _unitID],
                                ["Role", toLower _role],
                                ["CargoIndex", _cargoIndex],
                                ["TurretPath", _turretPath],
                                ["PersonTurret", _personTurret]
                            ]
                        );

                        [
                            "saveVehicleStates",
                            format [
                                "Besatzungsplatz gespeichert | Fahrzeug=%1 | UnitID=%2 | Rolle=%3 | CargoIndex=%4 | TurretPath=%5",
                                _id,
                                _unitID,
                                _role,
                                _cargoIndex,
                                _turretPath
                            ]
                        ] call TAG_fnc_debugLog;
                    };
                };

            } forEach (fullCrew [_vehicle, "", false]);


            // Auch eine leere Besatzung speichern:
            // Ausgestiegene Einheiten gelten beim Speichern nicht mehr
            // als Besatzung dieses Fahrzeugs.

            _state set [
                "Crew",
                _savedCrew
            ];


            [
                "saveVehicleStates",
                format [
                    "Besatzungszuordnung gespeichert | Fahrzeug=%1 | Mitglieder=%2",
                    _id,
                    count _savedCrew
                ]
            ] call TAG_fnc_debugLog;
        };

        _states set [_id, _state];

        ["saveVehicleStates", format [
            "GESPEICHERTER ZUSTAND | Fahrzeug=%1 | Turm=%2 | Pylonen=%3 | Trefferpunkte=%4",
            _id,
            _state get "TurretMagazines",
            _state get "PylonMagazines",
            _state get "HitPoints"
        ]] call TAG_fnc_debugLog;
    };
} forEach TAG_PersistentVehicles;

TAG_SaveData set ["Vehicles", _states];

[] call TAG_fnc_saveCampaign;

["saveVehicleStates", format [
    "Fahrzeugzustände gespeichert | Fahrzeuge in Zustands-Map: %1",
    count _states
]] call TAG_fnc_debugLog;