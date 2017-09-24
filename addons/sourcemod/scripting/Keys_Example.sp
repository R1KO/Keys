#pragma semicolon 1

#include <sourcemod>
#include <keys_core>

public Plugin:myinfo =
{
	name		= "[Keys] Example",
	author	= "R1KO",
	version	= "1.1",
	url		= "hlmod.ru"
};

new const String:g_sKeyType[] = {"examle"};

public OnPluginStart()
{
	LoadTranslations("keys_core.phrases");

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
	LogMessage("OnKeyParamsValidate: '%s'", sKeyType);
	decl i, String:sParam[KEYS_MAX_LENGTH];
	for(i = 0; i < GetArraySize(hParamsArr); ++i)
	{
		GetArrayString(hParamsArr, i, sParam, sizeof(sParam));
		LogMessage("GetArrayString = '%s'", sParam);
	}
	
	SetArrayString(hParamsArr, 1, "rep34");

	return true;
}

public bool:OnKeyUse(iClient, const String:sKeyType[], Handle:hParamsArr, String:sError[], iErrLen)
{
	LogMessage("OnKeyUse: '%s'", sKeyType);

	return true;
}

public OnKeyPrint(iClient, const String:sKeyType[], Handle:hParamsArr, String:sBuffer[], iBufLen)
{
	LogMessage("OnKeyPrint: '%s'", sKeyType);
	FormatEx(sBuffer, iBufLen, "Example");
}
