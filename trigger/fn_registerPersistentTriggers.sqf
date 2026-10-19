/*
    Author: Djinn

    Description:
    Registriert einmalige Editor-Trigger mit dem Namenspräfix
    "trg_persist_".

    Bereits abgeschlossene Trigger werden deaktiviert.
    Bei offenen Triggern wird die ursprüngliche Aktivierungsaktion
    um die zentrale Persistenzfunktion ergänzt.

    Ausführung: Server
*/

if (!isServer) exitWith {};

if (isNil "TAG_SaveData") exitWith {
    diag_log "[PERSISTENCE][TRIGGER] FEHLER: TAG_SaveData ist nicht initialisiert.";
};

private _triggerStates = TAG_SaveData getOrDefault [
    "TriggerStates",
    createHashMap
];

private _registered = 0;
private _disabled = 0;
private _ignoredRepeatable = 0;

["registerPersistentTriggers", "Registrierung gestartet."] call TAG_fnc_debugLog;

{
    private _trigger = _x;
    private _triggerName = vehicleVarName _trigger;

    // Nur ausdrücklich markierte Trigger berücksichtigen.
    if ((_triggerName find "trg_persist_") isEqualTo 0) then {

        private _activationData = triggerActivation _trigger;
        private _isRepeatable = _activationData param [2, false];

        if (_isRepeatable) then {

            _ignoredRepeatable = _ignoredRepeatable + 1;

            ["registerPersistentTriggers", format [
                "Wiederholbarer Trigger ignoriert | Name=%1",
                _triggerName
            ]] call TAG_fnc_debugLog;

        } else {

            private _statements = TriggerStatements _trigger;
            _statements params [
                "_condition",
                "_onActivation",
                "_onDeactivation"
            ];

            private _isCompleted = _triggerStates getOrDefault [
                _triggerName,
                false
            ];

            if (_isCompleted) then {

                // Bereits erledigte Trigger dürfen nicht erneut auslösen.
                _trigger setTriggerStatements [
                    "false",
                    "",
                    ""
                ];

                _disabled = _disabled + 1;

                ["registerPersistentTriggers", format [
                    "Erledigten Trigger deaktiviert | Name=%1",
                    _triggerName
                ]] call TAG_fnc_debugLog;

            } else {

                // Erst Triggerzustand speichern, dann Originalaktion ausführen.
                // Danach Ticket-, Task- und Markerzustände sichern.
                private _wrappedActivation = format [
                    "['%1'] call TAG_fnc_completePersistentTrigger;%2%3;%2[] call TAG_fnc_saveRespawnTickets;%2[] call TAG_fnc_saveMarkerStates;%2[] spawn { sleep 1; [] call TAG_fnc_syncTaskRegistry;};",
                    _triggerName,
                    endl,
                    _onActivation
                ];

                _trigger setTriggerStatements [
                    _condition,
                    _wrappedActivation,
                    _onDeactivation
                ];

                _registered = _registered + 1;

                ["registerPersistentTriggers", format [
                    "Trigger registriert | Name=%1",
                    _triggerName
                ]] call TAG_fnc_debugLog;
            };
        };
    };

} forEach (allMissionObjects "EmptyDetector");

["registerPersistentTriggers", format [
    "Registrierung abgeschlossen | Registriert=%1 | Deaktiviert=%2 | Wiederholbare ignoriert=%3",
    _registered,
    _disabled,
    _ignoredRepeatable
]] call TAG_fnc_debugLog;