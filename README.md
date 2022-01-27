# Summoner's stats
A Windows app that automatically retrieves stats for League of Legends ranked solo/duo queue games.

These are the same stats you can get from websites like op.gg or leagueofgraphs.com but with summoner's stats it's automatically displayed on your screen when you start a game (you dont have to copy paste the players list into op.gg), and the stats displayed are always up to date.

There are others apps available that try to do the same thing like blitz.gg but they are very complicated, very heavy (over 100MB), require you to install them on your computer, create an account, and most of the time the displayed stats are incorrect.

Here is a short demo of the app: https://www.youtube.com/watch?v=1z6y6mL0W08

This app is safe to use. It has been reviewed and allowed by riot (app ID 414403 on riot dev website). In other words: you will never get banned for using this. The binaries (.exe) are downloadable from the right side of this page. Some antivirus may trigger a false positive, if this happens please report it to me here. If your antivirus tells you this file is a virus it's 100% a false positive, it's the exact same code you can find here compiled into an .exe file, nothing hidden, nothing malicious. I also give the instructions on how to compile it yourself if you prefer.

## How to use

### Get your riot development api key

1. Go to https://developer.riotgames.com/
2. Login with any league of legends account
3. Click on (re)generate API key
4. Copy your API key (it should be something like RGAPI-xxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx) and save it somewhere.

Warning: do not share your api key with anyone, it's just for your personal use. If someone else needs one, they can generate one the same way you did.

### Download the app zip file and extract it on your computer

It can be downloaded here : https://github.com/NeutroGe/sstats/releases/download/v1.0/sstats1.0.zip

Once done paste your riot api key inside the file "api_key.txt", start the league client, start summoner's stats, you're good to go!

If you prefer compiling the app yourself, i'll explain how later in this readme so keep reading or scroll down :)

## Getting a personal riot api key

The riot API development keys last only a day, after this you need to regenerate them. If you plan to use the app regularly, on riot developpers website click "register product" then select "PERSONAL API KEY" and follow the instructions.

Personnals api keys are the same as development keys but they do not expire so you dont need to regenerate the key everyday to use sumonner's stats. AFAIK riot is not restrictive about giving personal api keys so your requests should be allowed if you do them properly. In the meantime you can use your development key.

## API key limitations

Development and personal riot api keys allows you to make 20 requests every 1 second and 100 requests every 2 minutes.

This has consequences on how summoner's stat works: 

 - the display of each player stats has a little delay to make sure the 20 requests per second limit is never reached,
 - stats can only be displayed for 1 game every 2 minutes. If you try to do more than that (for example if someone dodges a game and you dont wait 2 mins) the app will display an error message.
 
But once you know this and be careful about it the app does its job well.

## How to compile the app yourself

If you want to compile the app yourself, here is how:

1. download and install autoit on your computer (around 10MB) - link: https://www.autoitscript.com/site/autoit/downloads/
(optional) download and install "AutoIt Script Editor" (around 5MB) - https://www.autoitscript.com/site/autoit-script-editor/downloads/

2. download the file "sstats.au3" that you can find in this repository and open it with the autoit editor (right click on sstats.au3 -> edit)

3. press ctrl+F7 on the autoit editor to open the compile window, eventually select the yuumi.ico file (available in this repository as well) if you want a nice icon then click "compile" which will generate the exe file of the app.

Warning: do not ask about summoner's stats in the official autoIT forums as they do not allow discussions about anything related to games inside.

## Contact

Leave a message in the discussions here in github!
 
## Disclamer

Summoner's stats isn't endorsed by Riot Games and doesn't reflect the views or opinions of Riot Games or anyone officially involved in producing or managing League of Legends. League of Legends and Riot Games are trademarks or registered trademarks of Riot Games, Inc. League of Legends © Riot Games, Inc.
