Scriptname DNT_DialogueMenuListener extends ReferenceAlias

DNT_TravelCoordinator Property Coordinator Auto

Function RegisterDialogueMenu()
    RegisterForMenu("Dialogue Menu")
    Debug.Trace("[DNT] MENU_LISTENER_REGISTERED")
EndFunction

Event OnInit()
    RegisterDialogueMenu()
EndEvent

Event OnPlayerLoadGame()
    RegisterDialogueMenu()
EndEvent

Event OnMenuOpen(String menuName)
    If menuName == "Dialogue Menu" && Coordinator
        Coordinator.PreloadForSpeaker(Game.GetCurrentCrosshairRef())
    EndIf
EndEvent
