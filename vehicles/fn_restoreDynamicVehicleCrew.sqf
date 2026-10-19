
/*
    Author: Djinn

    Description:
    Stellt die gespeicherte Besatzung dynamischer Fahrzeuge wieder her.

    Voraussetzungen:
    - Dynamische Gruppen und Einheiten wurden wiederhergestellt.
    - Dynamische Fahrzeuge wurden wiederhergestellt.
    - Fahrzeugzustände und zerstörte Fahrzeuge wurden angewendet.

    Verhalten:
    - Einheiten werden anhand ihrer TAG_DynamicUnitUID gefunden.
    - Gespeicherte Rollen und Sitzplätze werden wiederhergestellt.
    - Nicht mehr gespeicherte Besatzungsmitglieder werden aus
      dynamischen Fahrzeugen entfernt.
    - Für ausgestiegene dynamische Einheiten wird, sofern vorhanden,
      die gespeicherte Weltposition erneut angewendet.
    - Keine neue Besatzung wird erzeugt.
    - Editor- und Spielerfahrzeuge bleiben unberührt.
*/

if (!isServer) exitWith {};

if (isNil "TAG_SaveData") exitWith {
    diag_log "[PERSISTENCE] FEHLER: TAG_SaveData fehlt.";
};

if (isNil "TAG_PersistentVehicles") exitWith {
    diag_log "[PERSISTENCE] FEHLER: TAG_PersistentVehicles fehlt.";
};


// Gespeicherte Zustände laden.

private _vehicleStates = TAG_SaveData getOrDefault [
    "Vehicles",
    createHashMap
];

private _destroyedVehicles = TAG_SaveData getOrDefault [
    "DestroyedVehicles",
    []
];

private _savedGroups = TAG_SaveData getOrDefault [
    "DynamicGroups",
    createHashMap
];


// Gespeicherte Einheitenpositionen anhand ihrer UnitID ablegen.
// Diese Positionen werden benötigt, wenn eine Einheit beim
// Missionsstart noch im Fahrzeug sitzt, obwohl sie beim letzten
// Speichern bereits ausgestiegen war.

private _savedUnitRecords = createHashMap;

{
    private _groupData = _y;

    if (_groupData isEqualType createHashMap) then {

        private _unitRecords = _groupData getOrDefault [
            "Units",
            []
        ];

        {
            private _unitRecord = _x;

            if (_unitRecord isEqualType createHashMap) then {

                private _unitID = _unitRecord getOrDefault [
                    "UnitID",
                    ""
                ];

                private _position = _unitRecord getOrDefault [
                    "Position",
                    []
                ];

                if (
                    _unitID isEqualType ""
                    && { !(_unitID isEqualTo "") }
                    && {
                        _position isEqualType []
                    }
                    && {
                        count _position >= 3
                    }
                ) then {

                    _savedUnitRecords set [
                        _unitID,
                        _unitRecord
                    ];
                };
            };

        } forEach _unitRecords;
    };

} forEach _savedGroups;


// Die aktuell vorhandenen Einheiten einmal erfassen.

private _allUnits = allUnits;


// Vorbereitete dynamische Fahrzeuge und ihre Besatzung.

private _crewSnapshots = createHashMap;

// Alle UnitIDs, die laut Spielstand zu einem dynamischen
// Fahrzeug gehören.

private _allSavedCrewIDs = [];

// Einzelne Zuordnungen:
// [FahrzeugID, Fahrzeugobjekt, UnitID, Besatzungsdatensatz]

private _crewAssignments = [];

private _snapshotCount = 0;


// -----------------------------------------------------
// Gespeicherte Besatzungszuordnungen einlesen
// -----------------------------------------------------

{
    private _vehicleID = _x;
    private _state = _y;


    // Ausschließlich dynamische Fahrzeuge berücksichtigen.

    private _isDynamicVehicle = (
        _vehicleID isEqualType ""
        && {
            (count _vehicleID) >= 7
        }
        && {
            (_vehicleID select [0, 7]) isEqualTo "DYNVEH_"
        }
    );

    if (_isDynamicVehicle) then {

        // Zerstörte Fahrzeuge bekommen keine Besatzung zugewiesen.

        if !(_vehicleID in _destroyedVehicles) then {

            if (_state isEqualType createHashMap) then {

                // Fehlt das Feld vollständig, liegt kein expliziter
                // Sitzplatz-Snapshot vor. Das Fahrzeug unverändert lassen.

                if (isNil { _state get "Crew" }) then {

                    [
                        "restoreDynamicVehicleCrew",
                        format [
                            "Keine Besatzungsdaten vorhanden | Fahrzeug=%1",
                            _vehicleID
                        ]
                    ] call TAG_fnc_debugLog;

                } else {

                    private _savedCrew = _state get "Crew";

                    if !(_savedCrew isEqualType []) then {

                        diag_log format [
                            "[PERSISTENCE] WARNUNG: Ungültige Besatzungsdaten | Fahrzeug=%1",
                            _vehicleID
                        ];

                    } else {

                        private _vehicle = TAG_PersistentVehicles getOrDefault [
                            _vehicleID,
                            objNull
                        ];

                        if (isNull _vehicle) then {

                            diag_log format [
                                "[PERSISTENCE] WARNUNG: Fahrzeug für Besatzungswiederherstellung fehlt | ID=%1",
                                _vehicleID
                            ];

                        } else {

                            private _vehicleCrewIDs = [];


                            {
                                private _crewRecord = _x;

                                if (_crewRecord isEqualType createHashMap) then {

                                    private _unitID = _crewRecord getOrDefault [
                                        "UnitID",
                                        ""
                                    ];

                                    if (
                                        _unitID isEqualType ""
                                        && { !(_unitID isEqualTo "") }
                                    ) then {

                                        _vehicleCrewIDs pushBackUnique _unitID;
                                        _allSavedCrewIDs pushBackUnique _unitID;

                                        _crewAssignments pushBack [
                                            _vehicleID,
                                            _vehicle,
                                            _unitID,
                                            _crewRecord
                                        ];
                                    };

                                } else {

                                    diag_log format [
                                        "[PERSISTENCE] WARNUNG: Ungültiger Besatzungsdatensatz | Fahrzeug=%1",
                                        _vehicleID
                                    ];
                                };

                            } forEach _savedCrew;


                            _crewSnapshots set [
                                _vehicleID,
                                [
                                    _vehicle,
                                    _vehicleCrewIDs
                                ]
                            ];

                            _snapshotCount = _snapshotCount + 1;


                            [
                                "restoreDynamicVehicleCrew",
                                format [
                                    "Besatzungsdaten geladen | Fahrzeug=%1 | Mitglieder=%2",
                                    _vehicleID,
                                    count _vehicleCrewIDs
                                ]
                            ] call TAG_fnc_debugLog;
                        };
                    };
                };
            };
        };
    };

} forEach _vehicleStates;


// -----------------------------------------------------
// Nicht gespeicherte KI-Besatzungen aus den Fahrzeugen lösen
// -----------------------------------------------------

{
    private _vehicleID = _x;
    private _snapshot = _y;

    _snapshot params [
        "_vehicle",
        "_vehicleCrewIDs"
    ];


    {
        private _currentUnit = _x select 0;

        if (
            !isNull _currentUnit
            && { !isPlayer _currentUnit }
        ) then {

            private _currentUnitID = _currentUnit getVariable [
                "TAG_DynamicUnitUID",
                ""
            ];


            // Gehört die Einheit zu einer anderen gespeicherten
            // Fahrzeugbesatzung, wird sie erst später umgesetzt.

            if !(_currentUnitID in _allSavedCrewIDs) then {

                if (local _currentUnit) then {

                    moveOut _currentUnit;


                    // Die zuletzt gespeicherte Position der Einheit
                    // wieder anwenden, falls eine UnitID existiert.

                    if (
                        _currentUnitID isEqualType ""
                        && { !(_currentUnitID isEqualTo "") }
                    ) then {

                        private _unitRecord = _savedUnitRecords getOrDefault [
                            _currentUnitID,
                            createHashMap
                        ];

                        if (
                            _unitRecord isEqualType createHashMap
                            && { count _unitRecord > 0 }
                        ) then {

                            private _position = _unitRecord getOrDefault [
                                "Position",
                                []
                            ];

                            private _vectorDir = _unitRecord getOrDefault [
                                "VectorDir",
                                []
                            ];

                            private _vectorUp = _unitRecord getOrDefault [
                                "VectorUp",
                                []
                            ];

                            if (
                                _position isEqualType []
                                && { count _position >= 3 }
                            ) then {
                                _currentUnit setPosWorld _position;
                            };

                            if (
                                _vectorDir isEqualType []
                                && { count _vectorDir isEqualTo 3 }
                                && {
                                    _vectorUp isEqualType []
                                }
                                && {
                                    count _vectorUp isEqualTo 3
                                }
                            ) then {

                                _currentUnit setVectorDirAndUp [
                                    _vectorDir,
                                    _vectorUp
                                ];
                            };
                        };
                    };


                    [
                        "restoreDynamicVehicleCrew",
                        format [
                            "Nicht gespeichertes Besatzungsmitglied ausgestiegen | Fahrzeug=%1 | UnitID=%2",
                            _vehicleID,
                            _currentUnitID
                        ]
                    ] call TAG_fnc_debugLog;

                } else {

                    diag_log format [
                        "[PERSISTENCE] WARNUNG: Besatzungsmitglied nicht lokal; Aussteigen nicht ausgeführt | Fahrzeug=%1 | Einheit=%2",
                        _vehicleID,
                        _currentUnit
                    ];
                };
            };
        };

    } forEach (fullCrew [_vehicle, "", false]);

} forEach _crewSnapshots;


// -----------------------------------------------------
// Alle wiederzufindenden Besatzungsmitglieder zunächst lösen
// -----------------------------------------------------

// Erst alle Plätze freigeben, damit die Zuordnung nicht von der
// Reihenfolge der Fahrzeuge oder Einheiten abhängt.

private _resolvedAssignments = [];

{
    _x params [
        "_vehicleID",
        "_vehicle",
        "_unitID",
        "_crewRecord"
    ];


    private _unitIndex = _allUnits findIf {
        (_x getVariable [
            "TAG_DynamicUnitUID",
            ""
        ]) isEqualTo _unitID
    };


    if (_unitIndex < 0) then {

        diag_log format [
            "[PERSISTENCE] WARNUNG: Besatzungsmitglied nicht gefunden | Fahrzeug=%1 | UnitID=%2",
            _vehicleID,
            _unitID
        ];

    } else {

        private _unit = _allUnits select _unitIndex;

        if (isPlayer _unit) then {

            diag_log format [
                "[PERSISTENCE] WARNUNG: Spieler nicht als dynamische KI-Besatzung eingesetzt | Fahrzeug=%1 | UnitID=%2",
                _vehicleID,
                _unitID
            ];

        } else {

            if (!local _unit) then {

                diag_log format [
                    "[PERSISTENCE] WARNUNG: Besatzungsmitglied nicht lokal | Fahrzeug=%1 | UnitID=%2",
                    _vehicleID,
                    _unitID
                ];

            } else {

                _resolvedAssignments pushBack [
                    _vehicleID,
                    _vehicle,
                    _unit,
                    _crewRecord
                ];
            };
        };
    };

} forEach _crewAssignments;


// Vor der Neuzuordnung alle gefundenen Einheiten aus
// ihren bisherigen Fahrzeugen lösen.

{
    private _unit = _x select 2;

    if (vehicle _unit != _unit) then {
        moveOut _unit;
    };

} forEach _resolvedAssignments;


// -----------------------------------------------------
// Gespeicherte Sitzplätze wiederherstellen
// -----------------------------------------------------

private _restoredSeats = 0;
private _failedSeats = 0;


{
    _x params [
        "_vehicleID",
        "_vehicle",
        "_unit",
        "_crewRecord"
    ];


    private _role = toLower (
        _crewRecord getOrDefault [
            "Role",
            ""
        ]
    );

    private _cargoIndex = _crewRecord getOrDefault [
        "CargoIndex",
        -1
    ];

    private _turretPath = _crewRecord getOrDefault [
        "TurretPath",
        []
    ];

    private _personTurret = _crewRecord getOrDefault [
        "PersonTurret",
        false
    ];


    private _seatCommandIssued = false;


    // Fahrer- und Cargo-Plätze haben eigene Befehle.
    // Bei Turmplätzen verwenden wir den gespeicherten Turmpfad.

    switch (_role) do {

        case "driver": {

            _unit moveInDriver _vehicle;

            _seatCommandIssued = true;
        };


        case "cargo": {

            if (
                _cargoIndex isEqualType 0
                && { _cargoIndex >= 0 }
            ) then {

                // Kein automatisches Ausweichen auf einen anderen Platz.

                _unit moveInCargo [
                    _vehicle,
                    _cargoIndex,
                    false
                ];

                _seatCommandIssued = true;
            };
        };


        default {

            if (
                _turretPath isEqualType []
                && { count _turretPath > 0 }
            ) then {

                _unit moveInTurret [
                    _vehicle,
                    _turretPath
                ];

                _seatCommandIssued = true;

            } else {

                // Fallback für Fahrzeugklassen, die ihre primäre
                // Schützen- oder Kommandantenposition ohne Turmpfad melden.

                switch (_role) do {

                    case "gunner": {

                        _unit moveInGunner _vehicle;

                        _seatCommandIssued = true;
                    };

                    case "commander": {

                        _unit moveInCommander _vehicle;

                        _seatCommandIssued = true;
                    };
                };
            };
        };
    };


    if (!_seatCommandIssued) then {

        _failedSeats = _failedSeats + 1;

        diag_log format [
            "[PERSISTENCE] WARNUNG: Keine gültige Sitzplatzzuweisung möglich | Fahrzeug=%1 | UnitID=%2 | Rolle=%3 | CargoIndex=%4 | TurretPath=%5",
            _vehicleID,
            _unit getVariable [
                "TAG_DynamicUnitUID",
                ""
            ],
            _role,
            _cargoIndex,
            _turretPath
        ];

    } else {

        // Die tatsächliche Sitzposition kontrollieren.

        private _actualCrew = fullCrew [
            _vehicle,
            "",
            false
        ];

        private _actualIndex = _actualCrew findIf {
            (_x select 0) isEqualTo _unit
        };

        private _seatMatches = false;


        if (_actualIndex >= 0) then {

            private _actualSeat = _actualCrew select _actualIndex;

            private _actualRole = toLower (
                _actualSeat select 1
            );

            private _actualCargoIndex = _actualSeat select 2;
            private _actualTurretPath = _actualSeat select 3;
            private _actualPersonTurret = _actualSeat select 4;


            switch (_role) do {

                case "driver": {

                    _seatMatches = (
                        _actualRole isEqualTo "driver"
                    );
                };


                case "cargo": {

                    _seatMatches = (
                        _actualRole isEqualTo "cargo"
                        && {
                            _actualCargoIndex isEqualTo _cargoIndex
                        }
                        && {
                            _actualPersonTurret isEqualTo _personTurret
                        }
                    );
                };


                default {

                    _seatMatches = (
                        _actualTurretPath isEqualTo _turretPath
                        && {
                            _actualPersonTurret isEqualTo _personTurret
                        }
                    );
                };
            };
        };


        if (_seatMatches) then {

            _restoredSeats = _restoredSeats + 1;

            [
                "restoreDynamicVehicleCrew",
                format [
                    "Besatzungsplatz wiederhergestellt | Fahrzeug=%1 | UnitID=%2 | Rolle=%3 | CargoIndex=%4 | TurretPath=%5",
                    _vehicleID,
                    _unit getVariable [
                        "TAG_DynamicUnitUID",
                        ""
                    ],
                    _role,
                    _cargoIndex,
                    _turretPath
                ]
            ] call TAG_fnc_debugLog;

        } else {

            _failedSeats = _failedSeats + 1;

            diag_log format [
                "[PERSISTENCE] WARNUNG: Sitzplatz konnte nicht bestätigt werden | Fahrzeug=%1 | UnitID=%2 | SollRolle=%3 | SollCargoIndex=%4 | SollTurretPath=%5 | IstBesatzung=%6",
                _vehicleID,
                _unit getVariable [
                    "TAG_DynamicUnitUID",
                    ""
                ],
                _role,
                _cargoIndex,
                _turretPath,
                str (fullCrew [_vehicle, "", false])
            ];
        };
    };

} forEach _resolvedAssignments;


// Abschlussdiagnose.

[
    "restoreDynamicVehicleCrew",
    format [
        "Besatzungswiederherstellung abgeschlossen | Fahrzeuge=%1 | Zuweisungen=%2 | BestätigteSitzplätze=%3 | Fehler=%4",
        count _crewSnapshots,
        count _resolvedAssignments,
        _restoredSeats,
        _failedSeats
    ]
] call TAG_fnc_debugLog;
