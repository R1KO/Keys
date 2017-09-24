
void CMD_Reg()
{
	// CMD`s for use keys
	RegConsoleCmd("key",		UseKey_CMD);
	RegConsoleCmd("usekey",		UseKey_CMD);	

	// CMD`s for create keys
	RegAdminCmd("key_add",		AddKey_CMD, ADMFLAG_ROOT);
	RegAdminCmd("key_create",	AddKey_CMD, ADMFLAG_ROOT);
	RegAdminCmd("keys_gen",		AddKey_CMD, ADMFLAG_ROOT);
	
	// CMD`s for remove keys
	RegAdminCmd("key_del",		DelKey_CMD, ADMFLAG_ROOT);
	RegAdminCmd("key_rem",		DelKey_CMD, ADMFLAG_ROOT);
	RegAdminCmd("keys_clear",	ClearKeys_CMD, ADMFLAG_ROOT);
	
	// CMD`s for keys output
//	RegAdminCmd("keys_list",		KeysListDump_CMD, ADMFLAG_ROOT);
//	RegAdminCmd("keys_dump",		KeysListDump_CMD, ADMFLAG_ROOT);
}

public Action UseKey_CMD(int iClient, int iArgs)
{
	if (iClient)
	{
		ReplySource CmdReplySource = GetCmdReplySource();

		if(g_CVAR_iAttempts && g_bIsBlocked[iClient])
		{
			if(g_iAttempts[iClient] > GetTime())
			{
				UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_BLOCKED");
				return Plugin_Handled;
				
			}
			else
			{
				Block_SetClientStatus(iClient, false);
			}
		}

		if(iArgs != 1)
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "USAGE_ERROR_USE_KEY");
			return Plugin_Handled;
		}

		char szKey[KEYS_MAX_LENGTH], szQuery[PMP*2];
		GetCmdArg(1, SZF(szKey));

		if(!Keys_Check(szKey, SZF(szQuery)))
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", szQuery);

			if(g_CVAR_iAttempts)
			{
				if(g_iAttempts[iClient]++ >= g_CVAR_iAttempts)
				{
					Block_SetClientStatus(iClient, true);
					UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_BLOCKED");
					return Plugin_Handled;
				}

				UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_INCORRECT_KEY_LEFT", g_CVAR_iAttempts-g_iAttempts[iClient]);
			}
			else
			{
				UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_INCORRECT_KEY");
			}

			return Plugin_Handled;
		}

		Keys_Use(szKey, iClient, CmdReplySource, true, false);
	}

	return Plugin_Handled;
}

public Action AddKey_CMD(int iClient, int iArgs)
{
	ReplySource CmdReplySource = GetCmdReplySource();

	if(iArgs < 5)
	{
		UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_NUM_ARGS");
		return Plugin_Handled;
	}

	char szKey[KEYS_MAX_LENGTH];

	GetCmdArg(0, SZF(szKey));

	bool bGen = (szKey[3] == 's');

	int iCount;
	if(bGen)
	{
		GetCmdArg(1, SZF(szKey));
		iCount = S2I(szKey);
		if(iCount < 1)
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_INCORRECT_AMOUNT");
			return Plugin_Handled;
		}

		szKey[0] = 0;
	}
	else
	{
		GetCmdArg(1, SZF(szKey));
	}

	char szKeyType[KEYS_MAX_LENGTH], szParam[KEYS_MAX_LENGTH], szError[PMP];
	GetCmdArg(4, SZF(szKeyType));

	GetCmdArg(2, SZF(szParam));
	int iLifeTime = S2I(szParam);

	GetCmdArg(3, SZF(szParam));
	int iUses = S2I(szParam);

	ArrayList hParamsArr = new ArrayList(ByteCountToCells(KEYS_MAX_LENGTH));

	for(int i = 5; i <= iArgs; ++i)
	{
		GetCmdArg(i, SZF(szParam));
		hParamsArr.PushString(szParam);
	}

	szError[0] = 0;

	if(!bGen && !Keys_Validate(szKey, szKeyType, iUses, iLifeTime, hParamsArr, SZF(szError), iClient))
	{
		delete hParamsArr;
		UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%s", "ERROR", szError);
		return Plugin_Handled;
	}

	int iExpires = iLifeTime ? (iLifeTime + GetTime()):iLifeTime;
	if(bGen)
	{
		szKey = NULL_STRING;
		LogMessage("LOOP: %d", iCount);
		while(iCount > 0)
		{
			--iCount;
			LogMessage("LOOP ITER: %d", iCount);

			Keys_Add(szKey, szKeyType, iUses, iLifeTime, iExpires, hParamsArr.Clone(), iClient, CmdReplySource);
		}
	}
	else
	{
		Keys_Add(szKey, szKeyType, iUses, iLifeTime, iExpires, hParamsArr.Clone(), iClient, CmdReplySource);
	}

	delete hParamsArr;

	return Plugin_Handled;
}

public Action DelKey_CMD(int iClient, int iArgs)
{
	ReplySource CmdReplySource = GetCmdReplySource();

	if(iArgs != 1)
	{
		UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_NUM_ARGS");
		return Plugin_Handled;
	}

	char szKey[KEYS_MAX_LENGTH], iLength;
	GetCmdArg(1, SZF(szKey));
	
	iLength = strlen(szKey);
	if(iLength > KEYS_MAX_LENGTH || iLength < 8)
	{
		UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_INCORRECT_KEY");
		return Plugin_Handled;
	}

	Keys_Delete(szKey, true, iClient, CmdReplySource);

	return Plugin_Handled;
}

public Action ClearKeys_CMD(int iClient, int iArgs)
{
	ReplySource CmdReplySource = GetCmdReplySource();

	char szKeyType[64];
	if(iArgs == 1)
	{
		GetCmdArg(1, SZF(szKeyType));
		if(FindStringInArray(g_hKeysArray, szKeyType) == -1)
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_INCORRECT_TYPE");
			return Plugin_Handled;
		}
	}
	else
	{
		szKeyType[0] = 0;
	}
	
	char szQuery[PMP], szSID[64];
	DataPack hDP = new DataPack();
	hDP.WriteCell(GET_UID(iClient));
	hDP.WriteCell(CmdReplySource);
	if(szKeyType[0])
	{
		if(!g_CVAR_iServerID)
		{
			szSID[0] = 0;
		}
		else
		{
			FormatEx(SZF(szSID), " AND `k_sid` = %d", g_CVAR_iServerID);
		}

		FormatEx(SZF(szQuery), "DELETE FROM `keys_tokens` WHERE `k_type` = '%s'%s;", szKeyType, szSID);

		hDP.WriteCell(true);
		hDP.WriteString(szKeyType);
	}
	else
	{
		if(!g_CVAR_iServerID)
		{
			szSID[0] = 0;
		}
		else
		{
			FormatEx(SZF(szSID), " WHERE `k_sid` = %d;", g_CVAR_iServerID);
		}

		FormatEx(SZF(szQuery), "DELETE FROM `keys_tokens`%s;", szSID);
	}

	g_hDatabase.Query(SQL_Callback_RemoveKeys, szQuery, hDP);

	return Plugin_Handled;
}

public void SQL_Callback_RemoveKeys(Database hDB, DBResultSet hResult, const char[] szDbError, any hCbDP)
{
	DataPack hDP = view_as<DataPack>(hCbDP);

	if (hResult == null || szDbError[0])
	{
		delete hDP;
		LogError("SQL_Callback_RemoveKeys: %s", szDbError);
		return;
	}

	hDP.Reset();

	int iClient = GET_CID(hDP.ReadCell());
	ReplySource CmdReplySource = view_as<ReplySource>(hDP.ReadCell());
	
	char szKeyType[64], szName[MAX_NAME_LENGTH], szAuth[32];
	
	CmdReplySource = view_as<ReplySource>(hDP.ReadCell());

	if(iClient == -1)
	{
		iClient = 0;
	}

	if(!iClient)
	{
		strcopy(SZF(szName), "CONSOLE");
		strcopy(SZF(szAuth), "STEAM_ID_SERVER");
	}
	else
	{
		GetClientName(iClient, SZF(szName));
		GetClientAuthId(iClient, AuthId_Engine, SZF(szAuth));
	}

	if(hDP.ReadCell())
	{
		hDP.ReadString(SZF(szKeyType));
	}
	else
	{
		szKeyType[0] = 0;
	}

	delete hDP;

	if(hResult.AffectedRows)
	{
		if(szKeyType[0])
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t", "SUCCESS_REMOVE_KEYS_TYPE", szKeyType);
			LogToFile(g_sLogFile, "%T", "LOG_SUCCESS_REMOVE_KEYS_TYPE", LANG_SERVER, szKeyType, szName, szAuth);
		}
		else
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t", "SUCCESS_REMOVE_KEYS");
			LogToFile(g_sLogFile, "%T", "LOG_SUCCESS_REMOVE_KEYS", LANG_SERVER, szKeyType, szName, szAuth);
		}
	}
	else
	{
		if(szKeyType[0])
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_REMOVE_KEYS_TYPE", szKeyType);
			LogToFile(g_sLogFile, "%T", "LOG_ERROR_REMOVE_KEYS_TYPE", LANG_SERVER, szKeyType, szName, szAuth);
		}
		else
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_REMOVE_KEYS");
			LogToFile(g_sLogFile, "%T", "LOG_ERROR_REMOVE_KEYS", LANG_SERVER, szKeyType, szName, szAuth);
		}
	}
}
/*
public Action KeysListDump_CMD(int iClient, int iArgs)
{
	char szQuery[PMP*2], szSID[64];
	ReplySource CmdReplySource = GetCmdReplySource();

	int iOffset = 0;
	if(iArgs)
	{
		GetCmdArg(2, szQuery, 16);
		iOffset = StringToInt(szQuery);
		if(iOffset < 0)
		{
			iOffset = 0;
		}
	}

	DataPack hDP = new DataPack();
	hDP.WriteCell(GET_UID(iClient));
	hDP.WriteCell(CmdReplySource);
	GetCmdArg(0, szQuery, 32);
	bool bToFile = szQuery[5] == 'd';
	hDP.WriteCell(bToFile);

	if(!g_CVAR_iServerID)
	{
		szSID[0] = 0;
	}
	else
	{
		FormatEx(SZF(szSID), " WHERE `k_sid` = %d;", g_CVAR_iServerID);
	}

	if(!g_iServerID)
	{
		FormatEx(SZF(szQuery), "SELECT `k_name`, `k_type`, `k_expires`, `k_uses`, `param1`, `param2`, `param3`, `param4`, `param5` FROM `keys_tokens` ORDER BY `k_type`, `param1`, `param2`, `param3`, `param4`, `param5`, `k_expires`, `k_uses`;");
	}
	else
	{
		FormatEx(SZF(szQuery), "SELECT `k_name`, `k_type`, `k_expires`, `k_uses`, `param1`, `param2`, `param3`, `param4`, `param5` FROM `keys_tokens` WHERE `k_sid` = %d ORDER BY `k_type`, `param1`, `param2`, `param3`, `param4`, `param5`, `k_expires`, `k_uses`;", g_iServerID);
	}
	
	if(!bToFile)
	{
		szQuery[strlen(szQuery)-1] = 0;
		Format(SZF(szQuery), "%s LIMIT %d, %d;", szQuery, iOffset, iClient ? 20:100);
	}

	g_hDatabase.Query(SQL_Callback_SelectKeysList, szQuery, hDP);

	return Plugin_Handled;
}

public void SQL_Callback_SelectKeysList(Database hDB, DBResultSet hResult, const char[] szDbError, any hCbDP)
{
	if (hResult == null || szDbError[0])
	{
		delete hDP;
		LogError("SQL_Callback_SelectKeysList: %s", szDbError);
		return;
	}

	hDP.Reset();
	decl iClient, ReplySource:CmdReplySource, bool:bToFile;
	iClient = GET_CID(hDP.ReadCell());
	CmdReplySource = view_as<ReplySource>(hDP.ReadCell());
	bToFile = view_as<bool>(hDP.ReadCell());
	delete hDP;

	if(!bToFile && iClient == -1)
	{
		return;
	}

	if(SQL_GetRowCount(hResult) > 0)
	{
		char szKey[64], szKeyType[64], sExpires[64], iUses, iCount, iTime, iExpires, i;
		decl Handle:hFile, Handle:hDataPack, Handle:hPlugin, Function:fPrintCallback, ArrayList hParamsArr, szParam[KEYS_MAX_LENGTH], sParams[PMP*2];
		
		if(bToFile)
		{
			BuildPath(Path_SM, SZF(sParams), "data/keys_dump.txt");
			hFile = OpenFile(sParams, "w+");
		}

		iCount = 0;
		iTime = GetTime();

		while(hResult.FetchRow())
		{
			hResult.FetchString(1, SZF(szKeyType));

			if(g_hKeysTrie.GetValue(szKeyType, hDataPack))
			{
				hResult.FetchString(0, SZF(szKey));

				iExpires = hResult.FetchInt(2);

				if(iExpires)
				{
					if(iExpires < iTime)
					{
						Keys_Delete(szKey);
						continue;
					}

					Keys_GetTimeFromStamp(SZF(sExpires), iExpires-iTime, iClient);
				}
				else
				{
					FormatEx(SZF(sExpires), "%T", "FOREVER", iClient);
				}
				
				iUses = hResult.FetchInt(3);

				if(!iUses)
				{
					Keys_Delete(szKey);
					continue;
				}

				hParamsArr = CreateArray(ByteCountToCells(KEYS_MAX_LENGTH));

				for(i = 4; i < 9; ++i)
				{
					if(SQL_IsFieldNull(hResult, i))
					{
						break;
					}
					
					hResult.FetchString(i, SZF(szParam));
					PushArrayString(hParamsArr, szParam);
				}

				sParams[0] = 0;

				hDataPack.Position = DP_Plugin;
				hPlugin = view_as<Handle>(hDataPack.ReadCell());
				hDataPack.Position = DP_OnPrintCallback;
				fPrintCallback = hDataPack.ReadFunction();
				Call_StartFunction(hPlugin, fPrintCallback);
				Call_PushCell(iClient);
				Call_PushString(szKeyType);
				Call_PushCell(hParamsArr);
				Call_PushStringEx(sParams, 256, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
				Call_PushCell(256);
				Call_Finish();

				delete hParamsArr;
				
				if(bToFile)
				{
					WriteFileLine(hFile, "%d. %s\t\t%T: %12s\t\t%T: %4i\t\t%T: %s\t\t%s", ++iCount, szKey, "EXPIRES", iClient, sExpires, "USAGE_LEFT", iClient, iUses, "TYPE", iClient, szKeyType, sParams);
					continue;
				}

				UTIL_ReplyToCommand(iClient, CmdReplySource, "%d. %s\t\t%T: %12s\t\t%T: %4i\t\t%T: %s\t\t%s", ++iCount, szKey, "EXPIRES", iClient, sExpires, "USAGE_LEFT", iClient, iUses, "TYPE", iClient, szKeyType, sParams);
			}
		}
		
		if(bToFile)
		{
			delete hFile;
		}
	}
	else
	{
		UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_LIST_NO_KEYS");
	}
}
*/