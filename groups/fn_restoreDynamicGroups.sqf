
/*
    Author: Djinn

    Description:
    Rekonstruiert dynamische Gruppen aus dem Spielstand.

    Berücksichtigt:
    - Vernichtete Gruppen werden nicht wiederhergestellt.
    - Einheiten werden anhand der gespeicherten Klassen erzeugt
      oder passende vorhandene Einheiten werden wiederverwendet.
    - Position, Ausrichtung, Ausrüstung, Schaden, Trefferzonen,
      Rang und Skill werden wiederhergestellt.
    - Gruppenparameter und gespeicherte Wegpunkte werden gesetzt.
    - Die Gruppen werden unter ihrer gespeicherten ID in
      TAG_PersistentGroups und TAG_DynamicGroups registriert.
*/

if (!isServer) exitWith {};

if (isNil "TAG_SaveData") exitWith {
    diag_log "[PERSISTENCE] FEHLER: TAG_SaveData fehlt.";
};

if (isNil "TAG_DynamicGroups") exitWith {
    diag_log "[PERSISTENCE] FEHLER: TAG_DynamicGroups fehlt.";
};

if (isNil "TAG_PersistentGroups") exitWith {
    diag_log "[PERSISTENCE] FEHLER: TAG_PersistentGroups fehlt.";
};


private _savedGroups = TAG_SaveData getOrDefault [
    "DynamicGroups",
    createHashMap
];

private _destroyedGroups = TAG_SaveData getOrDefault [
    "DestroyedGroups",
    []
];


[
    "restoreDynamicGroups",
    format [
        "Wiederherstellung gestartet | Gespeicherte Gruppen=%1",
        count _savedGroups
    ]
] call TAG_fnc_debugLog;


// Hilfsfunktion zum Wiederherstellen eines Einheitenzustands.

/*
    Stellt den Zustand einer dynamischen Einheit wieder her.

    Die Einheiten werden grundsätzlich mit voller Gesundheit
    rekonstruiert. Gespeicherter Schaden und Trefferzonenschaden
    werden nicht übernommen.
*/

private _restoreUnitState = {
    params [
        "_unit",
        "_unitRecord"
    ];

    _unit setUnitLoadout (
        _unitRecord getOrDefault [
            "Loadout",
            getUnitLoadout _unit
        ]
    );

    _unit setRank (
        _unitRecord getOrDefault [
            "Rank",
            "PRIVATE"
        ]
    );

    _unit setSkill (
        _unitRecord getOrDefault [
            "Skill",
            0.5
        ]
    );

    // Unabhängig vom gespeicherten Zustand volle Gesundheit herstellen.

    _unit setDamage 0;

    // Gespeicherte Position und Ausrichtung wiederherstellen.

    _unit setPosWorld (
        _unitRecord getOrDefault [
            "Position",
            getPosWorld _unit
        ]
    );

    _unit setVectorDirAndUp [
        _unitRecord getOrDefault [
            "VectorDir",
            vectorDir _unit
        ],
        _unitRecord getOrDefault [
            "VectorUp",
            vectorUp _unit
        ]
    ];
};

// Gespeicherte Gruppen durchgehen.

{
    private _groupID = _x;
    private _groupData = _y;


    // Vernichtete Gruppen haben grundsätzlich Vorrang.

    if (_groupID in _destroyedGroups) then {

        [
            "restoreDynamicGroups",
            format [
                "Wiederherstellung übersprungen | ID=%1 | Grund=Gruppe vernichtet",
                _groupID
            ]
        ] call TAG_fnc_debugLog;

    } else {

        if !(_groupData isEqualType createHashMap) then {

            diag_log format [
                "[PERSISTENCE] WARNUNG: Ungültige Gruppendaten: %1",
                _groupID
            ];

        } else {

            private _unitRecords = _groupData getOrDefault [
                "Units",
                []
            ];

            if (_unitRecords isEqualTo []) then {

                diag_log format [
                    "[PERSISTENCE] WARNUNG: Keine Einheiten gespeichert | Gruppe=%1",
                    _groupID
                ];

            } else {

                // Vor einer Änderung prüfen, ob alle gespeicherten
                // Einheitenklassen verfügbar sind.

                private _validRecords = true;

                {
                    if !(_x isEqualType createHashMap) then {

                        _validRecords = false;

                    } else {

                        private _class = _x getOrDefault [
                            "Class",
                            ""
                        ];

                        if (
                            _class isEqualTo ""
                            || {
                                !isClass (
                                    configFile
                                    >> "CfgVehicles"
                                    >> _class
                                )
                            }
                        ) then {

                            _validRecords = false;

                            diag_log format [
                                "[PERSISTENCE] WARNUNG: Einheitenklasse nicht verfügbar | Gruppe=%1 | Klasse=%2",
                                _groupID,
                                _class
                            ];
                        };
                    };

                } forEach _unitRecords;


                if (!_validRecords) then {

                    diag_log format [
                        "[PERSISTENCE] WARNUNG: Gruppe nicht rekonstruiert | ID=%1 | Grund=Einheitenklassen fehlen oder sind ungültig",
                        _groupID
                    ];

                } else {

                    // Side aus dem gespeicherten Datensatz lesen.
                    // Bei ungültigem Wert wird sie aus der Gruppen-ID
                    // abgeleitet.

                    private _savedSide = _groupData getOrDefault [
                        "Side",
                        sideUnknown
                    ];

                    if (
                        !(_savedSide isEqualType west)
                        || { _savedSide isEqualTo sideUnknown }
                    ) then {

                        private _sidePrefix = (
                            _groupID splitString "_"
                        ) param [0, ""];

                        _savedSide = switch (_sidePrefix) do {
                            case "WEST": { west };
                            case "EAST": { east };
                            case "GUER": { independent };
                            case "RESISTANCE": { independent };
                            case "CIV": { civilian };
                            case "CIVILIAN": { civilian };
                            default { sideUnknown };
                        };
                    };


                    if (_savedSide isEqualTo sideUnknown) then {

                        diag_log format [
                            "[PERSISTENCE] WARNUNG: Ungültige Seite | Gruppe=%1",
                            _groupID
                        ];

                    } else {

                        // Eine bereits registrierte dynamische Gruppe
                        // mit passender ID bevorzugt wiederverwenden.

                        private _group = TAG_DynamicGroups getOrDefault [
                            _groupID,
                            grpNull
                        ];

                        if (isNull _group) then {

                            // Vorhandenen Unterdrückungszustand sichern.

                            private _wasSuppressed = missionNamespace getVariable [
                                "TAG_RegisterGroups_SuppressGroupCreated",
                                false
                            ];

                            missionNamespace setVariable [
                                "TAG_RegisterGroups_SuppressGroupCreated",
                                true
                            ];

                            _group = createGroup [
                                _savedSide,
                                false
                            ];

                            // Vorherigen Zustand wiederherstellen.

                            missionNamespace setVariable [
                                "TAG_RegisterGroups_SuppressGroupCreated",
                                _wasSuppressed
                            ];
                        };

                        if (isNull _group) then {

                            diag_log format [
                                "[PERSISTENCE] FEHLER: Gruppe konnte nicht erstellt werden | ID=%1",
                                _groupID
                            ];

                        } else {

                            // Gruppen mit Spielereinheiten nicht verändern.

                            private _hasPlayer = (units _group) findIf {
                                isPlayer _x
                            } >= 0;

                            if (_hasPlayer) then {

                                diag_log format [
                                    "[PERSISTENCE] WARNUNG: Gruppe nicht rekonstruiert | ID=%1 | Grund=Spielereinheit enthalten",
                                    _groupID
                                ];

                            } else {

                                // Die interne Framework-ID wiederherstellen.

                                private _previousID = format [
                                    "%1_%2",
                                    side _group,
                                    groupId _group
                                ];

                                private _groupName = _groupData getOrDefault [
                                    "GroupIDName",
                                    ""
                                ];

                                if (_groupName isEqualTo "") then {
                                    private _prefixLength = (
                                        count (
                                            (_groupID splitString "_") select 0
                                        )
                                    ) + 1;

                                    _groupName = _groupID select [
                                        _prefixLength
                                    ];
                                };

                                _group setGroupIdGlobal [
                                    _groupName
                                ];


                                // Temporären Registrierungsschlüssel
                                // entfernen, sofern er auf diese Gruppe zeigt.

                                if !(_previousID isEqualTo _groupID) then {

                                    if (
                                        (
                                            TAG_DynamicGroups getOrDefault [
                                                _previousID,
                                                grpNull
                                            ]
                                        ) isEqualTo _group
                                    ) then {
                                        TAG_DynamicGroups deleteAt _previousID;
                                    };

                                    if (
                                        (
                                            TAG_PersistentGroups getOrDefault [
                                                _previousID,
                                                grpNull
                                            ]
                                        ) isEqualTo _group
                                    ) then {
                                        TAG_PersistentGroups deleteAt _previousID;
                                    };
                                };


                                // Vorhandene Einheiten für den Abgleich erfassen.

                                private _usedUnitIDs = [];

                                {
                                    private _unitRecord = _x;

                                    private _unitUID = _unitRecord getOrDefault [
                                        "UnitID",
                                        ""
                                    ];

                                    if (_unitUID isEqualTo "") then {

                                        private _nextUID = _forEachIndex + 1;

                                        _unitUID = format [
                                            "%1_unit_%2",
                                            _groupID,
                                            _nextUID
                                        ];

                                        while { _unitUID in _usedUnitIDs } do {
                                            _nextUID = _nextUID + 1;

                                            _unitUID = format [
                                                "%1_unit_%2",
                                                _groupID,
                                                _nextUID
                                            ];
                                        };

                                        _unitRecord set [
                                            "UnitID",
                                            _unitUID
                                        ];
                                    };

                                    _usedUnitIDs pushBackUnique _unitUID;

                                } forEach _unitRecords;

                                private _existingUnits = +units _group;
                                private _unitsToDelete = +_existingUnits;
                                private _restoredUnits = [];


                                {
                                    private _unitRecord = _x;
                                    private _class = _unitRecord get "Class";
                                    private _unit = objNull;

                                    // Passende vorhandene Einheiten wiederverwenden.
                                    // Eine tote Einheit darf nicht als lebende
                                    // Einheit weiterverwendet werden.

                                    if (_forEachIndex < count _existingUnits) then {

                                        private _candidate = _existingUnits select _forEachIndex;

                                        if (
                                            (typeOf _candidate) isEqualTo _class
                                            && { alive _candidate }
                                        ) then {

                                            _unit = _candidate;

                                            private _deleteIndex =
                                                _unitsToDelete find _candidate;

                                            if (_deleteIndex >= 0) then {
                                                _unitsToDelete deleteAt _deleteIndex;
                                            };
                                        };
                                    };


                                    // Fehlende oder nicht passende Einheit
                                    // neu innerhalb derselben Gruppe erzeugen.

                                    // Fehlende oder nicht passende Einheit
                                    // neu innerhalb derselben Gruppe erzeugen.

                                    if (isNull _unit) then {

                                        private _position = _unitRecord getOrDefault [
                                            "Position",
                                            [0, 0, 0]
                                        ];

                                        _unit = _group createUnit [
                                            _class,
                                            _position,
                                            [],
                                            0,
                                            "CAN_COLLIDE"
                                        ];
                                    };


                                    // Kennung setzen und Einheitenzustand
                                    // wiederherstellen, sofern die Erzeugung
                                    // erfolgreich war.

                                    if (!isNull _unit) then {

                                        private _unitUID = _unitRecord getOrDefault [
                                            "UnitID",
                                            format [
                                                "%1_unit_%2",
                                                _groupID,
                                                _forEachIndex + 1
                                            ]
                                        ];

                                        _unitRecord set [
                                            "UnitID",
                                            _unitUID
                                        ];

                                        _unit setVariable [
                                            "TAG_DynamicUnitUID",
                                            _unitUID
                                        ];

                                        _unit setVariable [
                                            "TAG_DynamicGroupID",
                                            _groupID
                                        ];

                                        [
                                            _unit,
                                            _unitRecord
                                        ] call _restoreUnitState;

                                        _restoredUnits pushBack _unit;
                                    };

                                } forEach _unitRecords;


                                // Alte Einheiten erst entfernen, wenn
                                // alle gespeicherten Einheiten existieren.

                                if (
                                    (count _restoredUnits)
                                    isEqualTo
                                    (count _unitRecords)
                                ) then {

                                    {
                                        deleteVehicle _x;
                                    } forEach _unitsToDelete;

                                } else {

                                    diag_log format [
                                        "[PERSISTENCE] FEHLER: Nicht alle Einheiten wiederhergestellt | ID=%1 | Erwartet=%2 | Erstellt=%3",
                                        _groupID,
                                        count _unitRecords,
                                        count _restoredUnits
                                    ];
                                };


                                // Gruppenparameter wiederherstellen.

                                private _behaviour = _groupData getOrDefault [
                                    "Behaviour",
                                    "AWARE"
                                ];

                                if (
                                    _behaviour in [
                                        "CARELESS",
                                        "SAFE",
                                        "AWARE",
                                        "COMBAT",
                                        "STEALTH"
                                    ]
                                ) then {
                                    _group setBehaviourStrong _behaviour;
                                };

                                private _combatMode = _groupData getOrDefault [
                                    "CombatMode",
                                    "YELLOW"
                                ];

                                if (
                                    _combatMode in [
                                        "BLUE",
                                        "GREEN",
                                        "WHITE",
                                        "YELLOW",
                                        "RED"
                                    ]
                                ) then {
                                    _group setCombatMode _combatMode;
                                };

                                private _speedMode = _groupData getOrDefault [
                                    "SpeedMode",
                                    "NORMAL"
                                ];

                                if (
                                    _speedMode in [
                                        "LIMITED",
                                        "NORMAL",
                                        "FULL"
                                    ]
                                ) then {
                                    _group setSpeedMode _speedMode;
                                };

                                private _formation = _groupData getOrDefault [
                                    "Formation",
                                    "WEDGE"
                                ];

                                if (
                                    _formation in [
                                        "COLUMN",
                                        "STAG COLUMN",
                                        "WEDGE",
                                        "ECH LEFT",
                                        "ECH RIGHT",
                                        "VEE",
                                        "LINE",
                                        "FILE",
                                        "DIAMOND"
                                    ]
                                ) then {
                                    _group setFormation _formation;
                                };


                                // Vorhandene Wegpunkte entfernen und
                                // die gespeicherten Wegpunkte neu anlegen.

                                {
                                    deleteWaypoint _x;
                                } forEach (waypoints _group);


                                private _waypointRecords = _groupData getOrDefault [
                                    "Waypoints",
                                    []
                                ];

                                private _firstRestoredWaypoint = [];

                                {
                                    private _waypointRecord = _x;

                                    private _position = _waypointRecord getOrDefault [
                                        "Position",
                                        []
                                    ];

                                    if (
                                        _position isEqualType []
                                        && { count _position >= 2 }
                                    ) then {

                                        private _waypoint = _group addWaypoint [
                                            _position,
                                            0
                                        ];

                                        _waypoint setWPPos _position;

                                        private _type = _waypointRecord getOrDefault [
                                            "Type",
                                            "MOVE"
                                        ];

                                        if !(_type isEqualTo "") then {
                                            _waypoint setWaypointType _type;
                                        };

                                        _waypoint setWaypointBehaviour (
                                            _waypointRecord getOrDefault [
                                                "Behaviour",
                                                "UNCHANGED"
                                            ]
                                        );

                                        _waypoint setWaypointCombatMode (
                                            _waypointRecord getOrDefault [
                                                "CombatMode",
                                                "NO CHANGE"
                                            ]
                                        );

                                        _waypoint setWaypointSpeed (
                                            _waypointRecord getOrDefault [
                                                "Speed",
                                                "UNCHANGED"
                                            ]
                                        );

                                        _waypoint setWaypointFormation (
                                            _waypointRecord getOrDefault [
                                                "Formation",
                                                "NO CHANGE"
                                            ]
                                        );

                                        _waypoint setWaypointCompletionRadius (
                                            _waypointRecord getOrDefault [
                                                "CompletionRadius",
                                                0
                                            ]
                                        );

                                        private _timeout = _waypointRecord getOrDefault [
                                            "Timeout",
                                            [0, 0, 0]
                                        ];

                                        if (
                                            _timeout isEqualType []
                                            && { count _timeout isEqualTo 3 }
                                        ) then {
                                            _waypoint setWaypointTimeout _timeout;
                                        };

                                        private _statements = _waypointRecord getOrDefault [
                                            "Statements",
                                            ["true", ""]
                                        ];

                                        if (
                                            _statements isEqualType []
                                            && { count _statements isEqualTo 2 }
                                        ) then {
                                            _waypoint setWaypointStatements _statements;
                                        };

                                        if (_firstRestoredWaypoint isEqualTo []) then {
                                            _firstRestoredWaypoint = _waypoint;
                                        };
                                    };

                                } forEach _waypointRecords;


                                // Der erste gespeicherte Wegpunkt entspricht
                                // dem aktuellen oder dem nächsten offenen Wegpunkt.

                                if !(_firstRestoredWaypoint isEqualTo []) then {
                                    _group setCurrentWaypoint _firstRestoredWaypoint;
                                };


                                // Gruppe in beiden Laufzeit-HashMaps registrieren.

                                TAG_PersistentGroups set [
                                    _groupID,
                                    _group
                                ];

                                TAG_DynamicGroups set [
                                    _groupID,
                                    _group
                                ];
                                
                                diag_log format [
                                    "[PERSISTENCE][DYNAMIC GROUPS] Registrierung gesetzt | ID=%1 | Objektgruppe=%2 | DynamicGroups=%3 | Eintrag korrekt=%4",
                                    _groupID,
                                    groupId _group,
                                    str (keys TAG_DynamicGroups),
                                    (TAG_DynamicGroups getOrDefault [
                                        _groupID,
                                        grpNull
                                    ]) isEqualTo _group
                                ];

                                [
                                    "restoreDynamicGroups",
                                    format [
                                        "Dynamische Gruppe rekonstruiert | ID=%1 | Einheiten=%2 | Wegpunkte=%3",
                                        _groupID,
                                        count _restoredUnits,
                                        count _waypointRecords
                                    ]
                                ] call TAG_fnc_debugLog;
                            };
                        };
                    };
                };
            };
        };
    };

} forEach _savedGroups;


[
    "restoreDynamicGroups",
    format [
        "Registrierung nach Wiederherstellung | Anzahl=%1 | IDs=%2",
        count TAG_DynamicGroups,
        str (keys TAG_DynamicGroups)
    ]
] call TAG_fnc_debugLog;

[
    "restoreDynamicGroups",
    "Wiederherstellung abgeschlossen."
] call TAG_fnc_debugLog;
