; Compile-time declaration of Better Carriage Destinations' public native API.
; The runtime implementation is provided by BetterCarriageDestinations.dll.
Scriptname BCD_Utils Hidden

ObjectReference Function GetMapMarkerByIndex(Int aiIndex) Global Native
Function OpenTheMap(FormList akFilterList = None, Bool abIsWhitelist = True) Global Native
Function CloseTheMap() Global Native
