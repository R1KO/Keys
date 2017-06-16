#pragma semicolon 1

#include <sourcemod>
#include <keys_core>
#include <store>

public Plugin:myinfo =
{
	name		= "[Keys] Store (Zephyrus)",
	author	= "R1KO",
	version	= "1.0",
	url		= "hlmod.ru"
};

new const String:g_sKeyType[] = "store_credits";

public OnPluginStart()
{
	LoadTranslations("keys_core.phrases");
	LoadTranslations("keys_store_module.phrases");

	if (Keys_IsCoreStarted()) Keys_OnCoreStarted();
}

public OnPluginEnd()
{
	Keys_UnregKey(g_sKeyType);
}

public Keys_OnCoreStarted()
{
	Keys_RegKey(g_sKeyType, OnKeyParamsValidate, OnKeyUse, OnKeyPrint);
}

public bool:OnKeyParamsValidate(iClient, const String:sKeyType[], Handle:hParamsArr, String:sError[], iErrLen)
{
	decl String:sParam[KEYS_MAX_LENGTH];
	if(GetArraySize(hParamsArr) != 1)
	{
		FormatEx(sError, iErrLen, "%T", "ERROR_NUM_ARGS", iClient);
		return false;
	}

	GetArrayString(hParamsArr, 0, sParam, sizeof(sParam));
	if(StringToInt(sParam) < 1)
	{
		FormatEx(sError, iErrLen, "%T", "ERROR_INVALID_CREDITS", iClient);
		return false;
	}

	return true;
}

public bool:OnKeyUse(iClient, const String:sKeyType[], Handle:hParamsArr, String:sError[], iErrLen)
{
	decl String:sParam[KEYS_MAX_LENGTH];
	GetArrayString(hParamsArr, 0, sParam, sizeof(sParam));
	Store_SetClientCredits(iClient, Store_GetClientCredits(iClient)+StringToInt(sParam));
	PrintToChat(iClient, "%t", "YOU_RECEIVED_CREDITS", StringToInt(sParam));
	return true;
}

public OnKeyPrint(iClient, const String:sKeyType[], Handle:hParamsArr, String:sBuffer[], iBufLen)
{
	decl String:sParam[KEYS_MAX_LENGTH];
	GetArrayString(hParamsArr, 0, sParam, sizeof(sParam));
	FormatEx(sBuffer, iBufLen, "%T: %s", "CREDITS", iClient, sParam);
}
