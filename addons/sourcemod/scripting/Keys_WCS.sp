#pragma semicolon 1

#include <sourcemod>
#include <keys_core>
#include <wcs>

public Plugin:myinfo =
{
	name		= "[Keys] WCS",
	author	= "R1KO",
	version	= "1.0",
	url		= "hlmod.ru"
};

new const String:g_sKeyType[][] = {"wcs_gold", "wcs_p_race", "wcs_bank_lvl"};

public OnPluginStart()
{
	LoadTranslations("keys_core.phrases");
	LoadTranslations("keys_wcs_module.phrases");
	
	if (Keys_IsCoreStarted()) Keys_OnCoreStarted();
}

public OnPluginEnd()
{
	for(new i = 0; i < sizeof(g_sKeyType); ++i)
	{
		Keys_UnregKey(g_sKeyType[i]);
	}
}

public Keys_OnCoreStarted()
{
	for(new i = 0; i < sizeof(g_sKeyType); ++i)
	{
		Keys_RegKey(g_sKeyType[i], OnKeyParamsValidate, OnKeyUse, OnKeyPrint);
	}
}

public bool:OnKeyParamsValidate(iClient, const String:sKeyType[], Handle:hParamsArr, String:sError[], iErrLen)
{
	if(GetArraySize(hParamsArr) != 1)
	{
		FormatEx(sError, iErrLen, "%T", "ERROR_NUM_ARGS", iClient);
		return false;
	}

	decl String:sParam[KEYS_MAX_LENGTH];
	GetArrayString(hParamsArr, 0, sParam, sizeof(sParam));

	if(!strcmp(sKeyType, g_sKeyType[1]))
	{
		if(!WCS_IsRacePrivate(sParam))
		{
			FormatEx(sError, iErrLen, "%T", "ERROR_INVALID_RACE", iClient);
			return false;
		}

		return true;
	}

	if(StringToInt(sParam) < 1)
	{
		FormatEx(sError, iErrLen, "%T", !strcmp(sKeyType, g_sKeyType[0]) ? "ERROR_INVALID_AMONUT":"ERROR_INVALID_LVL", iClient);
		return false;
	}

	return true;
}

public bool:OnKeyUse(iClient, const String:sKeyType[], Handle:hParamsArr, String:sError[], iErrLen)
{
	decl String:sParam[KEYS_MAX_LENGTH];
	GetArrayString(hParamsArr, 0, sParam, sizeof(sParam));

	if(!strcmp(sKeyType, g_sKeyType[0]))
	{
		if(!WCS_GiveGold(iClient, StringToInt(sParam)))
		{
			FormatEx(sError, iErrLen, "%T", "ERROR_HAS_OCCURRED", iClient);
			return false;
		}

		PrintToChat(iClient, "%t%t", "CHAT_PREFIX", "YOU_RECEIVED_GOLD", StringToInt(sParam));
		return true;
	}

	if(!strcmp(sKeyType, g_sKeyType[2]))
	{
		if(!WCS_GiveLBlvl(iClient, StringToInt(sParam)))
		{
			FormatEx(sError, iErrLen, "%T", "ERROR_HAS_OCCURRED", iClient);
			return false;
		}

		PrintToChat(iClient, "%t%t", "CHAT_PREFIX", "YOU_RECEIVED_BLVL", StringToInt(sParam));
		return true;
	}
	
	if(!WCS_IsRacePrivate(sParam))
	{
		FormatEx(sError, iErrLen, "%T", "ERROR_INVALID_RACE", iClient);
		return false;
	}

	decl String:sAuth[32];
	GetClientAuthId(iClient, AuthId_Steam2, sAuth, sizeof(sAuth));
	if(!WCS_GivePrivateRace(sAuth, sParam))
	{
		FormatEx(sError, iErrLen, "%T", "ERROR_HAS_OCCURRED", iClient);
		return false;
	}

	PrintToChat(iClient, "%t%t", "CHAT_PREFIX", "YOU_RECEIVED_PRIVATE_RACE", sParam);

	return true;
}

public OnKeyPrint(iClient, const String:sKeyType[], Handle:hParamsArr, String:sBuffer[], iBufLen)
{
	decl String:sParam[KEYS_MAX_LENGTH];
	GetArrayString(hParamsArr, 0, sParam, sizeof(sParam));
	if(!strcmp(sKeyType, g_sKeyType[0]))
	{
		FormatEx(sBuffer, iBufLen, "%T: %s", "GOLD", iClient, sParam);
		return;
	}

	if(!strcmp(sKeyType, g_sKeyType[1]))
	{
		FormatEx(sBuffer, iBufLen, "%T: %s", "PRIVATE_RACE", iClient, sParam);
		return;
	}

	FormatEx(sBuffer, iBufLen, "%T: %s", "BLVL", iClient, sParam);
}
