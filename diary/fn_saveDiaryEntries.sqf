
/*
    Author: Djinn

    Description:
    Fordert Diary-Daten aller Clients an und führt sie anhand
    ihres Geltungsbereichs zusammen.

    Speicherstruktur:
    TAG_SaveData
        └── DiaryEntries
            ├── PLAY:<Spielervariable>
            ├── GRP:<Gruppenrufzeichen>
            ├── SIDE:<Seite>
            └── ALL:ALL

    Datensatz:
    [
        Subject-ID,
        Subject-Titel,
        Subject-Bild,
        Eintragstitel,
        Beschreibung,
        Icon,
        Scope,
        ScopeKey,
        ScopeValid,
        RecordIndex
    ]

    Gemeinsame Einträge werden ergänzt, nicht durch einzelne
    Client-Snapshots ersetzt.

    Einheiten ohne bestätigten Diary-Restore dürfen ihren
    gespeicherten Stand nicht verändern.

    Ausführung: Server
*/

if (!isServer) exitWith {};

if (isNil "TAG_DiarySaveCounter") then {
    TAG_DiarySaveCounter = 0;
};

if (isNil "TAG_DiarySaveResponses") then {
    TAG_DiarySaveResponses = createHashMap;
};

if (isNil "TAG_SaveData") exitWith {
    diag_log "[PERSISTENCE][DIARY] FEHLER: TAG_SaveData nicht verfügbar.";
};

// -----------------------------------------------------
// Speicheranforderung vorbereiten
// -----------------------------------------------------

TAG_DiarySaveCounter = TAG_DiarySaveCounter + 1;
private _requestId = TAG_DiarySaveCounter;

private _expectedUnits = [];

{
    private _unitName = vehicleVarName _x;

    if !(_unitName isEqualTo "") then {
        _expectedUnits pushBackUnique _unitName;
    };
} forEach (allPlayers select {isPlayer _x});

private _responses = createHashMap;

TAG_DiarySaveResponses set [
    _requestId,
    _responses
];

// -----------------------------------------------------
// Clients zur Erfassung auffordern
// -----------------------------------------------------

if (hasInterface) then {
    [_requestId] call TAG_fnc_collectDiaryEntries;
};

[_requestId] remoteExecCall [
    "TAG_fnc_collectDiaryEntries",
    -2
];

["saveDiaryEntries", format [
    "Erfassung gestartet | Anfrage=%1 | Erwartete Einheiten=%2",
    _requestId,
    _expectedUnits
]] call TAG_fnc_debugLog;

// -----------------------------------------------------
// Auf Antworten warten (maximal 8 Sekunden)
// -----------------------------------------------------

private _deadline = diag_tickTime + 8;

waitUntil {
    sleep 0.25;

    private _received = {
        _x in (keys _responses)
    } count _expectedUnits;

    (_received >= count _expectedUnits)
    || {diag_tickTime >= _deadline}
};

// -----------------------------------------------------
// Gemeinsamen Speicherbestand laden
// -----------------------------------------------------

private _entries = TAG_SaveData getOrDefault [
    "DiaryEntries",
    createHashMap
];

private _workingEntries = createHashMap;
private _initialCopyValid = true;

{
    private _bucketKey = _x;
    private _bucket = _entries get _bucketKey;

    if !(_bucket isEqualType []) then {

        _initialCopyValid = false;

        diag_log format [
            "[PERSISTENCE][DIARY] Kopie ungültig | Bucket=%1 | Grund=Kein Array",
            _bucketKey
        ];

    } else {

        private _bucketCopy = [];
        private _bucketValid = true;

        {
            if (
                !(_x isEqualType [])
                || {count _x < 10}
            ) then {
                _bucketValid = false;
            } else {
                _bucketCopy pushBack (+_x);
            };
        } forEach _bucket;

        if (_bucketValid) then {
            _workingEntries set [
                _bucketKey,
                _bucketCopy
            ];
        } else {
            _initialCopyValid = false;

            diag_log format [
                "[PERSISTENCE][DIARY] Kopie ungültig | Bucket=%1 | Grund=Ungültiger Eintrag",
                _bucketKey
            ];
        };
    };
} forEach (keys _entries);

// -----------------------------------------------------
// Eingegangene Snapshots zusammenführen
// -----------------------------------------------------

private _savedCount = 0;
private _blockedCount = 0;
private _invalidCount = 0;
private _addedCount = 0;
private _duplicateCount = 0;

{
    private _unitName = _x;

    private _restoreReady = false;

    if (!isNil "TAG_DiaryRestoreReady") then {
        _restoreReady = TAG_DiaryRestoreReady getOrDefault [
            _unitName,
            false
        ];
    };

    if (!_restoreReady) then {

        _blockedCount = _blockedCount + 1;

        diag_log format [
            "[PERSISTENCE][DIARY] Snapshot nicht übernommen | Einheit=%1 | Grund=Restore nicht bestätigt",
            _unitName
        ];

    } else {

        private _unitData = _responses get _unitName;
        private _unitAdded = 0;
        private _unitDuplicates = 0;

        {
            if (
                !(_x isEqualType [])
                || {count _x < 10}
            ) then {
                _invalidCount = _invalidCount + 1;
                continue;
            };

            _x params [
                ["_subjectID", ""],
                ["_subjectTitle", ""],
                ["_subjectPicture", ""],
                ["_recordTitle", ""],
                ["_description", ""],
                ["_icon", ""],
                ["_scope", ""],
                ["_scopeKey", ""],
                ["_scopeValid", false],
                ["_recordIndex", -1]
            ];

            // Alle zehn Felder ausdrücklich auf ihren Typ prüfen.
            if (
                !(_subjectID isEqualType "")
                || {!(_subjectTitle isEqualType "")}
                || {!(_subjectPicture isEqualType "")}
                || {!(_recordTitle isEqualType "")}
                || {!(_description isEqualType "")}
                || {!(_icon isEqualType "")}
                || {!(_scope isEqualType "")}
                || {!(_scopeKey isEqualType "")}
                || {!(_scopeValid isEqualType true)}
                || {!(_recordIndex isEqualType 0)}
            ) then {
                _invalidCount = _invalidCount + 1;
                continue;
            };

            if (
                _subjectID isEqualTo ""
                || {_recordTitle isEqualTo ""}
                || {_scopeKey isEqualTo ""}
                || {!(_scope in ["PLAY", "GRP", "SIDE", "ALL"])}
                || {_recordIndex < 0}
            ) then {
                _invalidCount = _invalidCount + 1;
                continue;
            };

            // Prüfen, ob der Scope zum Titelpräfix passt.
            private _prefixValid = false;

            switch (_scope) do {
                case "PLAY": {
                    _prefixValid =
                        (_recordTitle find TAG_DiaryPrefixPlayer) isEqualTo 0;
                };

                case "GRP": {
                    _prefixValid =
                        (_recordTitle find TAG_DiaryPrefixGroup) isEqualTo 0;
                };

                case "SIDE": {
                    _prefixValid =
                        (_recordTitle find TAG_DiaryPrefixSide) isEqualTo 0;
                };

                case "ALL": {
                    _prefixValid =
                        (_recordTitle find TAG_DiaryPrefixAll) isEqualTo 0;
                };
            };

            // Unpräfixierte Einträge bleiben vorläufig spielerspezifisch.
            if (!_scopeValid) then {
                if (
                    _scope isNotEqualTo "PLAY"
                    || {_scopeKey isNotEqualTo _unitName}
                    || {_prefixValid}
                ) then {
                    _invalidCount = _invalidCount + 1;
                    continue;
                };
            } else {
                if (!_prefixValid) then {
                    _invalidCount = _invalidCount + 1;
                    continue;
                };
            };

            // PLAY-Einträge dürfen nur dem meldenden Spieler gehören.
            if (
                _scope isEqualTo "PLAY"
                && {_scopeKey isNotEqualTo _unitName}
            ) then {
                _invalidCount = _invalidCount + 1;
                continue;
            };

            // Eindeutiger Schlüssel für den jeweiligen Geltungsbereich.
            private _bucketKey = format [
                "%1:%2",
                _scope,
                _scopeKey
            ];

            private _bucket = _workingEntries getOrDefault [
                _bucketKey,
                []
            ];

            if !(_bucket isEqualType []) then {
                _invalidCount = _invalidCount + 1;
                continue;
            };

            // Vorhandene Einträge anhand Subject, Titel und Inhalt prüfen.
            private _alreadyExists = false;

            {
                if (
                    count _x >= 10
                    && {(_x param [0, ""]) isEqualTo _subjectID}
                    && {(_x param [3, ""]) isEqualTo _recordTitle}
                    && {(_x param [4, ""]) isEqualTo _description}
                ) exitWith {
                    _alreadyExists = true;
                };
            } forEach _bucket;

            if (_alreadyExists) then {
                // Den Index des vorhandenen Eintrags nicht überschreiben.
                _unitDuplicates = _unitDuplicates + 1;
            } else {
                _bucket pushBack [
                    _subjectID,
                    _subjectTitle,
                    _subjectPicture,
                    _recordTitle,
                    _description,
                    _icon,
                    _scope,
                    _scopeKey,
                    _scopeValid,
                    _recordIndex
                ];

                _workingEntries set [
                    _bucketKey,
                    _bucket
                ];

                _unitAdded = _unitAdded + 1;
            };

        } forEach _unitData;

        _savedCount = _savedCount + 1;
        _addedCount = _addedCount + _unitAdded;
        _duplicateCount = _duplicateCount + _unitDuplicates;

        ["saveDiaryEntries", format [
            "Snapshot zusammengeführt | Einheit=%1 | Neu=%2 | Bereits vorhanden=%3",
            _unitName,
            _unitAdded,
            _unitDuplicates
        ]] call TAG_fnc_debugLog;
    };

} forEach (keys _responses);

// -----------------------------------------------------
// Ergebnis sichern und Anfrage aufräumen
// -----------------------------------------------------

private _mergeValid = _initialCopyValid;

{
    private _bucketKey = _x;
    private _bucket = _workingEntries get _bucketKey;

    if !(_bucket isEqualType []) then {

        _mergeValid = false;

        diag_log format [
            "[PERSISTENCE][DIARY] Zusammenführung ungültig | Bucket=%1 | Grund=Kein Array",
            _bucketKey
        ];

    } else {

        {
            if (
                !(_x isEqualType [])
                || {count _x < 10}
                || {!((_x param [0, ""]) isEqualType "")}
                || {!((_x param [1, ""]) isEqualType "")}
                || {!((_x param [2, ""]) isEqualType "")}
                || {!((_x param [3, ""]) isEqualType "")}
                || {!((_x param [4, ""]) isEqualType "")}
                || {!((_x param [5, ""]) isEqualType "")}
                || {!((_x param [6, ""]) isEqualType "")}
                || {!((_x param [7, ""]) isEqualType "")}
                || {!((_x param [8, false]) isEqualType true)}
                || {!((_x param [9, -1]) isEqualType 0)}
                || {(_x param [9, -1]) < 0}
            ) then {

                _mergeValid = false;

                diag_log format [
                    "[PERSISTENCE][DIARY] Zusammenführung ungültig | Bucket=%1 | Grund=Ungültiger Eintrag",
                    _bucketKey
                ];

            } else {

                private _scope = _x param [6, ""];
                private _scopeKey = _x param [7, ""];
                private _expectedBucketKey = format [
                    "%1:%2",
                    _scope,
                    _scopeKey
                ];

                if (
                    !(_scope in ["PLAY", "GRP", "SIDE", "ALL"])
                    || {_scopeKey isEqualTo ""}
                    || {!(_bucketKey isEqualTo _expectedBucketKey)}
                ) then {

                    _mergeValid = false;

                    diag_log format [
                        "[PERSISTENCE][DIARY] Zusammenführung ungültig | Bucket=%1 | Erwartet=%2 | Scope=%3 | Schlüssel=%4",
                        _bucketKey,
                        _expectedBucketKey,
                        _scope,
                        _scopeKey
                    ];
                };
            };
        } forEach _bucket;
    };
} forEach (keys _workingEntries);

if (_mergeValid) then {
    TAG_SaveData set [
        "DiaryEntries",
        _workingEntries
    ];

    ["saveDiaryEntries", format [
        "Zusammenführung validiert | Buckets=%1",
        count (keys _workingEntries)
    ]] call TAG_fnc_debugLog;
} else {
    diag_log "[PERSISTENCE][DIARY] FEHLER: Zusammenführung nicht übernommen. Bisheriger Speicherbestand bleibt erhalten.";
};

private _responseCount = count (keys _responses);

TAG_DiarySaveResponses deleteAt _requestId;

[] call TAG_fnc_saveCampaign;

["saveDiaryEntries", format [
    "Speicherung abgeschlossen | Anfrage=%1 | Antworten=%2/%3 | Verarbeitet=%4 | Neue Einträge=%5 | Duplikate=%6 | Gesperrt=%7 | Ungültig=%8 | Speicherbereiche=%9",
    _requestId,
    _responseCount,
    count _expectedUnits,
    _savedCount,
    _addedCount,
    _duplicateCount,
    _blockedCount,
    _invalidCount,
    count (keys _workingEntries)
]] call TAG_fnc_debugLog;