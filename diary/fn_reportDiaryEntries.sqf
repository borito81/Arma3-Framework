
/*
    Author: Djinn

    Description:
    Nimmt Diary-Daten entgegen und ordnet sie der tatsächlichen
    Spielereinheit des Absenders zu.

    Akzeptiert nur Rückmeldungen von Einheiten, deren Diary-Restore
    serverseitig bestätigt wurde. Prüft das erweiterte Datenformat
    und die Zuordnungsschlüssel.

    Ausführung: Server
*/

if (!isServer) exitWith {};

params [
    ["_requestId", -1, [0]],
    ["_diaryData", [], [[]]]
];

if (_requestId < 0) exitWith {};
if (isNil "TAG_DiarySaveResponses") exitWith {};

if (isNil { TAG_DiarySaveResponses get _requestId }) exitWith {
    diag_log format [
        "[PERSISTENCE][DIARY] Rückmeldung verworfen: unbekannte Anfrage | Anfrage=%1",
        _requestId
    ];
};

private _responses = TAG_DiarySaveResponses get _requestId;

// Tatsächlichen Absender anhand der Remote-Owner-ID bestimmen.
private _sender = objNull;

{
    if (owner _x isEqualTo remoteExecutedOwner) exitWith {
        _sender = _x;
    };
} forEach allPlayers;

if (isNull _sender) exitWith {
    diag_log format [
        "[PERSISTENCE][DIARY] Rückmeldung abgelehnt: Absender nicht gefunden | Owner=%1",
        remoteExecutedOwner
    ];
};

private _unitName = vehicleVarName _sender;

if (_unitName isEqualTo "") exitWith {
    diag_log format [
        "[PERSISTENCE][DIARY] Rückmeldung verworfen: Einheit ohne Editor-Variable | Owner=%1",
        remoteExecutedOwner
    ];
};

// Restore-Ready prüfen.
private _restoreReady = false;

if (!isNil "TAG_DiaryRestoreReady") then {
    _restoreReady = TAG_DiaryRestoreReady getOrDefault [
        _unitName,
        false
    ];
};

if (!_restoreReady) exitWith {
    diag_log format [
        "[PERSISTENCE][DIARY] Rückmeldung verworfen | Anfrage=%1 | Einheit=%2 | Einträge=%3 | Grund=Restore nicht bestätigt",
        _requestId,
        _unitName,
        count _diaryData
    ];
};

// Rückmeldung anhand des Absenders validieren.
private _validatedData = [];
private _invalidCount = 0;

{
    if !(_x isEqualType []) then {
        _invalidCount = _invalidCount + 1;
        continue;
    };

    // Neues Format muss zehn Felder enthalten.
    if (count _x < 10) then {
        _invalidCount = _invalidCount + 1;
        continue;
    };

    _x params [
        ["_subjectID", "", [""]],
        ["_subjectTitle", "", [""]],
        ["_subjectPicture", "", [""]],
        ["_recordTitle", "", [""]],
        ["_description", "", [""]],
        ["_icon", "", [""]],
        ["_scope", "", [""]],
        ["_scopeKey", "", [""]],
        ["_scopeValid", false, [true]],
        ["_recordIndex", -1, [0]]
    ];

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

    // Pflichtfelder und Datentypen prüfen.
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

    // Der Server bestimmt den erwarteten Schlüssel selbst.
    private _expectedKey = "";

    switch (_scope) do {
        case "PLAY": {
            _expectedKey = _unitName;
        };

        case "GRP": {
            _expectedKey = format [
                "%1|%2",
                str (side _sender),
                groupId (group _sender)
            ];
        };

        case "SIDE": {
            _expectedKey = str (side _sender);
        };

        case "ALL": {
            _expectedKey = "ALL";
        };
    };

    if (
        _expectedKey isEqualTo ""
        || {!(_scopeKey isEqualTo _expectedKey)}
    ) then {
        _invalidCount = _invalidCount + 1;

        diag_log format [
            "[PERSISTENCE][DIARY] Eintrag verworfen: Schlüssel stimmt nicht | Einheit=%1 | Scope=%2 | Empfangen=%3 | Erwartet=%4 | Titel=%5",
            _unitName,
            _scope,
            _scopeKey,
            _expectedKey,
            _recordTitle
        ];

        continue;
    };

    // Titelpräfix muss zum angegebenen Geltungsbereich passen.
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

    // Einträge ohne gültiges Präfix dürfen nur PLAY-Einträge sein.
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

    _validatedData pushBack [
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

} forEach _diaryData;

_responses set [
    _unitName,
    _validatedData
];

["reportDiaryEntries", format [
    "Rückmeldung verarbeitet | Anfrage=%1 | Einheit=%2 | Gültige Einträge=%3 | Verworfen=%4",
    _requestId,
    _unitName,
    count _validatedData,
    _invalidCount
]] call TAG_fnc_debugLog;
