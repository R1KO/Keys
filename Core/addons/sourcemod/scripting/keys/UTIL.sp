
void UTIL_ReplyToCommand(int iClient, ReplySource CmdReplySource, const char[] szFormat, any ...)
{
	char szBuffer[2048];
	SetGlobalTransTarget(iClient);
	VFormat(SZF(szBuffer), szFormat, 4);
	
	if(iClient)
	{
		switch(CmdReplySource)
		{
			case SM_REPLY_TO_CONSOLE:	PrintToConsole(iClient, "[KEYS] %s", szBuffer);
			case SM_REPLY_TO_CHAT:		PrintToChat(iClient, GetEngineVersion() == Engine_CSGO ? " \x04[KEYS] \x01%s":"\x04[KEYS] \x01%s", szBuffer);
		}	
	}
	else
	{
		PrintToServer("[KEYS] %s", szBuffer);
	}
}

int UTIL_GetRandomInt(int iMin, int iMax)
{
	int iRandom = GetURandomInt();
	
	if (iRandom == 0)
	{
		++iRandom;
	}

	return RoundToCeil(float(iRandom) / (float(2147483647) / float(iMax - iMin + 1))) + iMin - 1;
}

/*
A - Буква в любом регистре
B - Цифра 0-9
X - Цифра 0-9 либо буква в любом регистре
U - число 0-9 либо буква в верхнем регистре
L - число 0-9 либо буква в нижнем регистре
*/

int UTIL_GetCharTemplate(char iChar)
{

	static const int g_iNumbers[] = {0x30, 0x39};
	static const int g_iLettersUpper[] = {0x41, 0x5A};
	static const int g_iLettersLower[] = {0x61, 0x7A};
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