#define PLUGIN_VERSION "1.41"
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>

StringMap BotMap;

// ConVars

ConVar TankDamage;
ConVar TankHealth;
ConVar ZDifficulty; char ZDifficulty_Char[16];
ConVar MaxSI;

public Plugin:myinfo = 
{
    name = "Infection",
    author = "boogameow",
    description = "You die in co-op modes, you're infected.",
    version = PLUGIN_VERSION,
    url = "https://github.com/boogameow/infection-l4d2"
}

public OnPluginStart()
{
	BotMap = new StringMap();

	// Hooks

	HookEvent("player_death", OnDeathHook, EventHookMode_Pre);
	HookEvent("survivor_rescued", OnSurvivorBackToLife);
	HookEvent("defibrillator_used", OnSurvivorBackToLife);
	HookEvent("player_bot_replace", AFKHook);

	HookEvent("mission_lost", RoundEndHook);
    HookEvent("map_transition", RoundTransitionHook, EventHookMode_Pre);

	HookEvent("difficulty_changed", OnDifficultyChange);

	// ConVars
	TankDamage = FindConVar("vs_tank_damage");
	TankHealth = FindConVar("z_tank_health");
	MaxSI = FindConVar("z_max_player_zombies");
	ZDifficulty = FindConVar("z_difficulty");

	GetConVarString(ZDifficulty, ZDifficulty_Char, sizeof(ZDifficulty_Char));
	SetDifficultyCvars();
}

// Helpers

stock bool:IsValidPlayerIndex(clientid) {
	return ( (clientid > 0) && (clientid <= MaxClients) );
}

stock bool:IsValidPlayer(clientid) {
	return (IsClientInGame(clientid) && IsClientConnected(clientid) && !IsFakeClient(clientid)); 
}

// Functions

void SetDifficultyCvars() {
	if (StrEqual(ZDifficulty_Char, "Easy")) {
		SetConVarInt(TankDamage, 12);
		SetConVarInt(TankHealth, 3000);
	} else if (StrEqual(ZDifficulty_Char, "Normal")) {
		SetConVarInt(TankDamage, 24);
		SetConVarInt(TankHealth, 4000);
	} else if (StrEqual(ZDifficulty_Char, "Hard")) {
		SetConVarInt(TankDamage, 33);
		SetConVarInt(TankHealth, 8000);
	} else if (StrEqual(ZDifficulty_Char, "Impossible")) {
		SetConVarInt(TankDamage, 150);
		SetConVarInt(TankHealth, 8000);
	}
}

void SetPlayerSI(int PlayerSI) {
	if (PlayerSI < 2) {
		SetConVarInt(MaxSI, 2); // Default amount of SI.
	} else {
		SetConVarInt(MaxSI, PlayerSI);
	}
}

// Difficulty CVars

public void OnDifficultyChange(Handle event, const char[] name, bool dontBroadcast) {
	GetEventString(event, "strDifficulty", ZDifficulty_Char, sizeof(ZDifficulty_Char));

	if (!ZDifficulty_Char) {
		return;
	}

	SetDifficultyCvars();
}

// Round

public void RoundEndHook(Handle event, const char[] name, bool dontBroadcast) {
    for(int i = 1; i <= MaxClients; i++) {
		SwitchTeam(i, 3); // Switch all players to infected on fail.
	}

	BotMap.Clear();
}

public void RoundTransitionHook(Handle event, const char[] name, bool dontBroadcast) {
    for(int i = 1; i <= MaxClients; i++) {
		SwitchTeam(i, 2); // Switch all players to survivors on success.
	}

	BotMap.Clear();
}

// Switch on Death and Revival

public void OnSurvivorBackToLife(Handle event, const char[] name, bool dontBroadcast) {
	int botid = GetEventInt(event, "subject"); // defibbed

	if (!botid) {
		botid = GetEventInt(event, "victim"); // rescued from closet

		if (!botid) {
			return;
		}
	}

	int botclient = GetClientOfUserId(botid);

	if (!botclient) {
		return;
	}

	char newbotid[8];
	IntToString(botid, newbotid, sizeof(newbotid));

	int userid;
	BotMap.GetValue(newbotid, userid);

	if (!userid) {
		return;
	}

	int client = GetClientOfUserId(userid);
	BotMap.Remove(newbotid);

	char botname[16];
	GetClientName(botclient, botname, sizeof(botname));

	SwitchTeam(client, 2, botname);
}

public void AFKHook(Handle event, const char[] name, bool dontBroadcast) {
	int UserId = GetEventInt(event, "player");
	int BotId = GetEventInt(event, "bot");

	char StringBotId[8];
	IntToString(BotId, StringBotId, sizeof(StringBotId));

	BotMap.SetValue(StringBotId, UserId);
}

public void OnDeathHook(Handle event, const char[] name, bool dontBroadcast) {
	int Client = GetClientOfUserId(GetEventInt(event, "userid"));
	SwitchTeam(Client, 3);
}

// Main

void SwitchTeam(int Client, int Team, char Bot[16]="") {
	if (!IsValidPlayerIndex(Client)) {
		return;
	} else if (!IsValidPlayer(Client)) {
		return;
	}

	int ClientTeam = GetClientTeam(Client);

	if (ClientTeam == Team) {
		return;
	}

	int PlayerSI = GetTeamClientCount(3);

	if (ClientTeam == 3) {
		PlayerSI -= 1;
	} else if (Team == 3) {
		PlayerSI += 1;
	}

	char TeamString[8];
	IntToString(Team, TeamString, sizeof(TeamString));

	SetPlayerSI(PlayerSI);
	
	if (StrEqual(Bot, "")) {
		ChangeClientTeam(Client, Team);
	} else {
		FakeClientCommand(Client, "jointeam %s %s", TeamString, Bot);
	}
}