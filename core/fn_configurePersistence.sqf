
/*
    Author: Djinn

    Description:
    Zentrale Konfiguration des Persistenzframeworks einschließlich
    Autosave- und Fahrzeugzustandsintervallen in Sekunden.

    Ausführung: Server
*/

// =====================================================
// Zentrale Speicherintervalle
// =====================================================

TAG_AutoSaveInterval = 300;
TAG_VehicleStateInterval = 60;

// Diary-Persistenz
// =====================================================

TAG_DiaryPrefixPlayer = "PLAY:";
TAG_DiaryPrefixGroup  = "GRP:";
TAG_DiaryPrefixSide   = "SIDE:";
TAG_DiaryPrefixAll    = "ALL:";

// =====================================================
// Konfiguration veröffentlichen
// =====================================================

{
    publicVariable _x;
} forEach [
    "TAG_AutoSaveInterval",
    "TAG_VehicleStateInterval",
    "TAG_DiaryPrefixPlayer",
    "TAG_DiaryPrefixGroup",
    "TAG_DiaryPrefixSide",
    "TAG_DiaryPrefixAll"
];

diag_log "[PERSISTENCE] Zentrale Konfiguration geladen.";
