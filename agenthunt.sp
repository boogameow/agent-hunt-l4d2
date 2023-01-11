#define PLUGIN_VERSION "1.3"
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>

StringMap ClientMap;

public Plugin:myinfo = 
{
    name = "Agent Hunt",
    author = "boogameow",
    description = "You die, you're one of them. Modified version of L4DSwitchPlayers.",
    version = PLUGIN_VERSION,
    url = "https://github.com/boogameow/agent-hunt-l4d2"
}

public OnPluginStart()
{
	ClientMap = new StringMap();

	// Hooks

	HookEvent("player_death", OnDeathHook, EventHookMode_Pre);
	HookEvent("survivor_rescued", OnSurvivorBackToLife);
	HookEvent("defibrillator_used", OnSurvivorBackToLife);

	HookEvent("player_bot_replace", AFKHook);
	HookEvent("mission_lost", RoundLostHook);
}

// Helpers

stock bool:IsValidPlayerIndex(clientid) {
	return ( (clientid > 0) && (clientid <= MaxClients) );
}

stock bool:IsValidPlayer(clientid) {
	return (IsClientInGame(clientid) && IsClientConnected(clientid) && !IsFakeClient(clientid)); 
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

	char newbotid[8];
	IntToString(botid, newbotid, sizeof(newbotid));

	int userid;
	ClientMap.GetValue(newbotid, userid);

	if (!userid) {
		return;
	}

	int client = GetClientOfUserId(userid);
	ClientMap.Remove(newbotid);

	SwitchTeam(client, 2);
}

public void RoundLostHook(Handle event, const char[] name, bool dontBroadcast) {
    for(int i = 1; i <= MaxClients; i++) {
		if (!IsFakeClient(i)){
			SwitchTeam(i, 3); // Switch all players to infected on fail.
		}
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

	if (GetClientTeam(client) == 2) {
		SwitchTeam(client, 3);
	}
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