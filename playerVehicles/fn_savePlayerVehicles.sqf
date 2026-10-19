/*
    Author: Djinn

    Description:
    Speichert den Zustand registrierter Spielerfahrzeuge
    getrennt von der normalen Fahrzeugpersistenz.

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

    private _respawn = _entry getOrDefault [
        "Respawn",
        false
    ];

    if (isNull _vehicle) then {

        // Warnungen bleiben unabhängig vom Debug-Schalter sichtbar.
        diag_log format [
            "[PERSISTENCE][PVEH] WARNUNG: Fahrzeugobjekt fehlt | ID=%1",
            _id
        ];

    } else {

        if (alive _vehicle) then {

            // Trefferpunkt-Schäden erfassen.
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

            // Turmmunition erfassen.
            private _turretMagazines = magazinesAllTurrets [
                _vehicle,
                true
            ];

            ["savePlayerVehicles", format [
                "Turmmunition erfasst | ID=%1 | Daten=%2",
                _id,
                str _turretMagazines
            ]] call TAG_fnc_debugLog;

            // Pylonenmunition erfassen.
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
            } forEach _pylonClasses;

            // Zustand des intakten Spielerfahrzeugs speichern.
            private _state = createHashMapFromArray [
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
                ["BackpackCargo", getBackpackCargo _vehicle],
                ["Respawn", _respawn],
                ["Status", "ACTIVE"]
            ];

            _states set [
                _id,
                _state
            ];

            ["savePlayerVehicles", format [
                "Fahrzeugzustand gespeichert | ID=%1 | Respawn=%2 | Status=ACTIVE | Schaden=%3 | Treibstoff=%4",
                _id,
                _respawn,
                damage _vehicle,
                fuel _vehicle
            ]] call TAG_fnc_debugLog;

        } else {

            // Zerstörungsstatus dauerhaft festhalten.
            // Die Position des tatsächlich zerstörten Fahrzeugs sichern.
            // Bereits gespeicherte Zustandsdaten bleiben erhalten.
            private _state = _states getOrDefault [
                _id,
                createHashMap
            ];

            _state set [
                "Position",
                getPosATL _vehicle
            ];

            _state set [
                "VectorDirAndUp",
                [
                    vectorDir _vehicle,
                    vectorUp _vehicle
                ]
            ];

            _state set [
                "Respawn",
                _respawn
            ];

            _state set [
                "Status",
                "DESTROYED"
            ];

            _states set [
                _id,
                _state
            ];

            ["savePlayerVehicles", format [
                "Fahrzeug zerstört | ID=%1 | Respawn=%2 | Position=%3 | Ausrichtung=%4",
                _id,
                _respawn,
                _state get "Position",
                _state get "VectorDirAndUp"
            ]] call TAG_fnc_debugLog;
        };
    };
} forEach TAG_PersistentPlayerVehicles;

TAG_SaveData set [
    "PlayerVehicles",
    _states
];

[] call TAG_fnc_saveCampaign;

["savePlayerVehicles", format [
    "Fahrzeugzustände gespeichert | Anzahl=%1",
    count _states
]] call TAG_fnc_debugLog;