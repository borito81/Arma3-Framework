
/*
    Author: Djinn

    Description:
    Erstellt eine neue Standard-SaveData-Struktur.

    Return:
    HashMap
*/

createHashMapFromArray [
    ["SaveVersion", 1],
    ["CampaignInitialized", false],

    // Weltzustand
    ["DestroyedGroups", []],
    ["DestroyedVehicles", []],
    ["DynamicGroups", createHashMap],
    ["Vehicles", createHashMap],
    ["POIs", createHashMap],

    // Missionsfortschritt
    ["CompletedEvents", []],
    ["TriggerStates", createHashMap],
    ["Tasks", createHashMap],
    ["TaskDefinitions", createHashMap],
    ["MarkerStates", createHashMap],
    ["DiaryEntries", createHashMap],

    // Spieler und Kampagnenressourcen
    ["Players", createHashMap],
    ["PlayerVehicles", createHashMap],
    ["RespawnTickets", createHashMap]
];