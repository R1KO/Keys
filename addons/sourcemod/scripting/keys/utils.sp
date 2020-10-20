

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
		// case SM_REPLY_TO_CHAT:		PrintToChat(iClient, GetEngineVersion() == Engine_CSGO ? " \x04[KEYS] \x01%s":"\x04[KEYS] \x01%s", sBuffer);
		case SM_REPLY_TO_CHAT:		PrintToChat(iClient, GetEngineVersion() == Engine_CSGO ? " %t \x01%s":"%t \x01%s", "CHAT_PREFIX", sBuffer);
		}	
	}
	else
	{
		PrintToServer("[KEYS] %s", sBuffer);
	}
}

UTIL_ValidateKey(String:sKey[], iLength, String:sError[], iErrLen)
{
	if(!sKey[0])
	{
		strcopy(sError, iErrLen, "ERROR_KEY_EMPTY");
		return false;
	}

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

UTIL_GenerateKey(String:sKey[])
{
	sKey[0] = '\0';
	
	new i = 0;

	if(g_CVAR_sKeyTemplate[0])
	{
		new iLength = strlen(g_CVAR_sKeyTemplate);
		while (i < iLength)
		{
			sKey[i] = UTIL_GetCharTemplate(g_CVAR_sKeyTemplate[i]);
			++i;
		}
	}
	else
	{
		while (i < g_CVAR_iKeyLength)
		{
			sKey[i] = UTIL_GetCharTemplate(0x58);
			++i;
		}
	}

	sKey[i] = '\0';
}
/*
A - Буква в любом регистре\n\
B - Цифра 0-9\n\
X - Цифра 0-9 либо буква в любом регистре\n\
*/

static const g_iNumbers[] = {0x30, 0x39};
static const g_iLettersUpper[] = {0x41, 0x5A};
static const g_iLettersLower[] = {0x61, 0x7A};

UTIL_GetCharTemplate(iChar)
{
	switch(iChar)
	{
		// A - буква в любом регистре
	case 0x41:	return GetRandomInt(1, 20) > 10 ? UTIL_GetRandomInt(g_iLettersUpper[0], g_iLettersUpper[1]):UTIL_GetRandomInt(g_iLettersLower[0], g_iLettersLower[1]);
		// B - число 0-9
	case 0x42:	return UTIL_GetRandomInt(g_iNumbers[0], g_iNumbers[1]);
		// X - число 0-9 либо буква в любом регистре
	case 0x58:	return GetRandomInt(0, 2) == 1 ? UTIL_GetRandomInt(g_iNumbers[0], g_iNumbers[1]):(GetRandomInt(1, 20) > 10 ? UTIL_GetRandomInt(g_iLettersUpper[0], g_iLettersUpper[1]):UTIL_GetRandomInt(g_iLettersLower[0], g_iLettersLower[1]));
		// U - число 0-9 либо буква в верхнем регистре
	case 0x55:	return GetRandomInt(0, 2) == 1 ? UTIL_GetRandomInt(g_iNumbers[0], g_iNumbers[1]):UTIL_GetRandomInt(g_iLettersUpper[0], g_iLettersUpper[1]);
		// L - число 0-9 либо буква в нижнем регистре
	case 0x4c:	return GetRandomInt(0, 2) == 1 ? UTIL_GetRandomInt(g_iNumbers[0], g_iNumbers[1]):UTIL_GetRandomInt(g_iLettersLower[0], g_iLettersLower[1]);
		// Другой символ
	default:	return iChar;
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
