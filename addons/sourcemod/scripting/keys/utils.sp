

UTIL_ReplyToCommand(iClient, ReplySource:CmdReplySource, const String:sFormat[], any:...)
{
	static String:sBuffer[2048];
	SetGlobalTransTarget(iClient);
	VFormat(sBuffer, sizeof(sBuffer), sFormat, 4);
	
	if(iClient)
	{
		switch(CmdReplySource)
		{
		case SM_REPLY_TO_CONSOLE:	PrintToConsole(iClient, "[KEYS] %s", sBuffer);
		case SM_REPLY_TO_CHAT:		PrintToChat(iClient, GetEngineVersion() == Engine_CSGO ? " \x04[KEYS] \x01%s":"\x04[KEYS] \x01%s", sBuffer);
		}	
	}
	else
	{
		PrintToServer("[KEYS] %s", sBuffer);
	}
}

bool:UTIL_CheckKey(String:sKey[], const String:sKeyType[], iLifeTime, iUses, Handle:hParamsArr, String:sError[], iErrLen, iClient = LANG_SERVER)
{
	decl Handle:hDataPack;

	if(!GetTrieValue(g_hKeysTrie, sKeyType, hDataPack))
	{
		FormatEx(sError, iErrLen, "%T%T", "ERROR", iClient, "ERROR_INCORRECT_TYPE", iClient);
		return false;
	}

	if(sKey[0])
	{
		if(!UTIL_ValidateKey(sKey, sError, iErrLen))
		{
			return false;
		}
	}

	if(iLifeTime < 0)
	{
		FormatEx(sError, iErrLen, "%T%T", "ERROR", iClient, "ERROR_INCORRECT_LIFETIME", iClient);
		return false;
	}

	if(iUses < 1)
	{
		FormatEx(sError, iErrLen, "%T%T", "ERROR", iClient, "ERROR_INCORRECT_USES", iClient);
		return false;
	}

	decl Handle:hPlugin, Function:FuncOnValidateParams, bool:bResult;

	SetPackPosition(hDataPack, DP_Plugin);
	hPlugin = Handle:ReadPackCell(hDataPack);

	SetPackPosition(hDataPack, DP_OnValidateCallback);
	FuncOnValidateParams = Function:ReadPackCell(hDataPack);

	sError = "unknown";
	bResult = false;
	Call_StartFunction(hPlugin, FuncOnValidateParams);
	Call_PushCell(iClient);
	Call_PushString(sKeyType);
	Call_PushCell(hParamsArr);
	Call_PushStringEx(SZF(sError), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(sizeof(sError));
	Call_Finish(bResult);

	if(!bResult)
	{
		FormatEx(sError, iErrLen, "%T%s", "ERROR", iClient, sError);
		return false;
	}

	return true;
}

bool:UTIL_AddKey(const String:sKey[],
const String:sKeyType[],
iLifeTime,
iExpires,
iUses,
Handle:hParamsArr,
iClient,
bool:bDuplicateErr)
{
	hDP = CreateDataPack();
	WritePackCell(hDP, hParamsArr);
	WritePackString(hDP, sKey);
	WritePackCell(hDP, false);
	WritePackCell(hDP, iClient);
	WritePackCell(hDP, CmdReplySource);
	WritePackString(hDP, sKeyType);
	WritePackCell(hDP, iUses);
	WritePackCell(hDP, iExpires);
	WritePackCell(hDP, iLifeTime);
	
	if(!g_iServerID)
	{
		FormatEx(SZF(sQuery), "SELECT `expires` FROM `table_keys` WHERE `key_name` = '%s';", sKey);
	}
	else
	{
		FormatEx(SZF(sQuery), "SELECT `expires` FROM `table_keys` WHERE `key_name` = '%s' AND `sid` = %d;", sKey, g_iServerID);
	}
	SQL_TQuery(g_hDatabase, SQL_Callback_SearchKey, sQuery, hDP);
}

UTIL_ValidateKey(String:sKey[], String:sError[], iErrLen)
{
	if(!sKey[0])
	{
		strcopy(sError, iErrLen, "ERROR_KEY_EMPTY");
		return false;
	}

	new iLength = strlen(sKey);
	if(iLength < 8)
	{
		strcopy(sError, iErrLen, "ERROR_KEY_SHORT");
		return false;
	}

	if(iLength > 64)
	{
		strcopy(sError, iErrLen, "ERROR_KEY_LONG");
		return false;
	}

	new i = 0;

	while (i < iLength)
	{
		if((sKey[i] > 0x2F && sKey[i] < 0x3A) ||
				(sKey[i] > 0x40 && sKey[i] < 0x5B) ||
				(sKey[i] > 0x60 && sKey[i] < 0x7B) ||
				sKey[i] == 0x2D)
		{
			++i;
			continue;
		}

		strcopy(sError, iErrLen, "ERROR_KEY_INVALID_CHARACTERS");
		return false;
	}

	return true;
}

UTIL_GenerateKey(String:sKey[], iMaxLen, const String:sTemplate[] = NULL_STRING)
{
	sKey[0] = '\0';
	
	new i = 0;

	if(g_CVAR_sKeyTemplate[0])
	{
		new iLength = strlen(g_CVAR_sKeyTemplate);
		while (i < iLength && i < iMaxLen)
		{
			sKey[i] = UTIL_GetCharTemplate(g_CVAR_sKeyTemplate[i]);
			++i;
		}
	}
	else
	{
		while (i < g_CVAR_iKeyLength && i < iMaxLen)
		{
			sKey[i] = UTIL_GetCharTemplate(0x58);
			++i;
		}
	}

	sKey[i] = '\0';
}
/*
A - Буква в любом регистре
B - Цифра 0-9
X - Цифра 0-9 либо буква в любом регистре
U - число 0-9 либо буква в верхнем регистре
L - число 0-9 либо буква в нижнем регистре
*/

static const g_iNumbers[] = {0x30, 0x39};
static const g_iLettersUpper[] = {0x41, 0x5A};
static const g_iLettersLower[] = {0x61, 0x7A};

UTIL_GetCharTemplate(iChar)
{
	switch(iChar)
	{
		// A - буква в любом регистре
		case 0x41:	return UTIL_GetRandomInt(1, 20) > 10 ? UTIL_GetRandomInt(g_iLettersUpper[0], g_iLettersUpper[1]):UTIL_GetRandomInt(g_iLettersLower[0], g_iLettersLower[1]);
		// B - число 0-9
		case 0x42:	return UTIL_GetRandomInt(g_iNumbers[0], g_iNumbers[1]);
		// X - число 0-9 либо буква в любом регистре
		case 0x58:	return UTIL_GetRandomInt(0, 2) == 1 ? UTIL_GetRandomInt(g_iNumbers[0], g_iNumbers[1]):(UTIL_GetRandomInt(1, 20) > 10 ? UTIL_GetRandomInt(g_iLettersUpper[0], g_iLettersUpper[1]):UTIL_GetRandomInt(g_iLettersLower[0], g_iLettersLower[1]));
		// U - число 0-9 либо буква в верхнем регистре
		case 0x55:	return UTIL_GetRandomInt(0, 2) == 1 ? UTIL_GetRandomInt(g_iNumbers[0], g_iNumbers[1]):UTIL_GetRandomInt(g_iLettersUpper[0], g_iLettersUpper[1]);
		// L - число 0-9 либо буква в нижнем регистре
		case 0x4c:	return UTIL_GetRandomInt(0, 2) == 1 ? UTIL_GetRandomInt(g_iNumbers[0], g_iNumbers[1]):UTIL_GetRandomInt(g_iLettersLower[0], g_iLettersLower[1]);
		// Символ -
		case 0x2D:	return iChar;
		// Другой символ
		default:
		{
			return UTIL_GetCharTemplate(0x58);
		}
	}

	return iChar;
}

UTIL_GetRandomInt(iMin, iMax)
{
	new iRandom = GetURandomInt();
	
	if (iRandom == 0)
	{
		++iRandom;
	}

	return RoundToCeil(float(iRandom) / (float(2147483647) / float(iMax - iMin + 1))) + iMin - 1;
}
