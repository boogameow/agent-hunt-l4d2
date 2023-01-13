#define PLUGIN_VERSION "1.33"
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>

StringMap ClientMap;

// ConVars

ConVar TankDamage;
ConVar TankHealth;
ConVar ZDifficulty; char ZDifficulty_Char[16];

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
	ClientMap = new StringMap();

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

// Function

public void SetDifficultyCvars() {
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

// Event Hooks

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
	ClientMap.GetValue(newbotid, userid);

	if (!userid) {
		return;
	}

	int client = GetClientOfUserId(userid);
	ClientMap.Remove(newbotid);

	char botname[16];
	GetClientName(botclient, botname, sizeof(botname));

	FakeClientCommand(client, "%s %s %s", "jointeam", "2", botname);
}

public void OnDifficultyChange(Handle event, const char[] name, bool dontBroadcast) {
	GetEventString(event, "strDifficulty", ZDifficulty_Char, sizeof(ZDifficulty_Char));

	if (!ZDifficulty_Char) {
		return;
	}

	SetDifficultyCvars();
}

public void RoundEndHook(Handle event, const char[] name, bool dontBroadcast) {
    for(int i = 1; i <= MaxClients; i++) {
		SwitchTeam(i, 3); // Switch all players to infected on fail.
	}

	ClientMap.Clear();
}

public void RoundTransitionHook(Handle event, const char[] name, bool dontBroadcast) {
    for(int i = 1; i <= MaxClients; i++) {
		SwitchTeam(i, 2); // Switch all players to survivors on success.
	}

	ClientMap.Clear();
}

public void AFKHook(Handle event, const char[] name, bool dontBroadcast) {
    int userid = GetEventInt(event, "player");
	int botid = GetEventInt(event, "bot");

	char newbotid[8];
	IntToString(botid, newbotid, sizeof(newbotid));

	ClientMap.SetValue(newbotid, userid);
}

public void OnDeathHook(Handle event, const char[] name, bool dontBroadcast) {
    int userid = GetEventInt(event, "userid");
    int client = GetClientOfUserId(userid);

	SwitchTeam(client, 3);
}

// Main

public void SwitchTeam(client, team) {
	if (!IsValidPlayerIndex(client)) {
		return;
	} else if (!IsValidPlayer(client)) {
		return;
	} else if (GetClientTeam(client) == team) {
		return;
	}

	ChangeClientTeam(client, team);
}