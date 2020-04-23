#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=yuumi.ico
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.14.5
 Author:         N3utro

 Script Function:
	Get ranked players stats in league of legends solo/duo queue games

#ce ----------------------------------------------------------------------------

;including libraries used in the code

#NoTrayIcon
#include <Array.au3>
#include <Inet.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <TrayConstants.au3>
#include <File.au3>
#include <GuiRichEdit.au3>
#include <WinAPIProc.au3>
#include <WinHttp.au3>
#include <IE.au3>
;#include <MCFinclude.au3>

;only display "exit" in the tray menu

Opt("TrayMenuMode", 3)
Opt("TrayOnEventMode", 1)
Opt("GUIOnEventMode", 1)
TrayCreateItem("Exit")
TrayItemSetOnEvent(-1, "ExitApp")
TraySetState($TRAY_ICONSTATE_SHOW)
TraySetToolTip ("Summoner's stats")
AutoItSetOption("WinTitleMatchMode", 3)


;app options are below

$debug = 0 ;generates debug files if set to 1
$skip_local_player = 1 ;this should be always set to 1. Set only to 0 for debugging purposes (testing with custom games for example)
$tempfile_location = @TempDir & "\sstats_temp.txt"
$gui_img_location = @TempDir & "\sstats_gui.jpg"
$error_log = @Scriptdir & "\error.log"

;initializing variables. the variables below are not options, dont change their values or the app will stop working

$gui_enabled = 0
$stats_done = 0
$LCUsource = ""
$champ_select_start = 0
$champ_select_reset = 0

;checking if the app is already launched

if winexists("sstats") Then

	msgbox("","Error", "Another instance of summoners stats is already running.")

	Exit

EndIf

;reading the api key from the textfile which should be located in the app folder

$api_key_file = FileReadToArray(@scriptdir & "\api_key.txt")

if isarray($api_key_file) = 0 Then

	msgbox("","Error", "Impossible to read the api key from api_key.txt")

	Exit

Else

	$api_key = $api_key_file[0]

	if stringleft($api_key, 6) <> "RGAPI-" Then

			msgbox("","Error", "The API key does not start with RGAPI- so it is incorrect. Please input your correct key in the api_key.txt file.")

			Exit

		EndIf

EndIf

;checking if the file gui.txt is in the app folder

if fileexists(@scriptdir & "/gui.jpg") = 0 Then

	msgbox("","Error", "The file gui.jpg is missing from the app folder.")

	Exit

EndIf

;finding out the server (EUW1, NA1, ...) on which the player is connected
;for that we check a configuration file in the installation folder of the game where it is indicated

;getting the lol client installation path from the executable process informations

$lol_process_id = ProcessExists('LeagueClient.exe')

if $lol_process_id = 0 Then

	msgbox("","Error", 'Please launch the League of Legends client before launching this app.')

	Exit

Else

	$lol_client_exe_file_path = _WinAPI_GetProcessFileName($lol_process_id)

	if $lol_client_exe_file_path = "" then

		msgbox("","Error", 'The game is beeing run with administrators rights and should not be. Please disable admin rights for the lol client and try again.')

		Exit

	EndIf

EndIf

$lol_client_install_path = StringReplace($lol_client_exe_file_path,"LeagueClient.exe", "")


;ok we found out where the client is installed, now we open the config file which contains the server region informations

$settings_file = FileReadToArray($lol_client_install_path & "Config\LeagueClientSettings.yaml")

if IsArray($settings_file) = 0 Then

	msgbox("","Error", "Cannot read the content of " & $lol_client_install_path & "Config\LeagueClientSettings.yaml")
	Exit

EndIf

$region_line = _ArraySearch($settings_file, "region:", 0, 0, 0, 1)

if $region_line = -1 Then

	msgbox("","Error", "Cannot find the region setting in " & $lol_client_install_path & "Config\LeagueClientSettings.yaml")
	Exit

EndIf

$region_line_delimiter_start = stringinstr($settings_file[$region_line], '"', 0, 1)

$region_line_delimiter_end = stringinstr($settings_file[$region_line], '"', 0, 2)

$region_letters_count = $region_line_delimiter_end - 1 - $region_line_delimiter_start

$region = stringmid($settings_file[$region_line], $region_line_delimiter_start + 1, $region_letters_count)

if $region <> "NA" AND $region <> "EUW" AND $region <> "EUNE" AND $region <> "LAN" AND $region <> "LAS" AND $region <> "BR" AND $region <> "JP" AND $region <> "RU" AND $region <> "TR" and $region <> "OCE" & $region <> "KR" Then

	msgbox("","Error", "Impossible to get the server region.")
	Exit

EndIf

switch $region

	case "NA"
		$api_platform = "na1"

	case "EUW"
		$api_platform = "euw1"

	case "EUNE"
		$api_platform = "eun1"

	case "LAN"
		$api_platform = "la1"

	case "LAS"
		$api_platform = "la2"

	case "BR"
		$api_platform = "br1"

	case "JP"
		$api_platform = "jp1"

	case "RU"
		$api_platform = "ru"

	case "TR"
		$api_platform = "tr1"

	case "OCE"
		$api_platform = "oc1"

	case "KR"
		$api_platform = "kr"

EndSwitch

;ok we're done with getting the server region.



;getting local client (riot calls it "LCU") http server port and password (it changes everytime the league client is restarted)

$lockfile = fileopen($lol_client_install_path & "lockfile")

if $lockfile = -1 then

	msgbox("","Error", 'Cannot open ' & $lol_client_install_path & 'lockfile (is the game client started?')
    Exit

EndIf

$lockfile_content = FileReadLine($lockfile)

$lockfile_split_content=""

$lockfile_split_content = StringSplit($lockfile_content, ":")

if IsArray($lockfile_split_content) <> 1 Then

	msgbox("","Error", "Cannot read the content of " & $lol_client_install_path & "lockfile")
	Exit

EndIf

;_arraydisplay($lockfile_split_content)

$port = $lockfile_split_content[3]
$pass = $lockfile_split_content[4]


;connecting to the LCU local web server and checking if it works by accessing the local game settings informations

$hOpen = _WinHttpOpen()
$hConnect = _WinHttpConnect($hOpen, "127.0.0.1", $port)
$hRequest = _WinHttpSimpleSSLRequest($hConnect,"GET", "/lol-game-settings/v1/game-settings", Default, Default, Default, True , 1, "riot", $pass, 1)

if IsArray($hRequest) = 0 Then

	msgbox("","Error", "Impossible to connect to the local client web server")

	Exit

EndIf

;the source we get this way should contain the word "MasterVolume". We check if it is the case, which means the connection is successful

if StringInStr($hRequest[1], "MasterVolume") = 0 Then

	msgbox("","Error", "Impossible to find MasterVolume reference in the http server query reply.")
	Exit

EndIf

_WinHttpCloseHandle($hRequest)

;----------------------------------------------------------------

;starting to check in a loop the content of the LCU local http server to see if a champion selection screen is displayed or not

;When a game is started and the champion selection screen is displayed, the page /lol-champ-select/v1/session becomes available and contains players names, positions and their selected champions.
;So we wait for this page to become available, and when it does we retrieve and use the players names to download their matches history through riot API, generate their stats from them and display these stats.
;Once a player has locked a champion, we also get the champion name and display the players stats with this champion.

While 1 ;until the software is closed, we start watching for games

	;closing the app if league of legend is closed

	if WinExists("League of Legends") = 0 then

		_WinHttpCloseHandle($hRequest)
        _WinHttpCloseHandle($hConnect)
        _WinHttpCloseHandle($hOpen)

		Exit

	EndIf

	$hRequest = _WinHttpSimpleSSLRequest($hConnect,"GET", "/lol-champ-select/v1/session", Default, Default, Default, True , 1, "riot", $pass, 1)

	if IsArray($hRequest) = 0 Then

		msgbox("","Error", "Impossible to retreive the champion select data")

		Exit

	EndIf

	$LCUsource = $hRequest[1]

	_WinHttpCloseHandle($hRequest)

	if $debug = 1 then FileDelete(@scriptdir & "\data\lcu.txt")

	if $debug = 1 then FileWrite(@scriptdir & "\data\lcu.txt", $LCUsource)

				;drawing the gui

	if $gui_enabled = 0 Then

		;the code below was used to automatically display the app next to the league client window but riot asked me not to do it, so i changed it to "always appear in the top left corner of the screen"

		;if the client window x position is below 321 we move it to 321 to allow the gui to be displayed

		;automatic positionning of the app is disabled per riot request. Instead the app will always start at 0,0 (top left of the screen)

;~ 		$pos =	WinGetPos("League of Legends")

;~ 		if $pos[0] >= 0 AND $pos[0] < 350 then Winmove("League of Legends", "", 350, $pos[1])

;~ 		$pos =	WinGetPos("League of Legends")

;~ 		if BitAND(wingetstate("League of Legends"), $WIN_STATE_VISIBLE) = 0  then

;~ 			$gui_x_pos = 0
;~ 			$gui_y_pos = (@DesktopHeight / 2) - 360

;~ 		else

;~ 			$gui_x_pos = $pos[0] - 350
;~ 			$gui_y_pos = $pos[1]

;~ 		EndIf

		;$gui = GUICreate("sstats", 320, 720, $gui_x_pos, $gui_y_pos, $WS_POPUP)

;----------------------------------------------------------------------------------------------

		;drawing the app gui

		$gui = GUICreate("sstats", 320, 720, 0, 0, $WS_POPUP)
		;GUISetState(@SW_HIDE)
		$Pic1 = GUICtrlCreatePic("gui.jpg", 0, 0, 320, 720)
		GUICtrlSetState(-1, $GUI_DISABLE)
		$Dragarea = GUICtrlCreateLabel("", 0, 0, 320, 33, -1, $GUI_WS_EX_PARENTDRAG)
		GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
		$title = GUICtrlCreateLabel("Summoners stats", 75, 32, 193, 33, -1, $GUI_WS_EX_PARENTDRAG)
		GUICtrlSetFont(-1, 15, 400)
		GUICtrlSetColor(-1, 0xFFFFFF)
		GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
		$summoner1_gui = _GUICtrlRichEdit_Create($gui, "",5, 96, 315, 77, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $ES_LEFT,  $ES_READONLY),  $WS_EX_TRANSPARENT)
		settext($summoner1_gui,"Waiting for a ranked solo/duo queue game...")
		$summoner2_gui = _GUICtrlRichEdit_Create($gui, "",5, 176, 315, 77, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $ES_LEFT,  $ES_READONLY),  $WS_EX_TRANSPARENT)
		$summoner3_gui = _GUICtrlRichEdit_Create($gui, "",5, 256, 315, 77, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $ES_LEFT,  $ES_READONLY),  $WS_EX_TRANSPARENT)
		$summoner4_gui = _GUICtrlRichEdit_Create($gui, "",5, 336, 315, 77, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $ES_LEFT,  $ES_READONLY),  $WS_EX_TRANSPARENT)
		$summoner5_gui = _GUICtrlRichEdit_Create($gui, "",5, 416, 315, 77, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $ES_LEFT,  $ES_READONLY),  $WS_EX_TRANSPARENT)

		GUISetOnEvent($GUI_EVENT_CLOSE, "guiclose")

		GUISetState(@SW_SHOW)

		DllCall("user32.dll","int","HideCaret","int",0) ;this is to disable the cursor when the user select the text of the GUI to copy it

		$gui_enabled = 1

		;the below code was used to add an HTML counter link to see how many people were using it in server mode, but it's useless in a private usage

		;$browse = _IECreate("http://n3utro.free.fr/sstats/counter.html", 0, 0)

		;_IEAction($browse, "refresh")

		;_IEQuit($browse)

	EndIf

	DllCall("user32.dll","int","HideCaret","int",0) ;this is to disable the cursor when the user select the text of the GUI to copy it

	$test = StringInStr($LCUsource, '"httpStatus":404') ; when no champion select page is displayed, querying the champ select page returns a 404 error

	if $test <> 0 then  ; no champion select screen is displayed so we reset the app gui and wait for a game to start

			$stats_done = 0

			$champ_select_start = 0

			if $champ_select_reset = 0 Then

				settext($summoner1_gui, "Waiting for a ranked solo/duo queue game...")
				settext($summoner2_gui, "")
				settext($summoner3_gui, "")
				settext($summoner4_gui, "")
				settext($summoner5_gui, "")

				$champ_select_reset = 1

			EndIf

			sleep(1000)

	Else ; champion select has started


			if $champ_select_start = 0 Then

				settext($summoner1_gui, "Loading summoner 1 stats...")
				settext($summoner2_gui, "Loading summoner 2 stats...")
				settext($summoner3_gui, "Loading summoner 3 stats...")
				settext($summoner4_gui, "Loading summoner 4 stats...")
				settext($summoner5_gui, "Loading summoner 5 stats...")

				$champ_select_start = 1

				$champ_select_reset = 0

			EndIf

			;msgbox("","","pause")

			;---------------------------------------------------------------------------------

			;the code below was used to automatically move the app next to the league client window but riot asked me not to do it, so it's removed and users will have to move the window manually

			;ConsoleWrite($pos[0] & @CRLF)

			;moving the GUI window to be side by side with the LCU - DISABLED PER RIOT REQUEST

			;Winmove("GUI", "", $pos[0] - 320, $pos[1])

			;ConsoleWrite("Champion selection has started!" & @CRLF)

			;----------------------------------------------------------------------------------

			;clearing old debug files

			if $stats_done = 0 Then  ;this is used so that when stats are done, the app doesn't do them over and over again, just once.

				if FileExists(@scriptdir & "\data") then

					FileDelete(@scriptdir & "\data")

					DirRemove(@Scriptdir & "\data")

				EndIf

				;creating a folder for debugging files if enabled

				if $debug = 1 AND FileExists(@scriptdir & "\data") = 0 then DirCreate(@scriptdir & "\data")

				;creating an array for each summoner to store their stats for each champions played which we will use later to compute things like kda, winrate, ect...
				;in other words, this is the app "database".

				;lines
				;1 = champ ID
				;2 = times played
				;3 = kills
				;4 = deaths
				;5 = assists
				;6 = wins
				;7 = most played champion gui data

				;columns = one for each champion played (we add columns later when necessary when a new champion played is detected)

				local $summoner1[14][1]
				local $summoner2[14][1]
				local $summoner3[14][1]
				local $summoner4[14][1]
				local $summoner5[14][1]


				local $summoners_names_list[6] ;array that contains the names of all players of the team of the local player that is later used for the "recently played with" system detection

				;getting summoners names by finding their LCU summoner ID and converting it to their real names
				;we're not getting the local player stats because of the request limit of riot API

				;$LCUsource = _INetGetSource("https://riot:" & $pass & "@127.0.0.1:" & $port & "/lol-champ-select/v1/session")

				;ConsoleWrite($LCUsource)

				;identifying the id of the local player

				$local_player_index = stringinstr($LCUsource, "localPlayerCellId")
				$local_player_cell_ID = stringmid($LCUsource, $local_player_index + 19, 1)
				$local_player_cell_ID = number($local_player_cell_ID) + 1 ;cellID go from 0 to 9 so we add one to go from 1 to 10
				if $local_player_cell_ID > 5 then $local_player_cell_ID = $local_player_cell_ID - 5 ;if the local player cell id is for the second team, we remove 5 to transpose it so it's in the 1-5 range

				$index = stringinstr($LCUsource, '"myTeam":[{', 1)

				for $i = 1 to 5 step 1

					;if it's the local player we skip it

					if $i = $local_player_cell_ID AND $skip_local_player = 1 Then

						$gui_temp = eval("summoner" & $i & "_gui")

						settext($gui_temp, "Local player - skipping")

						ContinueLoop

					EndIf

					$index2 = stringinstr($LCUsource, "summonerId", 1, $i, $index)

					$index3 = stringinstr($LCUsource, ",", 1, 1, $index2)

					$id = stringmid($LCUsource, $index2 + 12, $index3 - ($index2 + 12))

					if StringIsDigit($id) = 0 Then continueloop ;the id wont be a number if there are less than 5 players so we skip them

					if $debug = 1 then filewrite(@scriptdir & "\data\summoner" & $i & ".txt", $id & ",")

					;translating summoner ID into their summoner's name

					$hRequest = _WinHttpSimpleSSLRequest($hConnect,"GET", "/lol-summoner/v1/summoners/" & $id, Default, Default, Default, True , 1, "riot", $pass, 1)

					if IsArray($hRequest) = 0 Then

						msgbox("","Error", "Impossible to retreive the summoners informations from the local web server")

						Exit

					EndIf

					$summonerinfosource = $hRequest[1]

					_WinHttpCloseHandle($hRequest)

					$summoner_name_index_start = stringinstr($summonerinfosource, '"', 1, 5)

					$summoner_name_index_end = stringinstr($summonerinfosource, '"', 1, 6)

					$summoner_name = stringmid($summonerinfosource, $summoner_name_index_start +1, $summoner_name_index_end - $summoner_name_index_start - 1)

					if $debug = 1 then  filewrite(@scriptdir & "\data\summoner" & $i & ".txt", $summoner_name & ",")

					$summoners_names_list[$i] = $summoner_name

				Next

				for $i = 1 to 5 step 1 ;this is the core of the app, where we start getting the matches history of each players and parse them to generate stats

						if $i = $local_player_cell_ID AND $skip_local_player = 1 Then ContinueLoop


						$summoner_name = $summoners_names_list[$i]

						if $summoner_name = "" then ContinueLoop ;this means the team of the localplayer has less than 5 members. Shouldn't happen but used for debugging in custom games


						;some special characters need to be encoded in url form to query the riot API.

						$encoded_summoner_name = _UnicodeURLEncode($summoner_name)

						if $debug = 1 then  filewrite(@scriptdir & "\data\summoner" & $i & ".txt", $encoded_summoner_name & ",")

						;GUICtrlSetData(eval("summoner" & $i & "_gui") , $summoner_name)

						;getting the corresponding encrypted account ID from the summoner name from riot API - this is needed because it's requested by riot API for other queries later used by the app

						if FileExists(@tempdir & "\summonerquery") then FileDelete(@tempdir & "\summonerquery")

						InetGet("https://" & $api_platform & ".api.riotgames.com/lol/summoner/v4/summoners/by-name/" & $encoded_summoner_name & "?api_key=" & $api_key, @tempdir & "\summonerquery")

						$tempfile = FileOpen(@tempdir & "\summonerquery")

						$riot_API_summonerinfo_source = FileRead(@tempdir & "\summonerquery")

						FileClose($tempfile)

						FileDelete(@TempDir & "\summonerquery")

						if $debug = 1 then filewrite(@TempDir & "\data\summoner_api_infos.txt", $riot_API_summonerinfo_source & @CRLF)

						;$riot_API_summonerinfo_source = _INetGetSource("https://euw1.api.riotgames.com/lol/summoner/v4/summoners/by-name/" & $encoded_summoner_name & "?api_key=" & $api_key)

						if stringinstr($riot_API_summonerinfo_source, $summoner_name) = 0 Then

							msgbox("","Error", "Impossible to find " & $summoner_name & " in the riot API query. This might mean that you need to download a newer version of summoners stats!")

							Exit

						EndIf

						;ConsoleWrite($riot_API_summonerinfo_source & @CRLF)

						;getting encrypted_account_id

						$encrypted_account_id = find_data_value_in_json($riot_API_summonerinfo_source, "accountId", true)

						if $debug = 1 then  filewrite(@scriptdir & "\data\summoner" & $i & ".txt", $encrypted_account_id & "," & @CRLF)

						;getting encrypted summoner id

						$encrypted_summoner_id = find_data_value_in_json($riot_API_summonerinfo_source, "id", true)

						if $debug = 1 then  filewrite(@scriptdir & "\data\summoner" & $i & ".txt", $encrypted_summoner_id & "," & @CRLF)

						;quering the riot API to get the player's ranked solo/duo queue tier, rank and his/her current number of LP points

						$riot_API_summoner_rank = _INetGetSource("https://" & $api_platform & ".api.riotgames.com/lol/league/v4/entries/by-summoner/" & $encrypted_summoner_id & "?api_key=" & $api_key)

						$index2 = stringinstr($riot_API_summoner_rank, "RANKED_SOLO_5x5")

						if $index2 = 0 Then ;if this text is not found then it means the player is unranked

							if $debug = 1 then  filewrite(@scriptdir & "\data\summoner" & $i & ".txt", "unranked" & @CRLF)

							$gui_temp = eval("summoner" & $i & "_gui")

							settext($gui_temp, $summoner_name & " - Unranked" & @CRLF)

						Else ;the player has a rank so we extract the informations that we need

							$tier = find_data_value_in_json($riot_API_summoner_rank, "tier", true, 1, "RANKED_SOLO_5x5") ;iron, bronze, silver, gold, plat, ect...

							$rank = find_data_value_in_json($riot_API_summoner_rank, "rank", true, 1, "RANKED_SOLO_5x5") ; from I to IV

							$LP = find_data_value_in_json($riot_API_summoner_rank, "leaguePoints", false, 1, "RANKED_SOLO_5x5")

							;updating GUI to display these informations

							$gui_temp = eval("summoner" & $i & "_gui")

							settext($gui_temp, $summoner_name & " - " & $tier & " " & $rank & " - " & $LP & " LP" & @CRLF)

						EndIf

						;$riot_API_summoner_rank = _INetGetSource("https://euw1.api.riotgames.com/lol/league/v4/entries/by-summoner/T_RXOqJa5LlMynZFL9FrF5LXPtOjSV9EmDXAUj1vsqpDsS8?api_key=RGAPI-a2c5b4f2-5cb7-454a-8451-c11cc93438fc")

						if $debug = 1 then FileWrite(@scriptdir & "\data\riot_api_summoner_rank.txt", $riot_API_summoner_rank & @CRLF)

						;getting the player's last 20 ranked matches list from riot API

						$riot_API_matchlist = _INetGetSource("https://" & $api_platform & ".api.riotgames.com/lol/match/v4/matchlists/by-account/" & $encrypted_account_id & "?queue=420&endIndex=20&api_key=" & $api_key)

						;extracting the id of all matches

						StringRegExpReplace($riot_API_matchlist, "gameId", "gameId")

						;checking if there are at least one previous ranked solo/duo game played, otherwise it's the first ranked game ever (new account) so we display this information on the gui

						$matches_count = @extended

						if $matches_count = 0 Then

							$array = eval("summoner" & $i)

							;$array[0][0] = 0 ;probably not needed

							$gui_temp = eval("summoner" & $i & "_gui")

							if $debug = 1 then  filewrite(@scriptdir & "\data\summoner" & $i & ".txt", "No ranked games previously played" & @CRLF)

							settext($gui_temp, $summoner_name & @CRLF & @CRLF & "No ranked games previously played")

							ContinueLoop

						EndIf

						sleep(1000) ;adding a 1s delay to ensure the 20 request per second query limit to riot API is not reached

						$recently_played_with = "" ;used later

						;ok we now have the list of the 20 last previous games played so we start retreiving the JSON source for each of these matches from the riot API and parse them to extract the information we need

						for $j = 1 to $matches_count step 1 ; for each match in the player 20 last previously ranked solo/duo matches list

						;for $j = 1 to 1 step 1


							$match_id = find_data_value_in_json($riot_API_matchlist, "gameId", false, $j)

							if $debug = 1 then  filewrite(@scriptdir & "\data\summoner" & $i & ".txt", $match_id & @CRLF)

							if FileExists(@tempdir & "\temp2") then FileDelete(@tempdir & "\temp2")

							InetGet("https://" & $api_platform & ".api.riotgames.com/lol/match/v4/matches/" & $match_id & "?api_key=" & $api_key, @tempdir & "\temp2")

							$tempfile = FileOpen(@tempdir & "\temp2")

							$match_stats = FileRead($tempfile)

							FileClose($tempfile)

							FileDelete(@tempdir & "\temp2")

							if $debug = 1 then  filewrite(@scriptdir & "\data\summoner" & $i & ".txt", $match_stats & @CRLF)

							if StringInStr($match_stats, "queueId") = 0 Then

								FileWrite($error_log, "Could not get stats for match id " & $match_id & " of summoner " & $summoner_name  & " - This usually happens when API query rate has been reached" & @CRLF)

							EndIf

							;checking if the game is a remake (game duration is below 5 mins) or not. If it is, we skip it

							$game_duration = find_data_value_in_json($match_stats, "gameDuration", false)

							;ConsoleWrite($game_duration & @CRLF)

							if number($game_duration) < 300 then ContinueLoop

							;checking if the name of one player in the game matches the name of one of the local player team member ("recently played with" feature on op.gg)

							;finding all player names

							if $debug = 1 then FileWrite(@scriptdir & "\data\recent.txt", $match_id & @CRLF)

							for $k = 1 to 10 step 1

								$game_member_name = find_data_value_in_json($match_stats, "summonerName", True, $k)

								if $debug = 1 then FileWrite(@scriptdir & "\data\recent.txt", $game_member_name & @CRLF)

								;ConsoleWrite($game_member_name & @CRLF)

								$search = _ArraySearch($summoners_names_list, $game_member_name) ;searching if the found player name is part of the local player team

								$already_added = stringinstr($recently_played_with, $game_member_name) ;searching if the found name is already part of the "recently played" list

								if $game_member_name <> $summoner_name AND $search  <> -1 AND $already_added = 0 Then $recently_played_with = $recently_played_with & $game_member_name & " - "

							Next


						    ;finding the participantId corresponding to the summoner's name

							$participant_id = find_data_value_in_json($match_stats, "participantId", false, -1, $encrypted_summoner_id)

							if $debug = 1 then  filewrite(@scriptdir & "\data\summoner" & $i & ".txt", "participantid : " & $participant_id & @CRLF)

							if $participant_id = 1 AND stringmid($match_stats, $index3 + 16, 1) = "0" then $participant_id = 10 ;dirty hack if summonerid is 10

							;getting the stats from the player for the current match: champion played, kills, deaths, ...

							$champion_id = find_data_value_in_json($match_stats, "championId", false, 1, "participants", '"participantId":' & $participant_id)

							if $debug = 1 then  filewrite(@scriptdir & "\data\summoner" & $i & ".txt", $champion_id & " - " & get_champion_name($champion_id) & @CRLF)

							$kills = find_data_value_in_json($match_stats, "kills", false, 1, "participants", '"participantId":' & $participant_id)

							if $debug = 1 then  filewrite(@scriptdir & "\data\summoner" & $i & ".txt", "kills : " & $kills & @CRLF)

							$deaths = find_data_value_in_json($match_stats, "deaths", false, 1, "participants", '"participantId":' & $participant_id)

							if $debug = 1 then  filewrite(@scriptdir & "\data\summoner" & $i & ".txt", "deaths: " & $deaths & @CRLF)

							$assists = find_data_value_in_json($match_stats, "assists", false, 1, "participants", '"participantId":' & $participant_id)

							if $debug = 1 then  filewrite(@scriptdir & "\data\summoner" & $i & ".txt", "assists : " & $assists & @CRLF)

							$win = find_data_value_in_json($match_stats, "win", false, 1, "participants", '"participantId":' & $participant_id)

							if $win = "true" then $win = 1

							if $win = "false" then $win = 0

							if $debug = 1 then  filewrite(@scriptdir & "\data\summoner" & $i & ".txt", "win : " & $win & @CRLF)


							;adding stats data to the summoner array

							;we search if there is already data for this champion : if yes then we add it to the current data, if not we create a new column for this champion

							;to my knowledge autoit has no way to access a specific array line/column based on the current loop step like you can do in the C language for example, so we need to use this "eval" system which is a dirty way to do it.
							;there perhaps is a better way to do it, but hey at least it's working.

							$array = eval("summoner" & $i)

							$search = _ArraySearch($array , $champion_id, default, default, default, default, default, 1, true)

							if $search = -1 Then ;first time the played champion is detected, so we add a new column for it

								_ArrayColInsert($array , 0)

								;we always write in the column 1 because it's the new column created by the previous function. So the number stays "1" but it's actually a different new column every time

								$array[1][1] = $champion_id
								$array[2][1] = 1
								$array[3][1] = $kills
								$array[4][1] = $deaths
								$array[5][1] = $assists
								$array[6][1] = $win

								assign("summoner" & $i, $array)


							Else ; the champion has already been played, so we add the stats to the current one

								$array[2][$search] = $array[2][$search] + 1 ;we add 1 to the previous number of matches played with this champion
								$array[3][$search] = $array[3][$search] + $kills
								$array[4][$search] = $array[4][$search] + $deaths
								$array[5][$search] = $array[5][$search] + $assists
								$array[6][$search] = $array[6][$search] + $win

								assign("summoner" & $i, $array)

							EndIf

							;if $debug = 1 then  _FileWriteFromArray(@scriptdir & "\data\summoner" & $i & ".txt", $array)

							if $debug = 1 then  filewrite(@scriptdir & "\data\summoner" & $i & ".txt", @CRLF)

						Next ;next match

						$array = eval("summoner" & $i)

						;stats gathering is done for all matches

						;now calculating the average kill, death, assists and winrate by champion played by dividing total stats by the number of games played for each champions

						$columns_count = UBound($array, 2)

						;ConsoleWrite($columns_count & @CRLF)

						for $k = 1 to $columns_count - 1  step 1

							$array[3][$k] = round($array[3][$k] / $array[2][$k], 1) ;average kills
							$array[4][$k] = round($array[4][$k] / $array[2][$k], 1) ;average deaths
							$array[5][$k] = round($array[5][$k] / $array[2][$k], 1) ;average assists
							$array[6][$k] = round($array[6][$k] / $array[2][$k], 2) * 100 ;average winrate percentage

						Next

						sleep(1000); adding a 1s delay to ensure the 20 request per second query limit to the riot API is not reached

						;finding which is the most played champion

						for $f = 1 to ubound($array, 2) - 1 step 1

							if number($array[2][$f]) > number($array[2][0]) then

							   ;ConsoleWrite(number($array[2][$f]) & " > " & number($array[2][0]) & @CRLF)

                               $array[2][0] = $array[2][$f]
							   $array[1][0] = $array[1][$f]
							   $array[0][0] = $f

							EndIf

						Next

						;_ArrayDisplay($array)

						;if $debug = 1 then  _FileWriteFromArray(@scriptdir & "\data\summoner" & $i & ".txt", $array)

						if $debug = 1 then  filewrite(@scriptdir & "\data\summoner" & $i & ".txt", @CRLF)

						;_arraydisplay(eval("summoner" & $i))

						;updating summoner GUI with most played champion

						$gui_temp = eval("summoner" & $i & "_gui")

						$gui_previous_data = _GUICtrlRichEdit_GetText($gui_temp) ;getting the tier and rank info so we can add the stats after

						;adding "recently played with players"

						;$recently_played_with = "TEST"

						if $recently_played_with <> "" then

							$gui_previous_data = $gui_previous_data & @CRLF & @CRLF & "Recently played with: " & $recently_played_with & @CRLF

							$array[12][0] = $recently_played_with

						EndIf

						;updating the GUI to display the stats that we just generated for the player and adding colors so we can see them better

						$most_play_col = $array[0][0]

						$array[7][0] =  $gui_previous_data & get_champion_name($array[1][$most_play_col]) & " (" & $array[2][$most_play_col] & ") " & " - " & $array[3][$most_play_col] & "/" & $array[4][$most_play_col] & "/" & $array[5][$most_play_col] & ' (' & $array[6][$most_play_col] & '% winrate)'

						settext($gui_temp, $array[7][0])

						;set kills in green color

						$coloring_index = StringLen($gui_previous_data & get_champion_name($array[1][$most_play_col]) & " (" & $array[2][$most_play_col] & ") " & " - ")
						if $recently_played_with <> "" then $coloring_index = $coloring_index - 5
						$coloring_index2 = StringLen($array[3][$most_play_col])
						_GUICtrlRichEdit_SetSel($gui_temp, $coloring_index, $coloring_index + $coloring_index2 )
						_GUICtrlRichEdit_SetCharColor($gui_temp, dec("00FF00"))
						_GUICtrlRichEdit_SetSel($gui_temp, 0, 0)
						DllCall("user32.dll","int","HideCaret","int",0)

						$array[8][0] = $coloring_index
						$array[9][0] = $coloring_index2

						;set deaths in red color

						$coloring_index = StringLen($gui_previous_data & get_champion_name($array[1][$most_play_col]) & " (" & $array[2][$most_play_col] & ") " & " - " & $array[3][$most_play_col] & "/")
						if $recently_played_with <> "" then $coloring_index = $coloring_index - 5
						$coloring_index2 = StringLen($array[4][$most_play_col])
						_GUICtrlRichEdit_SetSel($gui_temp, $coloring_index, $coloring_index + $coloring_index2 )
						_GUICtrlRichEdit_SetCharColor($gui_temp, dec("0000FF"))
						_GUICtrlRichEdit_SetSel($gui_temp, 0, 0)
						DllCall("user32.dll","int","HideCaret","int",0)

						$array[10][0] = $coloring_index
						$array[11][0] = $coloring_index2


						assign("summoner" & $i, $array)



				Next ;stats are done and displayed for the current summoner, we do them for the next one until all are done

				;all the stats for all the players are done and displayed

				$stats_done = 1

			EndIf ;end of stats making

			;stats are done so now we just check what are the picks of the players and display the corresponding stats if they exist

			;identifying the id of the local player

			$index = stringinstr($LCUsource, "localPlayerCellId")

			$local_player_cell_ID = stringmid($LCUsource, $index + 19, 1)

			;we have to get all picks from all players and then use only what we need

			local $summoners_picks[10]

			;counting how many pick there are to get (should be always 10 but if used in another game mode (which the app is not designed to be used for as a reminder) it could change)

			StringRegExpReplace($LCUsource, '"type":"pick"', '"type":"pick"')

			$pick_counts = @extended


			for $i = 1 to $pick_counts step 1


				$index = stringinstr($LCUsource, '"type":"pick"', 1, $i)

				$index2 = stringinstr($LCUsource, 'actorCellId', 1, -1, $index)

				$actor_cell_ID = stringmid($LCUsource, $index2 + 13, 1)

				$index3 = stringinstr($LCUsource, "championId", 1, 1, $index2)

				$index4 = stringinstr($LCUsource, ",", 0, 1, $index3)

				$champion_id = stringmid($LCUsource, $index3 + 12, $index4 - ($index3 + 12))

				$summoners_picks[$actor_cell_ID] = $champion_id


				if $debug = 1 then FileWrite(@scriptdir & "\data\lcu.txt", "$actor_cell_ID = " & $actor_cell_ID & @CRLF)

				if $debug = 1 then FileWrite(@scriptdir & "\data\lcu.txt", "$champion_id = " & $champion_id & @CRLF)

			Next

			if $debug = 1 then  _FileWriteFromArray(@scriptdir & "\data\summoners_picks.txt", $summoners_picks)

			;we got everyone's pick. Now for each player of our team we search if the pick is in the stats we generated earlier and display the corresponding informations in the app's GUI

		    for $i = 0 to 4 step 1

				if $i = $local_player_cell_ID OR $i = $local_player_cell_ID - 5 AND $skip_local_player = 1 Then ;skipping local player

					if $debug = 1 then  FileWrite(@scriptdir & "\data\lcu.txt", @CRLF & "skipping loop " & $i & " local_player_cell_ID " & $local_player_cell_ID & @CRLF)
					continueloop ;found local player

				EndIf

				$array = eval("summoner" & $i + 1)

				;_ArrayDisplay($array)

				$gui_temp = eval("summoner" & $i + 1 & "_gui")

				$gui_temp_data = _GUICtrlRichEdit_GetText($gui_temp)

				;the id of the players of the team depends of the id of the cell of the local player, so we only search for picks of players of the same team (team 1: 0 to 4 - team 2: 5 to 9)

				if number($local_player_cell_ID) < 5 then $search = _arraysearch($array, $summoners_picks[$i], 1, default, default, default, default, 1, true)

				if number($local_player_cell_ID) > 4 then $search = _arraysearch($array, $summoners_picks[$i + 5], 1, default, default, default, default, 1, true)

				if $debug = 1 then  FileWrite(@scriptdir & "\data\lcu.txt", @CRLF & "search : " & $search & @CRLF)

				if $debug = 1 then  FileWrite(@scriptdir & "\data\lcu.txt", @CRLF & "$summoners_picks[$i] : " & $summoners_picks[$i] & @CRLF)

				if $debug = 1 then  FileWrite(@scriptdir & "\data\lcu.txt", @CRLF & "$summoners_picks[$i+5] : " & $summoners_picks[$i + 5] & @CRLF)


				if $search <> -1 Then ;the picked champion has stats so we display them

					$update_text = $array[7][0] & @CRLF & get_champion_name($array[1][$search]) & " (" & $array[2][$search] & ') - ' & $array[3][$search] & "/" & $array[4][$search] & "/" & $array[5][$search] & ' (' & $array[6][$search] & '% winrate)'

					;consolewrite(StringToBinary(StringStripWS($gui_temp_data, 8)) & @CRLF)
					;consolewrite(StringToBinary(StringStripWS($update_text, 8)) & @CRLF)


					if StringStripWS($gui_temp_data, 8) <> StringStripWS($update_text, 8) then

						settext($gui_temp, $update_text)

						;setting colors
						;for the selected champion

						$coloring_index =  StringLen($array[7][0] & @CRLF & get_champion_name($array[1][$search]) & " (" & $array[2][$search] & ') - ') - 1
						if $array[12][0] <> "" then $coloring_index = $coloring_index - 5
						$coloring_index2 = StringLen($array[3][$search])
						_GUICtrlRichEdit_SetSel($gui_temp, $coloring_index, $coloring_index + $coloring_index2 )
						_GUICtrlRichEdit_SetCharColor($gui_temp, dec("00FF00"))
						_GUICtrlRichEdit_SetSel($gui_temp, 0, 0)
						DllCall("user32.dll","int","HideCaret","int",0)

						$coloring_index =  StringLen($array[7][0] & @CRLF & get_champion_name($array[1][$search]) & " (" & $array[2][$search] & ') - ' & $array[3][$search] & "/") - 1
						if $array[12][0] <> "" then $coloring_index = $coloring_index - 5
						$coloring_index2 = StringLen($array[4][$search])
						_GUICtrlRichEdit_SetSel($gui_temp, $coloring_index, $coloring_index + $coloring_index2 )
						_GUICtrlRichEdit_SetCharColor($gui_temp, dec("0000FF"))
						_GUICtrlRichEdit_SetSel($gui_temp, 0, 0)
						DllCall("user32.dll","int","HideCaret","int",0)


						;for the most played champion


						_GUICtrlRichEdit_SetSel($gui_temp, $array[8][0], $array[8][0] + $array[9][0] )
						_GUICtrlRichEdit_SetCharColor($gui_temp, dec("00FF00"))
						_GUICtrlRichEdit_SetSel($gui_temp, 0, 0)
						DllCall("user32.dll","int","HideCaret","int",0)

						_GUICtrlRichEdit_SetSel($gui_temp, $array[10][0], $array[10][0] + $array[11][0] )
						_GUICtrlRichEdit_SetCharColor($gui_temp, dec("0000FF"))
						_GUICtrlRichEdit_SetSel($gui_temp, 0, 0)
						DllCall("user32.dll","int","HideCaret","int",0)


					EndIf


				Else

					;no recorded stats for this champion

					if number($local_player_cell_ID) < 5 AND $summoners_picks[$i] <> 0 then

						$update_text = $array[7][0] & @CRLF & get_champion_name($summoners_picks[$i]) & " (0 played)"

					;consolewrite(StringToBinary(StringStripWS($gui_temp_data, 8)) & @CRLF)
					;consolewrite(StringToBinary(StringStripWS($update_text, 8)) & @CRLF)

						if StringStripWS($gui_temp_data, 8) <> StringStripWS($update_text, 8) then

							settext($gui_temp, $update_text)

							_GUICtrlRichEdit_SetSel($gui_temp, $array[8][0], $array[8][0] + $array[9][0] )
							_GUICtrlRichEdit_SetCharColor($gui_temp, dec("00FF00"))
							_GUICtrlRichEdit_SetSel($gui_temp, 0, 0)
							DllCall("user32.dll","int","HideCaret","int",0)

							_GUICtrlRichEdit_SetSel($gui_temp, $array[10][0], $array[10][0] + $array[11][0] )
							_GUICtrlRichEdit_SetCharColor($gui_temp, dec("0000FF"))
							_GUICtrlRichEdit_SetSel($gui_temp, 0, 0)
							DllCall("user32.dll","int","HideCaret","int",0)

						EndIf

					EndIf

					if number($local_player_cell_ID) > 4 AND $summoners_picks[$i + 5] <> 0 then

						$update_text = $array[7][0] & @CRLF & get_champion_name($summoners_picks[$i + 5]) & " (0 played)"

					;consolewrite(StringToBinary(StringStripWS($gui_temp_data, 8)) & @CRLF)
					;consolewrite(StringToBinary(StringStripWS($update_text, 8)) & @CRLF)

						if StringStripWS($gui_temp_data, 8) <> StringStripWS($update_text, 8) then

							settext($gui_temp, $update_text)

							_GUICtrlRichEdit_SetSel($gui_temp, $array[8][0], $array[8][0] + $array[9][0] )
							_GUICtrlRichEdit_SetCharColor($gui_temp, dec("00FF00"))
							_GUICtrlRichEdit_SetSel($gui_temp, 0, 0)
							DllCall("user32.dll","int","HideCaret","int",0)

							_GUICtrlRichEdit_SetSel($gui_temp, $array[10][0], $array[10][0] + $array[11][0] )
							_GUICtrlRichEdit_SetCharColor($gui_temp, dec("0000FF"))
							_GUICtrlRichEdit_SetSel($gui_temp, 0, 0)
							DllCall("user32.dll","int","HideCaret","int",0)

						EndIf

					EndIf


				EndIf

			Next

			sleep(10) ;used so that the numbers of queries to the local web server is not too high

	Endif

WEnd ;end of the app

;----------------------------------------------------------------------;

;below are custom functions called in the app source code

;----------------------------------------------------------------------;

func find_data_value_in_json($jsonsource, $data_name, $is_text, $occurence = 1, $start_index_keyword = "", $second_index_keyword = "")

	;json source = the json source where to find the data value
	;data_name = the name of the data of which we want to find the value
	;is_text = define if the value of the data is a text or not.
	;occurence = define the occurence of the $data_name to find; defaut is 1 (find first occurence)
	;start index = (optionnal) the number of characters to start to search from in the json source, default is 0 = since the beginning
	;start_index_keyword = (optionnal) searches this keyword in the json source and start looking for the data from this point.
	;second_index_keyword = (optionnal) searches this keyword in the json source file from $start_index_keyword and start looking for the data from this point

$index = 1

if $start_index_keyword <> "" Then

	$index = StringInStr($jsonsource, $start_index_keyword, 1, 1)

	if $index = 0 then FileWrite($error_log, "Cannot find " & $start_index_keyword & " when looking for " & $data_name & " value" & @CRLF)

EndIf

if $second_index_keyword <> "" then

	$index = StringInStr($jsonsource, $second_index_keyword, 1, 1, $index)

	if $index = 0 then FileWrite($error_log, "Cannot find " & $second_index_keyword & " when looking for " & $data_name & " value" & @CRLF)

EndIf

$index2 = StringInStr($jsonsource, '"' & $data_name & '"', 1, $occurence, $index)

if $index2 = 0 then FileWrite($error_log, "Cannot find " & $data_name & @CRLF)


;finding the separator symbol. It can be either "," or "}," or "}"


$index3 = stringinstr($jsonsource, ",", 0, 1, $index2)


if $index3 <> 0 AND stringmid($jsonsource, $index3 - 1, 1) = "}" then $index3 = $index3 - 1

if $index3 = 0 then $index3 = stringinstr($jsonsource, ",", 0, 1, $index2)

if $index3 = 0 then $index3 = stringinstr($jsonsource, "}", 0, 1, $index2)

if $index3 = 0 then FileWrite($error_log, "cannot find the separator symbol that ends the value of " & $data_name & @CRLF)



if $is_text = true then ; "data":"value"

	$data_value = stringmid($jsonsource, $index2 + stringlen($data_name) + 4, $index3 - 1 - ($index2 + stringlen($data_name) + 4))

Else ; "data":value

	$data_value = stringmid($jsonsource, $index2 + stringlen($data_name) + 3, $index3 - ($index2 + stringlen($data_name) + 3))

EndIf

return $data_value

EndFunc


;--------------------------------------------------------------------------------------

func settext($gui, $text) ;used to format text properly in the app GUI

	_GUICtrlRichEdit_SetText($gui, $text)
	_GUICtrlRichEdit_SetSel($gui, 0, -1)
	_GUICtrlRichEdit_SetFont($gui, 10)
	_GUICtrlRichEdit_SetCharColor($gui, dec("FFFFFF"))
	_GUICtrlRichEdit_SetSel($gui, 0, 0)
	DllCall("user32.dll","int","HideCaret","int",0)

EndFunc

;--------------------------------------------------------------------------------------

Func _UnicodeURLEncode($UnicodeURL) ;used to format URL properly so they work with the riot API
    $UnicodeBinary = StringToBinary ($UnicodeURL, 4)
    $UnicodeBinary2 = StringReplace($UnicodeBinary, '0x', '', 1)
    $UnicodeBinaryLength = StringLen($UnicodeBinary2)
    Local $EncodedString
    For $i = 1 To $UnicodeBinaryLength Step 2
        $UnicodeBinaryChar = StringMid($UnicodeBinary2, $i, 2)
        If StringInStr("$-_.+!*'(),;/?:@=&abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890", BinaryToString ('0x' & $UnicodeBinaryChar, 4)) Then
            $EncodedString &= BinaryToString ('0x' & $UnicodeBinaryChar)
        Else
            $EncodedString &= '%' & $UnicodeBinaryChar
        EndIf
    Next
    Return $EncodedString
EndFunc   ;==>_UnicodeURLEncode

;----------------------------------------------------------------------------------------

Func ExitApp() ;used by the GUI to close the app
    Exit
EndFunc   ;==>ExitScript

;----------------------------------------------------------------------------------------

func guiclose() ;used by the GUI to close the app
	Exit
EndFunc

;----------------------------------------------------------------------------------------

;converts champion ID to champion name ; in other words this is a champion ID database

func get_champion_name($id)

	switch $id

		case 1
		return 'Annie'
		case 2
		return 'Olaf'
		case 3
		return 'Galio'
		case 4
		return 'Twisted Fate'
		case 5
		return 'Xin Zhao'
		case 6
		return 'Urgot'
		case 7
		return 'LeBlanc'
		case 8
		return 'Vladimir'
		case 9
		return 'Fiddlesticks'
		case 10
		return 'Kayle'
		case 11
		return 'Master Yi'
		case 12
		return 'Alistar'
		case 13
		return 'Ryze'
		case 14
		return 'Sion'
		case 15
		return 'Sivir'
		case 16
		return 'Soraka'
		case 17
		return 'Teemo'
		case 18
		return 'Tristana'
		case 19
		return 'Warwick'
		case 20
		return 'Nunu'
		case 21
		return 'Miss Fortune'
		case 22
		return 'Ashe'
		case 23
		return 'Tryndamere'
		case 24
		return 'Jax'
		case 25
		return 'Morgana'
		case 26
		return 'Zilean'
		case 27
		return 'Singed'
		case 28
		return 'Evelynn'
		case 29
		return 'Twitch'
		case 30
		return 'Karthus'
		case 31
		return 'ChoGath'
		case 32
		return 'Amumu'
		case 33
		return 'Rammus'
		case 34
		return 'Anivia'
		case 35
		return 'Shaco'
		case 36
		return 'Dr. Mundo'
		case 37
		return 'Sona'
		case 38
		return 'Kassadin'
		case 39
		return 'Irelia'
		case 40
		return 'Janna'
		case 41
		return 'Gangplank'
		case 42
		return 'Corki'
		case 43
		return 'Karma'
		case 44
		return 'Taric'
		case 45
		return 'Veigar'
		case 48
		return 'Trundle'
		case 50
		return 'Swain'
		case 51
		return 'Caitlyn'
		case 53
		return 'Blitzcrank'
		case 54
		return 'Malphite'
		case 55
		return 'Katarina'
		case 56
		return 'Nocturne'
		case 57
		return 'Maokai'
		case 58
		return 'Renekton'
		case 59
		return 'Jarvan IV'
		case 60
		return 'Elise'
		case 61
		return 'Orianna'
		case 62
		return 'Wukong'
		case 63
		return 'Brand'
		case 64
		return 'Lee Sin'
		case 67
		return 'Vayne'
		case 68
		return 'Rumble'
		case 69
		return 'Cassiopeia'
		case 72
		return 'Skarner'
		case 74
		return 'Heimerdinger'
		case 75
		return 'Nasus'
		case 76
		return 'Nidalee'
		case 77
		return 'Udyr'
		case 78
		return 'Poppy'
		case 79
		return 'Gragas'
		case 80
		return 'Pantheon'
		case 81
		return 'Ezreal'
		case 82
		return 'Mordekaiser'
		case 83
		return 'Yorick'
		case 84
		return 'Akali'
		case 85
		return 'Kennen'
		case 86
		return 'Garen'
		case 89
		return 'Leona'
		case 90
		return 'Malzahar'
		case 91
		return 'Talon'
		case 92
		return 'Riven'
		case 96
		return 'KogMaw'
		case 98
		return 'Shen'
		case 99
		return 'Lux'
		case 101
		return 'Xerath'
		case 102
		return 'Shyvana'
		case 103
		return 'Ahri'
		case 104
		return 'Graves'
		case 105
		return 'Fizz'
		case 106
		return 'Volibear'
		case 107
		return 'Rengar'
		case 110
		return 'Varus'
		case 111
		return 'Nautilus'
		case 112
		return 'Viktor'
		case 113
		return 'Sejuani'
		case 114
		return 'Fiora'
		case 115
		return 'Ziggs'
		case 117
		return 'Lulu'
		case 119
		return 'Draven'
		case 120
		return 'Hecarim'
		case 121
		return 'KhaZix'
		case 122
		return 'Darius'
		case 126
		return 'Jayce'
		case 127
		return 'Lissandra'
		case 131
		return 'Diana'
		case 133
		return 'Quinn'
		case 134
		return 'Syndra'
		case 136
		return 'Aurelion Sol'
		case 141
		return 'Kayn'
		case 142
		return 'Zoe'
		case 143
		return 'Zyra'
		case 145
		return 'KaiSa'
		case 150
		return 'Gnar'
		case 154
		return 'Zac'
		case 157
		return 'Yasuo'
		case 161
		return 'VelKoz'
		case 163
		return 'Taliyah'
		case 164
		return 'Camille'
		case 201
		return 'Braum'
		case 202
		return 'Jhin'
		case 203
		return 'Kindred'
		case 222
		return 'Jinx'
		case 223
		return 'Tahm Kench'
		case 235
		return 'Senna'
		case 236
		return 'Lucian'
		case 238
		return 'Zed'
		case 240
		return 'Kled'
		case 245
		return 'Ekko'
		case 246
		return 'Qiyana'
		case 254
		return 'Vi'
		case 266
		return 'Aatrox'
		case 267
		return 'Nami'
		case 268
		return 'Azir'
		case 350
		return 'Yuumi'
		case 412
		return 'Thresh'
		case 420
		return 'Illaoi'
		case 421
		return 'RekSai'
		case 427
		return 'Ivern'
		case 429
		return 'Kalista'
		case 432
		return 'Bard'
		case 497
		return 'Rakan'
		case 498
		return 'Xayah'
		case 516
		return 'Ornn'
		case 517
		return 'Sylas'
		case 518
		return 'Neeko'
		case 523
		return 'Aphelios'
		case 555
		return 'Pyke'
		case 875
		return 'Sett'

	EndSwitch

EndFunc

