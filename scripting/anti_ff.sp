#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

ConVar cv_FFIncap, cv_FFSuicide;
int FriendlyFire[MAXPLAYERS + 1];
bool IsIncap[MAXPLAYERS + 1], IsSuicide[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "[L4D2]友伤惩罚",
	author = "奈",
	description = "友伤到达一定值惩罚攻击者",
	version = "1.3",
	url = "https://github.com/NanakaNeko/l4d2_plugins_coop"
};

public void OnPluginStart()
{
	cv_FFIncap = CreateConVar("friendly_fire_incap", "150", "友伤达到多少进行第一个惩罚？(倒地)", FCVAR_NOTIFY, true, 50.0, true, 9999.0);
	cv_FFSuicide = CreateConVar("friendly_fire_suicide", "300", "友伤达到多少进行第二个惩罚？(处死) 设置值不能低于第一个惩罚", FCVAR_NOTIFY, true, GetConVarFloat(cv_FFIncap), true, 9999.0);

	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("round_start", Event_RoundStart);
}

//记录友伤
public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid")), attacker = GetClientOfUserId(event.GetInt("attacker")), damage = event.GetInt("dmg_health");
	if (IsValidPlayer(attacker) && IsValidPlayer(victim) && GetClientTeam(attacker) == 2 && GetClientTeam(victim) == 2 && !IsFakeClient(victim) && attacker != victim)
	{
		FriendlyFire[attacker] += damage;
		FriendlyFireCheck(attacker);
	}
}

//友伤检测
void FriendlyFireCheck(int client)
{
	if(!IsValidPlayer(client))
		return;
	
	int FFIncap = GetConVarInt(cv_FFIncap);
	int FFSuicide = GetConVarInt(cv_FFSuicide);

	if (FriendlyFire[client] >= FFIncap)
	{
		if(!IsIncap[client])
		{
			IsIncap[client] = true;
			if(!IsPlayerIncap(client))
				Incap(client);
			PrintToChatAll("\x04[提示] \x03%N \x05队友伤害达到 \x04%d \x05进行 \x03倒地 \x05惩罚", client, FFIncap);
		}
	}
	if (FriendlyFire[client] >= FFSuicide)
	{
		if(!IsSuicide[client])
		{
			ForcePlayerSuicide(client);
			IsSuicide[client] = true;
			CreateTimer(0.1, ResetFriendlyFireCount, client);
			PrintToChatAll("\x04[提示] \x03%N \x05队友伤害达到 \x04%d \x05进行 \x03处死 \x05惩罚", client, FFSuicide);
		}
	}
}

//换图重置
public void OnMapStart()
{
	for (int i = 1; i <= MaxClients + 1; i++)
	{
		if (IsValidPlayer(i) && !IsFakeClient(i) && GetClientTeam(i) == 2)
			CreateTimer(5.0, ResetFriendlyFireCount, i);
	}
}

//回合开始重置
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients + 1; i++)
	{
		if (IsValidPlayer(i) && !IsFakeClient(i) && GetClientTeam(i) == 2)
			CreateTimer(5.0, ResetFriendlyFireCount, i);
	}
}

//重置友伤计算
Action ResetFriendlyFireCount(Handle timer, int client)
{
	if (IsValidPlayer(client) && FriendlyFire[client] != 0)
	{
		FriendlyFire[client] = 0;
		IsIncap[client] = false;
		IsSuicide[client] = false;
		//PrintToChatAll("\x04[提示] \x03队友伤害计算次数已重置");
	}
	return Plugin_Stop;
}

stock bool IsValidPlayer(int client)
{
	if (client < 1 || client > MaxClients)
		return false;
	if (!IsClientConnected(client) || !IsClientInGame(client))
		return false;
	
	return true;
}

//倒地
void Incap(int client) {
	if (IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !L4D_IsPlayerIncapacitated(client)) {
		static ConVar cv;
		if (!cv)
			cv = FindConVar("survivor_max_incapacitated_count");

		int val = cv.IntValue;
		if (GetEntProp(client, Prop_Send, "m_currentReviveCount") >= val) {
			SetEntProp(client, Prop_Send, "m_currentReviveCount", val - 1);
			SetEntProp(client, Prop_Send, "m_isGoingToDie", 0);
			SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
			StopSound(client, SNDCHAN_STATIC, "player/heartbeatloop.wav");
		}
		IncapPlayer(client);
	}
}

void IncapPlayer(int client)  {
	Vulnerable(client);
	SetEntityHealth(client, 1);
	L4D_SetPlayerTempHealth(client, 0);
	SDKHooks_TakeDamage(client, 0, 0, 100.0);
}

void Vulnerable(int client) {
	static int m_invulnerabilityTimer = -1;
	if (m_invulnerabilityTimer == -1)
		m_invulnerabilityTimer = FindSendPropInfo("CTerrorPlayer", "m_noAvoidanceTimer") - 12;

	SetEntDataFloat(client, m_invulnerabilityTimer + 4, 0.0);
	SetEntDataFloat(client, m_invulnerabilityTimer + 8, 0.0);
}

stock bool IsPlayerIncap(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}