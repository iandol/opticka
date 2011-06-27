#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=..\..\..\..\Program Files (x86)\AutoIt3\Icons\au3.ico
#AutoIt3Wrapper_Compression=4
#AutoIt3Wrapper_Res_Fileversion=1.0.0.0
#AutoIt3Wrapper_Run_Tidy=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
$wins = WinList("MATLAB Command Window")

For $i = 1 To $wins[0][0]
	$size = WinGetPos($wins[$i][1])
;~ 	MsgBox(0, "Active window stats (x,y,width,height):", $size[0] & " " & $size[1] & " " & $size[2] & " " & $size[3])
	WinSetTitle($wins[$i][1], "", $wins[$i][0] & " : " & $i)
	If $i == 1 Then
		$mod = 400
	Else
		$mod = 400 * $i
	EndIf
	WinMove($wins[$i][1], "", @DesktopWidth - $mod, @DesktopHeight - 400, 400, 400)
Next

$uiwin = WinList("Omniplex Online Data Display")
WinMove($uiwin[1][1], "", @DesktopWidth - 800, 0)