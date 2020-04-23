# Summoner's stats
A Windows app that automatically retrieves stats for League of Legends ranked solo/duo queue games.

These are the same stats you can get from websites like op.gg or leagueofgraphs.com but it's automatically displayed on your screen when you start a game, and the stats displayed are always up to date.

There are others apps available that try to do the same thing like blitz.gg but they are very complicated, very heavy (over 100MB), require you to install them on your computer, create an account, and most of the time the displayed stats are incorrect.

Here is a short demo of the app: https://www.youtube.com/watch?v=1z6y6mL0W08

## How to use

### Get your riot development api key

1. Go to https://developer.riotgames.com/
2. Login with any league of legends account
3. Click on (re)generate API key
4. Copy your API key (it should be something like RGAPI-xxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx) and save it somewhere.

DO NOT SHARE YOUR API KEY ANYWHERE WITH ANYONE IT'S PRIVATE AND FOR YOUR EYES ONLY

### Download the app zip file and extract it on your computer

It can be downloaded here

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


 
 
