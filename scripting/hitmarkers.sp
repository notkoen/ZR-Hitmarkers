#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <DynamicChannels>
#include <csgocolors_fix>
#include <zombiereloaded>

Handle g_hitmarker_cookie;

ConVar g_cvChannel;

bool g_bZHitmarker[MAXPLAYERS+1] = {true, ...};
bool g_bBHitmarker[MAXPLAYERS+1] = {true, ...};
int g_iChannel;

public Plugin myinfo =
{
    name = "[ZR] Simple Hitmarkers",
    author = "koen",
    description = "Hitmarkers for ZE",
    version = "1.0",
    url = "https://steamcommunity.com/id/notkoen/"
};

public void OnPluginStart()
{
    g_hitmarker_cookie = RegClientCookie("hitmarker_cookies", "[Hitmarker] Cookies for boss and zombie hitmarkers", CookieAccess_Private);

    g_cvChannel = CreateConVar("sm_hitmarker_channel", "1", "Hitmarker channel to be displayed on", _, true, 0.0, true, 5.0);
    HookConVarChange(g_cvChannel, OnConvarChange);
    AutoExecConfig(true, "Simple Hitmarker");

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

public void OnConfigsExecuted()
{
    g_iChannel = g_cvChannel.IntValue;
}

public void OnConvarChange(ConVar cvar, const char[] oldValue, const char[] newValue)
{
    if (cvar == g_cvChannel)
        g_iChannel = g_cvChannel.IntValue;
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

    if (boss)
        ShowHudText(client, GetDynamicChannel(g_iChannel), "◞  ◟\n◝  ◜");
    else
        ShowHudText(client, GetDynamicChannel(g_iChannel), "∷");
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
    
    if (!IsValidClient(attacker) || !IsValidClient(victim))
        return;

    if (g_bZHitmarker[attacker] && ZR_IsClientZombie(victim))
        hitmarker(attacker, false);
}

public void Event_EntityDamage(const char[] output, int caller, int activator, float delay)
{
    hitmarker(activator, true);
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
    menu.SetTitle("Hitmarkers Settings\n\n ");
    SetMenuExitBackButton(menu, true);
    SetMenuExitButton(menu, true);

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
                CPrintToChat(client, "{green}[Hitmarker] {lightgreen}Zombie hitmarker is now %s{lightgreen}.", g_bZHitmarker[client] ? "{blue}enabled" : "{red}disabled");
            }
            else if (StrEqual(info, "boss"))
            {
                g_bBHitmarker[client] = !g_bBHitmarker[client];
                CPrintToChat(client, "{green}[Hitmarker] {lightgreen}Boss hitmarker is now %s{lightgreen}.", g_bBHitmarker[client] ? "{blue}enabled" : "{red}disabled");
            }
            SaveClientCookies(client);
            HitmarkerMenu(client);
        }
        case MenuAction_Cancel:
        {
            if (selection == MenuCancel_ExitBack)
                ShowCookieMenu(client);
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
    }
    return 0;
}