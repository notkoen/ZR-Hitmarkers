#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <DynamicChannels>
#include <zombiereloaded>

Handle g_hitmarker_cookie;

ConVar g_cvChannel;

bool g_bZHitmarker[MAXPLAYERS+1] = {true, ...};
bool g_bBHitmarker[MAXPLAYERS+1] = {true, ...};

public Plugin myinfo =
{
    name = "[ZR] Hitmarkers",
    author = "koen",
    description = "Hitmarkers for ZE",
    version = "1.1",
    url = "https://github.com/notkoen"
};

public void OnPluginStart()
{
    g_hitmarker_cookie = RegClientCookie("hitmarker_cookies", "Cookies for boss and zombie hitmarkers", CookieAccess_Private);

    g_cvChannel = CreateConVar("sm_hitmarker_channel", "1", "game_text channel for hitmarkers to be displayed on", _, true, 0.0, true, 5.0);
    AutoExecConfig(true, "Hitmarkers");

    HookEvent("player_hurt", Event_PlayerHurt);
    HookEntityOutput("func_physbox", "OnHealthChanged", Event_EntityDamage);
    HookEntityOutput("func_physbox_multiplayer", "OnHealthChanged", Event_EntityDamage);
    HookEntityOutput("func_breakable", "OnHealthChanged", Event_EntityDamage);
    HookEntityOutput("math_counter", "OutValue", Event_EntityDamage);

    RegConsoleCmd("sm_hitmarker", Command_Hitmarker, "Bring up hitmarker settings menu");
    RegConsoleCmd("sm_hitmarkers", Command_Hitmarker, "Bring up hitmarker settings menu");

    SetCookieMenuItem(HitmarkerMenuHandler, 0, "Hitmarker Options");

    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && AreClientCookiesCached(client))
        {
            LoadCookies(client);
        }
    }
}

public void OnClientDisconnect(int client)
{
    g_bZHitmarker[client] = true;
    g_bBHitmarker[client] = true;
}

stock bool IsValidClient(int client)
{
    if (!(1 <= client <= MaxClients) || !IsClientInGame(client))
        return false;
    return true;
}

void hitmarker(int client, bool boss)
{
    SetHudTextParams(-1.0, -1.0, 0.3, 255, 0, 0, 255, 0, 0.1, 0.1, 0.1);

    if (boss) ShowHudText(client, GetDynamicChannel(g_cvChannel.IntValue), "???  ???\n???  ???");
    else ShowHudText(client, GetDynamicChannel(g_cvChannel.IntValue), "???");
}

void SaveClientCookies(int client)
{
    char cookie[8];
    FormatEx(cookie, sizeof(cookie), "%b%b", g_bZHitmarker[client], g_bBHitmarker[client]);
    SetClientCookie(client, g_hitmarker_cookie, cookie);
}

void LoadCookies(int client)
{
    char cookie[8];
    GetClientCookie(client, g_hitmarker_cookie, cookie, sizeof(cookie));

    if (cookie[0] != '\0')
    {
        char temp[2];

        FormatEx(temp, sizeof(temp), "%c", cookie[0]);
        g_bZHitmarker[client] = StrEqual(temp, "1");

        FormatEx(temp, sizeof(temp), "%c", cookie[1]);
        g_bBHitmarker[client] = StrEqual(temp, "1");
    }
    else
    {
        g_bZHitmarker[client] = true;
        g_bBHitmarker[client] = true;
    }
}

public Action Command_Hitmarker(int client, int args)
{
    HitmarkerMenu(client);
    return Plugin_Handled;
}

public void Event_PlayerHurt(Handle event, const char[] name, bool broadcast)
{
    int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    int victim = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if (!IsValidClient(attacker) || !IsValidClient(victim)) return;

    if (g_bZHitmarker[attacker] && ZR_IsClientZombie(victim)) hitmarker(attacker, false);
}

public void Event_EntityDamage(const char[] output, int caller, int activator, float delay)
{
    if (g_bBHitmarker[activator]) hitmarker(activator, true);
}

public void HitmarkerMenuHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
    switch (action)
    {
        case CookieMenuAction_SelectOption:
        {
            HitmarkerMenu(client);
        }
    }
}

public void HitmarkerMenu(int client)
{
    Menu menu = CreateMenu(MenuHandler);
    menu.SetTitle("Hitmarkers Settings\n ");
    menu.ExitBackButton(true);
    menu.ExitButton(true);

    char buffer[64];

    FormatEx(buffer, sizeof(buffer), "Zombie Hitmarker: %s", g_bZHitmarker[client] ? "On" : "Off");
    menu.AddItem("zm", buffer);
    FormatEx(buffer, sizeof(buffer), "Boss Hitmarker: %s", g_bBHitmarker[client] ? "On" : "Off");
    menu.AddItem("boss", buffer);

    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler(Handle menu, MenuAction action, int client, int selection)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char info[32];
            GetMenuItem(menu, selection, info, sizeof(info));

            if (StrEqual(info, "zm"))
            {
                g_bZHitmarker[client] = !g_bZHitmarker[client];
                CPrintToChat(client, " \x02[Hitmarker] \x01Zombie hitmarker is now %s\x01.", g_bZHitmarker[client] ? "\x04enabled" : "\x02disabled");
            }
            else if (StrEqual(info, "boss"))
            {
                g_bBHitmarker[client] = !g_bBHitmarker[client];
                CPrintToChat(client, " \x02[Hitmarker] \x01Boss hitmarker is now %s\x01.", g_bBHitmarker[client] ? "\x04enabled" : "\x02disabled");
            }
            SaveClientCookies(client);
            HitmarkerMenu(client);
        }
        case MenuAction_Cancel: if (selection == MenuCancel_ExitBack) ShowCookieMenu(client);
        case MenuAction_End: CloseHandle(menu);
    }
    return 0;
}