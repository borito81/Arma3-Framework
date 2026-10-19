
/*
    Author: Djinn

    Description:
    Stellt übermittelte Diary-Daten lokal wieder her und bestätigt
    danach den Abschluss gegenüber dem Server.

    Ausführung: Client
*/

if (!hasInterface) exitWith {};

params [
    ["_diaryData", [], [[]]]
];

[_diaryData] spawn {

    params [
        ["_diaryData", [], [[]]]
    ];

    waitUntil {
        sleep 0.1;
        !isNull player
    };

    {
        _x params [
            ["_subjectID", "Diary", [""]],
            ["_subjectTitle", "", [""]],
            ["_subjectPicture", "", [""]],
            ["_recordTitle", "", [""]],
            ["_description", "", [""]],
            ["_icon", "", [""]]
        ];

        if (
            !(_subjectID isEqualTo "")
            && {!(_recordTitle isEqualTo "")}
        ) then {

            if !(player diarySubjectExists _subjectID) then {
                player createDiarySubject [
                    _subjectID,
                    _subjectTitle,
                    _subjectPicture
                ];
            };

            private _records = player allDiaryRecords _subjectID;
            private _alreadyExists = false;

            {
                if (
                    (_x param [1, ""]) isEqualTo _recordTitle
                    && {(_x param [2, ""]) isEqualTo _description}
                ) exitWith {
                    _alreadyExists = true;
                };
            } forEach _records;

            if (!_alreadyExists) then {

                player createDiaryRecord [
                    _subjectID,
                    [_recordTitle, _description, _icon]
                ];

                ["applyDiaryEntries", format [
                    "Eintrag wiederhergestellt | Subject=%1 | Titel=%2",
                    _subjectID,
                    _recordTitle
                ]] call TAG_fnc_debugLog;
            };
        };
    } forEach ([_diaryData] call {
        params ["_entries"];
        private _reversed = [];

        for "_i" from ((count _entries) - 1) to 0 step -1 do {
            _reversed pushBack (_entries select _i);
        };

        _reversed
    });

    ["applyDiaryEntries", format [
        "Client-Restore abgeschlossen | Einheit=%1 | Übermittelte Einträge=%2",
        vehicleVarName player,
        count _diaryData
    ]] call TAG_fnc_debugLog;

    [] remoteExecCall [
        "TAG_fnc_confirmDiaryRestore",
        2
    ];
};
