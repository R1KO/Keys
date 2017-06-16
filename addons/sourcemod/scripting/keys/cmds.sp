#define GET_UID(%0) (%0 == 0 ? 0:UID(%0))

GET_CID(iClient)
{
	if(iClient)
	{
		iClient = CID(iClient);
		if(!iClient)
		{
			return -1;
		}

		return iClient;
	}
	
	return 0;
}

RegAdminCmds()
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
	RegAdminCmd("keys_list",		KeysListDump_CMD, ADMFLAG_ROOT);
	RegAdminCmd("keys_dump",		KeysListDump_CMD, ADMFLAG_ROOT);
}

public Action:UseKey_CMD(iClient, iArgs)
{
	if (iClient)
	{
		new ReplySource:CmdReplySource = GetCmdReplySource();

		if(g_CVAR_iAttempts && g_bIsBlocked[iClient])
		{
			if(g_iAttempts[iClient] > GetTime())
			{
				UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_BLOCKED");
				return Plugin_Handled;
				
			}
			else
			{
				UnBlockClient(iClient);
				g_bIsBlocked[iClient] = false;
				g_iAttempts[iClient] = 0;
			}
		}

		if(iArgs != 1)
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "USAGE_ERROR_USE_KEY");
			return Plugin_Handled;
		}

		decl String:sKey[KEYS_MAX_LENGTH], String:sQuery[512];
		GetCmdArg(1, SZF(sKey));

		if(!UTIL_ValidateKey(sKey, strlen(sKey), SZF(sQuery)))
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", sQuery);

			if(g_CVAR_iAttempts)
			{
				if(g_iAttempts[iClient]++ >= g_CVAR_iAttempts)
				{
					BlockClient(iClient);
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

		decl Handle:hDP, String:sAuth[32];
		hDP = CreateDataPack();
		WritePackCell(hDP, UID(iClient));
		WritePackCell(hDP, CmdReplySource);

		GetClientAuthId(iClient, AuthId_Engine, SZF(sAuth));
		if (g_bDBMySQL)
		{
			if(!g_iServerID)
			{
				FormatEx(SZF(sQuery), "SELECT `key_name`, `type`, `expires`, `uses`, IF((SELECT `key_name` FROM `keys_players_used` WHERE `auth` = '%s' AND `key_name` = '%s') IS NULL, 0, 1) as `used`, `param1`, `param2`, `param3`, `param4`, `param5` FROM `table_keys` WHERE `key_name` = '%s' LIMIT 1;", sAuth, sKey, sKey);
			}
			else
			{
				FormatEx(SZF(sQuery), "SELECT `key_name`, `type`, `expires`, `uses`, IF((SELECT `key_name` FROM `keys_players_used` WHERE `auth` = '%s' AND `key_name` = '%s') IS NULL, 0, 1) as `used`, `param1`, `param2`, `param3`, `param4`, `param5` FROM `table_keys` WHERE `key_name` = '%s' AND `sid` = %d LIMIT 1;", sAuth, sKey, sKey, g_iServerID);
			}
		}
		else
		{
			FormatEx(SZF(sQuery), "SELECT `key_name`, `type`, `expires`, `uses`, CASE WHEN (SELECT `key_name` FROM `keys_players_used` WHERE `auth` = '%s' AND `key_name` = '%s') IS NULL THEN 0 ELSE 1 END AS `used`, `param1`, `param2`, `param3`, `param4`, `param5` FROM `table_keys` WHERE `key_name` = '%s' LIMIT 1;", sAuth, sKey, sKey);
		}

		SQL_TQuery(g_hDatabase, SQL_Callback_UseKey, sQuery, hDP);
	}

	return Plugin_Handled;
}

public SQL_Callback_UseKey(Handle:hOwner, Handle:hResult, const String:sDBError[], any:hDP)
{
	if (hResult == INVALID_HANDLE || sDBError[0])
	{
		CloseHandle(hDP);
		LogError("SQL_Callback_UseKey: %s", sDBError);
		return;
	}
	
	ResetPack(hDP);

	new iClient = CID(ReadPackCell(hDP));
	new ReplySource:CmdReplySource = ReplySource:ReadPackCell(hDP);
	CloseHandle(hDP);

	if (iClient)
	{
		if(SQL_FetchRow(hResult))
		{
			decl Handle:hDataPack, String:sKeyType[KEYS_MAX_LENGTH];
			SQL_FetchString(hResult, 1, SZF(sKeyType));
			if(GetTrieValue(g_hKeysTrie, sKeyType, hDataPack))
			{
				decl Handle:hPlugin, Function:fUseCallback, Handle:hParamsArr, String:sKey[KEYS_MAX_LENGTH], String:sParam[KEYS_MAX_LENGTH], String:sError[256], iExpires, iUses, i, bool:bResult;
				SQL_FetchString(hResult, 0, SZF(sKey));

				iExpires = SQL_FetchInt(hResult, 2);
				if(iExpires)
				{
					if(iExpires < GetTime())
					{
						DeleteKey(sKey);
						UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_KEY_NOT_EXIST");
						return;
					}
				}

				iUses = SQL_FetchInt(hResult, 3);
				if(!iUses)
				{
					DeleteKey(sKey);
					UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_KEY_NOT_EXIST");
					return;
				}
				
				if(SQL_FetchInt(hResult, 4))
				{
					UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_KEY_ALREADY_USED");
					return;
				}

				hParamsArr = CreateArray(ByteCountToCells(KEYS_MAX_LENGTH));
				for(i = 5; i < 10; ++i)
				{
					if(SQL_IsFieldNull(hResult, i))
					{
						break;
					}
					
					SQL_FetchString(hResult, i, SZF(sParam));
					PushArrayString(hParamsArr, sParam);
				}

				SetPackPosition(hDataPack, DP_Plugin);
				hPlugin = Handle:ReadPackCell(hDataPack);

				SetPackPosition(hDataPack, DP_OnUseCallback);
				fUseCallback = Function:ReadPackCell(hDataPack);

				sError = "unknown";
				bResult = false;
				Call_StartFunction(hPlugin, fUseCallback);
				Call_PushCell(iClient);
				Call_PushString(sKeyType);
				Call_PushCell(hParamsArr);
				Call_PushStringEx(SZF(sError), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
				Call_PushCell(sizeof(sError));
				Call_Finish(bResult);

				CloseHandle(hParamsArr);

				if(!bResult)
				{
					UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%s", "ERROR", sError);
					return;
				}

				decl String:sName[MAX_NAME_LENGTH], String:sAuth[32], String:sQuery[256];
				GetClientName(iClient, SZF(sName));
				GetClientAuthId(iClient, AuthId_Engine, SZF(sAuth));

				if(--iUses)
				{
					if(!g_iServerID)
					{
						FormatEx(SZF(sQuery), "INSERT INTO `keys_players_used` (`auth`, `key_name`) VALUES ('%s', '%s');", sAuth, sKey);
					}
					else
					{
						FormatEx(SZF(sQuery), "INSERT INTO `keys_players_used` (`auth`, `key_name`, `sid`) VALUES ('%s', '%s', %d);", sAuth, sKey, g_iServerID);
					}
					SQL_TQuery(g_hDatabase, SQL_Callback_ErrorCheck, sQuery);

					if(!g_iServerID)
					{
						FormatEx(SZF(sQuery), "UPDATE `table_keys` SET `uses` = %d WHERE `key_name` = '%s';", iUses, sKey);
					}
					else
					{
						FormatEx(SZF(sQuery), "UPDATE `table_keys` SET `uses` = %d WHERE `key_name` = '%s' AND `sid` = %d;", iUses, sKey, g_iServerID);
					}
					SQL_TQuery(g_hDatabase, SQL_Callback_ErrorCheck, sQuery);
				}
				else
				{
					DeleteKey(sKey);
					if(!g_iServerID)
					{
						FormatEx(SZF(sQuery), "DELETE FROM `keys_players_used` WHERE `key_name` = '%s';", sKey);
					}
					else
					{
						FormatEx(SZF(sQuery), "DELETE FROM `keys_players_used` WHERE `key_name` = '%s' AND `sid` = %d;", sKey, g_iServerID);
					}
					SQL_TQuery(g_hDatabase, SQL_Callback_ErrorCheck, sQuery);
				}

				UTIL_ReplyToCommand(iClient, CmdReplySource, "%t", "SUCCESS_USE_KEY", sKey);
				LogToFile(g_sLogFile, "%T", "LOG_SUCCESS_USE_KEY", LANG_SERVER, sName, sAuth, sKey);
				return;
			}

			return;
		}
		
		if(g_CVAR_iAttempts)
		{
			if(g_iAttempts[iClient]++ >= g_CVAR_iAttempts)
			{
				BlockClient(iClient);
				UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_BLOCKED");
				return;
			}

			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_INCORRECT_KEY_LEFT", g_CVAR_iAttempts-g_iAttempts[iClient]);
		}
		else
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_INCORRECT_KEY");
		}
	}
}

public Action:AddKey_CMD(iClient, iArgs)
{
	new ReplySource:CmdReplySource = GetCmdReplySource();

	if(iArgs < 5)
	{
		UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_NUM_ARGS");
		return Plugin_Handled;
	}

	decl String:sKeyType[KEYS_MAX_LENGTH], Handle:hDataPack;
	GetCmdArg(4, SZF(sKeyType));

	if(!GetTrieValue(g_hKeysTrie, sKeyType, hDataPack))
	{
		UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_INCORRECT_TYPE");
		return Plugin_Handled;
	}

	decl String:sKey[KEYS_MAX_LENGTH], String:sParam[KEYS_MAX_LENGTH], String:sError[256], iLifeTime, iUses, iCount, bool:bGen;

	GetCmdArg(0, SZF(sKey));
	
	bGen = bool:(sKey[3] == 's');

	if(bGen)
	{
		GetCmdArg(1, SZF(sParam));
		iCount = StringToInt(sParam);
		if(iCount < 1)
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_INCORRECT_AMOUNT");
			return Plugin_Handled;
		}
	}
	else
	{
		GetCmdArg(1, SZF(sKey));
		if(!UTIL_ValidateKey(sKey, strlen(sKey), SZF(sError)))
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t", sError);
			return Plugin_Handled;
		}
	}

	GetCmdArg(2, SZF(sParam));
	iLifeTime = StringToInt(sParam);
	if(iLifeTime < 0)
	{
		UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_INCORRECT_LIFETIME");
		return Plugin_Handled;
	}

	GetCmdArg(3, SZF(sParam));
	iUses = StringToInt(sParam);
	if(iUses < 1)
	{
		UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_INCORRECT_USES");
		return Plugin_Handled;
	}

	decl Handle:hParamsArr, Handle:hPlugin, Function:FuncOnValidateParams, i, bool:bResult;

	hParamsArr = CreateArray(ByteCountToCells(KEYS_MAX_LENGTH));

	for(i = 5; i <= iArgs; ++i)
	{
		GetCmdArg(i, SZF(sParam));
		PushArrayString(hParamsArr, sParam);
	}

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
		CloseHandle(hParamsArr);
		UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%s", "ERROR", sError);
		return Plugin_Handled;
	}

	decl Handle:hDP, String:sQuery[256], iExpires;

	iClient = GET_UID(iClient);
	iExpires = iLifeTime ? (iLifeTime + GetTime()):iLifeTime;

	if(bGen)
	{
		while(iCount > 0)
		{
			--iCount;

			UTIL_GenerateKey(sKey);

			hDP = CreateDataPack();
			WritePackCell(hDP, CloneArray(hParamsArr));
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
	}
	else
	{
		hDP = CreateDataPack();
		WritePackCell(hDP, CloneArray(hParamsArr));
		WritePackString(hDP, sKey);
		WritePackCell(hDP, true);
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

	CloseHandle(hParamsArr);

	return Plugin_Handled;
}

public SQL_Callback_SearchKey(Handle:hOwner, Handle:hResult, const String:sError[], any:hDP)
{
	ResetPack(hDP);

	new Handle:hParamsArr = Handle:ReadPackCell(hDP);

	if (hResult == INVALID_HANDLE || sError[0])
	{
		LogError("SQL_Callback_SearchKey: %s", sError);
		CloseHandle(hParamsArr);
		CloseHandle(hDP);
		return;
	}

	decl String:sQuery[1024], String:sKey[KEYS_MAX_LENGTH], i;
	ReadPackString(hDP, SZF(sKey));
	
	if(SQL_FetchRow(hResult))
	{
		if(ReadPackCell(hDP))
		{
			i = GET_CID(ReadPackCell(hDP));
			if(i != -1)
			{
				UTIL_ReplyToCommand(i, ReplySource:ReadPackCell(hDP), "%t%t", "ERROR", "ERROR_KEY_ALREADY_EXISTS", sKey);
			}

			CloseHandle(hParamsArr);
			return;
		}
		else
		{
			decl Handle:hDP2;
			hDP2 = CreateDataPack();
			WritePackCell(hDP2, hParamsArr);
			UTIL_GenerateKey(sKey);
			WritePackString(hDP2, sKey); // New Key
			WritePackCell(hDP2, false);
			i = ReadPackCell(hDP); // Client
			WritePackCell(hDP2, i);
			i = ReadPackCell(hDP); // CmdReplySource
			WritePackCell(hDP2, i);
			ReadPackString(hDP, SZF(sKey));
			WritePackString(hDP2, sKey);
			i = ReadPackCell(hDP); // Uses
			WritePackCell(hDP2, i);
			i = ReadPackCell(hDP); // Expires
			WritePackCell(hDP2, i);
			i = ReadPackCell(hDP); // LifeTime
			WritePackCell(hDP2, i);
			CloseHandle(hDP);
			
			if(!g_iServerID)
			{
				FormatEx(SZF(sQuery), "SELECT `expires` FROM `table_keys` WHERE `key_name` = '%s';", sKey);
			}
			else
			{
				FormatEx(SZF(sQuery), "SELECT `expires` FROM `table_keys` WHERE `key_name` = '%s' AND `sid` = %d;", sKey, g_iServerID);
			}
			SQL_TQuery(g_hDatabase, SQL_Callback_SearchKey, sQuery, hDP2);
		}

		return;
	}

	decl String:sBufferColumns[256], String:sBufferValues[256], String:sKeyType[KEYS_MAX_LENGTH], String:sParam[KEYS_MAX_LENGTH], iExpires, iUses;

	ReadPackCell(hDP); // ...
	ReadPackCell(hDP); // Client
	ReadPackCell(hDP); // CmdReplySource

	ReadPackString(hDP, SZF(sKeyType));

	iUses = ReadPackCell(hDP);
	iExpires = ReadPackCell(hDP);

	strcopy(SZF(sBufferColumns), "`param1`");
	GetArrayString(hParamsArr, 0, SZF(sParam));
	FormatEx(SZF(sBufferValues), "'%s'", sParam);

	for(i = 1; i < GetArraySize(hParamsArr); ++i)
	{
		Format(SZF(sBufferColumns), "%s, `param%d`", sBufferColumns, i+1);
		GetArrayString(hParamsArr, i, SZF(sParam));
		Format(SZF(sBufferValues), "%s, '%s'", sBufferValues, sParam);
	}

	if(!g_iServerID)
	{
		FormatEx(SZF(sQuery), "INSERT INTO `table_keys` (`key_name`, `type`, `expires`, `uses`, %s) VALUES ('%s', '%s', %d, %d, %s);", sBufferColumns, sKey, sKeyType, iExpires, iUses, sBufferValues);
		
	}
	else
	{
		FormatEx(SZF(sQuery), "INSERT INTO `table_keys` (`key_name`, `type`, `expires`, `uses`, `sid`, %s) VALUES ('%s', '%s', %d, %d, %d, %s);", sBufferColumns, sKey, sKeyType, iExpires, iUses, g_iServerID, sBufferValues);
		
	}
	SQL_TQuery(g_hDatabase, SQL_Callback_AddKey, sQuery, hDP);
}

public SQL_Callback_AddKey(Handle:hOwner, Handle:hResult, const String:sError[], any:hDP)
{
	ResetPack(hDP);

	new Handle:hParamsArr = Handle:ReadPackCell(hDP);

	if (hResult == INVALID_HANDLE || sError[0])
	{
		LogError("SQL_Callback_AddKey: %s", sError);
		CloseHandle(hParamsArr);
		CloseHandle(hDP);
		return;
	}

	decl Handle:hDataPack, Handle:hPlugin, Function:fPrintCallback, String:sKey[KEYS_MAX_LENGTH], String:sKeyType[KEYS_MAX_LENGTH], String:sParams[512], String:sName[MAX_NAME_LENGTH], String:sAuth[32], String:sExpires[64], iLifeTime, iUses, iClient, ReplySource:CmdReplySource;
	ReadPackString(hDP, SZF(sKey));
	ReadPackCell(hDP);
	iClient = GET_CID(ReadPackCell(hDP));
	CmdReplySource = ReplySource:ReadPackCell(hDP);

	ReadPackString(hDP, SZF(sKeyType));

	iUses = ReadPackCell(hDP);
	ReadPackCell(hDP);
	iLifeTime = ReadPackCell(hDP);

	if(iClient == -1)
	{
		iClient = 0;
	}
	
	if(!iClient)
	{
		strcopy(SZF(sName), "CONSOLE");
		strcopy(SZF(sAuth), "STEAM_ID_SERVER");
	}
	else
	{
		GetClientName(iClient, SZF(sName));
		GetClientAuthId(iClient, AuthId_Engine, SZF(sAuth));
	}
	
	if(iLifeTime)
	{
		Keys_GetTimeFromStamp(SZF(sExpires), iLifeTime, iClient);
	}
	else
	{
		FormatEx(SZF(sExpires), "%T", "FOREVER", iClient);
	}
	
	sParams[0] = 0;

	GetTrieValue(g_hKeysTrie, sKeyType, hDataPack);
	SetPackPosition(hDataPack, DP_Plugin);
	hPlugin = Handle:ReadPackCell(hDataPack);
	SetPackPosition(hDataPack, DP_OnPrintCallback);
	fPrintCallback = Function:ReadPackCell(hDataPack);
	Call_StartFunction(hPlugin, fPrintCallback);
	Call_PushCell(LANG_SERVER);
	Call_PushString(sKeyType);
	Call_PushCell(hParamsArr);
	Call_PushStringEx(SZF(sParams), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(sizeof(sParams));
	Call_Finish();

	if(SQL_GetAffectedRows(hOwner))
	{
		if(iClient != -1)
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t", "SUCCESS_CREATE_KEY", sKey);
		}
		
		LogToFile(g_sLogFile, "%T", "LOG_SUCCESS_CREATE_KEY", LANG_SERVER, sName, sAuth, sKey, sExpires, iUses, sKeyType, sParams);
	}
	else
	{
		if(iClient != -1)
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_CREATE_KEY", sKey);
		}

		LogToFile(g_sLogFile, "%T", "LOG_ERROR_CREATE_KEY", LANG_SERVER, sKey, sName, sAuth, sExpires, iUses, sKeyType, sParams);
	}

	CloseHandle(hParamsArr);
	CloseHandle(hDP);
}

public Action:DelKey_CMD(iClient, iArgs)
{
	new ReplySource:CmdReplySource = GetCmdReplySource();

	if(iArgs != 1)
	{
		UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_NUM_ARGS");
		return Plugin_Handled;
	}

	decl String:sKey[KEYS_MAX_LENGTH], iLength;
	GetCmdArg(1, SZF(sKey));
	
	iLength = strlen(sKey);
	if(iLength > KEYS_MAX_LENGTH || iLength < 8)
	{
		UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_INCORRECT_KEY");
		return Plugin_Handled;
	}

	DeleteKey(sKey, iClient, CmdReplySource);

	return Plugin_Handled;
}

public SQL_Callback_RemoveKey(Handle:hOwner, Handle:hResult, const String:sError[], any:hDP)
{
	if (hResult == INVALID_HANDLE || sError[0])
	{
		CloseHandle(hDP);
		LogError("SQL_Callback_RemoveKey: %s", sError);
		return;
	}

	ResetPack(hDP);

	decl String:sKey[KEYS_MAX_LENGTH];
	ReadPackString(hDP, SZF(sKey));
	
	if(ReadPackCell(hDP))
	{
		decl iClient, String:sName[MAX_NAME_LENGTH], String:sAuth[32], ReplySource:CmdReplySource;
		iClient = GET_CID(ReadPackCell(hDP));
		CmdReplySource = ReplySource:ReadPackCell(hDP);

		if(iClient == -1)
		{
			iClient = 0;
		}

		if(!iClient)
		{
			strcopy(SZF(sName), "CONSOLE");
			strcopy(SZF(sAuth), "STEAM_ID_SERVER");
		}
		else
		{
			GetClientName(iClient, SZF(sName));
			GetClientAuthId(iClient, AuthId_Engine, SZF(sAuth));
		}

		if(SQL_GetAffectedRows(hOwner))
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t", "SUCCESS_REMOVE_KEY", sKey);

			LogToFile(g_sLogFile, "%T", "LOG_SUCCESS_REMOVE_KEY", LANG_SERVER, sKey, sName, sAuth);
		}
		else
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_REMOVE_KEY", sKey);

			LogToFile(g_sLogFile, "%T", "LOG_SUCCESS_REMOVE_KEY", LANG_SERVER, sKey, sName, sAuth);
		}
	}
	else
	{
		if(SQL_GetAffectedRows(hOwner))
		{
			LogToFile(g_sLogFile, "%T", "SUCCESS_REMOVE_KEY", LANG_SERVER, sKey);
		}
		else
		{
			LogToFile(g_sLogFile, "%T", "ERROR_REMOVE_KEY", LANG_SERVER, sKey);
		}
	}

	CloseHandle(hDP);
}

public Action:ClearKeys_CMD(iClient, iArgs)
{
	new ReplySource:CmdReplySource = GetCmdReplySource();

	decl String:sKeyType[64];
	if(iArgs == 1)
	{
		GetCmdArg(1, SZF(sKeyType));
		if(FindStringInArray(g_hKeysArray, sKeyType) == -1)
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_INCORRECT_TYPE");
			return Plugin_Handled;
		}
	}
	else
	{
		sKeyType[0] = 0;
	}
	
	decl Handle:hDP, String:sQuery[256];
	hDP = CreateDataPack();
	WritePackCell(hDP, GET_UID(iClient));
	WritePackCell(hDP, CmdReplySource);
	if(sKeyType[0])
	{
		if(!g_iServerID)
		{
			FormatEx(SZF(sQuery), "DELETE FROM `table_keys` WHERE `type` = '%s';", sKeyType);
		}
		else
		{
			FormatEx(SZF(sQuery), "DELETE FROM `table_keys` WHERE `type` = '%s' AND `sid` = %d;", sKeyType, g_iServerID);
		}
		WritePackCell(hDP, true);
		WritePackString(hDP, sKeyType);
	}
	else
	{
		if(!g_iServerID)
		{
			FormatEx(SZF(sQuery), "DELETE FROM `table_keys`;");
		}
		else
		{
			FormatEx(SZF(sQuery), "DELETE FROM `table_keys` WHERE `sid` = %d;", g_iServerID);
		}
	}

	SQL_TQuery(g_hDatabase, SQL_Callback_RemoveKeys, sQuery, hDP);

	return Plugin_Handled;
}

public SQL_Callback_RemoveKeys(Handle:hOwner, Handle:hResult, const String:sError[], any:hDP)
{
	if (hResult == INVALID_HANDLE || sError[0])
	{
		LogError("SQL_Callback_RemoveKeys: %s", sError);
		CloseHandle(hDP);
		return;
	}

	ResetPack(hDP);

	decl iClient, String:sKeyType[64], String:sName[MAX_NAME_LENGTH], String:sAuth[32], ReplySource:CmdReplySource;
	iClient = GET_CID(ReadPackCell(hDP));
	CmdReplySource = ReplySource:ReadPackCell(hDP);

	if(iClient == -1)
	{
		iClient = 0;
	}

	if(!iClient)
	{
		strcopy(SZF(sName), "CONSOLE");
		strcopy(SZF(sAuth), "STEAM_ID_SERVER");
	}
	else
	{
		GetClientName(iClient, SZF(sName));
		GetClientAuthId(iClient, AuthId_Engine, SZF(sAuth));
	}

	if(IsPackReadable(hDP, 4))
	{
		ReadPackCell(hDP);
		ReadPackString(hDP, SZF(sKeyType));
	}
	else
	{
		sKeyType[0] = 0;
	}

	CloseHandle(hDP);

	if(SQL_GetAffectedRows(hOwner))
	{
		if(sKeyType[0])
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t", "SUCCESS_REMOVE_KEYS_TYPE", sKeyType);
			LogToFile(g_sLogFile, "%T", "LOG_SUCCESS_REMOVE_KEYS_TYPE", LANG_SERVER, sKeyType, sName, sAuth);
		}
		else
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t", "SUCCESS_REMOVE_KEYS");
			LogToFile(g_sLogFile, "%T", "LOG_SUCCESS_REMOVE_KEYS", LANG_SERVER, sKeyType, sName, sAuth);
		}
	}
	else
	{
		if(sKeyType[0])
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_REMOVE_KEYS_TYPE", sKeyType);
			LogToFile(g_sLogFile, "%T", "LOG_ERROR_REMOVE_KEYS_TYPE", LANG_SERVER, sKeyType, sName, sAuth);
		}
		else
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_REMOVE_KEYS");
			LogToFile(g_sLogFile, "%T", "LOG_ERROR_REMOVE_KEYS", LANG_SERVER, sKeyType, sName, sAuth);
		}
	}
}

public Action:KeysListDump_CMD(iClient, iArgs)
{
	decl ReplySource:CmdReplySource, Handle:hDP, String:sQuery[512], iOffset, bool:bToFile;
	CmdReplySource = GetCmdReplySource();

	if(iArgs)
	{
		GetCmdArg(2, sQuery, 16);
		iOffset = StringToInt(sQuery);
		if(iOffset < 0)
		{
			iOffset = 0;
		}
	}
	else
	{
		iOffset = 0;
	}

	hDP = CreateDataPack();
	WritePackCell(hDP, GET_UID(iClient));
	WritePackCell(hDP, CmdReplySource);
	GetCmdArg(0, sQuery, 32);
	bToFile = sQuery[5] == 'd';
	WritePackCell(hDP, bToFile);

	if(!g_iServerID)
	{
		FormatEx(SZF(sQuery), "SELECT `key_name`, `type`, `expires`, `uses`, `param1`, `param2`, `param3`, `param4`, `param5` FROM `table_keys` ORDER BY `type`, `param1`, `param2`, `param3`, `param4`, `param5`, `expires`, `uses`;");
	}
	else
	{
		FormatEx(SZF(sQuery), "SELECT `key_name`, `type`, `expires`, `uses`, `param1`, `param2`, `param3`, `param4`, `param5` FROM `table_keys` WHERE `sid` = %d ORDER BY `type`, `param1`, `param2`, `param3`, `param4`, `param5`, `expires`, `uses`;", g_iServerID);
	}
	
	if(!bToFile)
	{
		sQuery[strlen(sQuery)-1] = 0;
		Format(SZF(sQuery), "%s LIMIT %d, %d;", sQuery, iOffset, iClient ? 20:100);
	}

	SQL_TQuery(g_hDatabase, SQL_Callback_SelectKeysList, sQuery, hDP);

	return Plugin_Handled;
}

public SQL_Callback_SelectKeysList(Handle:hOwner, Handle:hResult, const String:sError[], any:hDP)
{
	if (hResult == INVALID_HANDLE || sError[0])
	{
		CloseHandle(hDP);
		LogError("SQL_Callback_SelectKeysList: %s", sError);
		return;
	}

	ResetPack(hDP);
	decl iClient, ReplySource:CmdReplySource, bool:bToFile;
	iClient = GET_CID(ReadPackCell(hDP));
	CmdReplySource = ReplySource:ReadPackCell(hDP);
	bToFile = bool:ReadPackCell(hDP);
	CloseHandle(hDP);

	if(!bToFile && iClient == -1)
	{
		return;
	}

	if(SQL_GetRowCount(hResult) > 0)
	{
		decl String:sKey[64], String:sKeyType[64], String:sExpires[64], iUses, iCount, iTime, iExpires, i;
		decl Handle:hFile, Handle:hDataPack, Handle:hPlugin, Function:fPrintCallback, Handle:hParamsArr, String:sParam[KEYS_MAX_LENGTH], String:sParams[512];
		
		if(bToFile)
		{
			BuildPath(Path_SM, SZF(sParams), "data/keys_dump.txt");
			hFile = OpenFile(sParams, "w+");
		}

		iCount = 0;
		iTime = GetTime();

		while(SQL_FetchRow(hResult))
		{
			SQL_FetchString(hResult, 1, SZF(sKeyType));

			if(GetTrieValue(g_hKeysTrie, sKeyType, hDataPack))
			{
				SQL_FetchString(hResult, 0, SZF(sKey));

				iExpires = SQL_FetchInt(hResult, 2);

				if(iExpires)
				{
					if(iExpires < iTime)
					{
						DeleteKey(sKey);
						continue;
					}

					Keys_GetTimeFromStamp(SZF(sExpires), iExpires-iTime, iClient);
				}
				else
				{
					FormatEx(SZF(sExpires), "%T", "FOREVER", iClient);
				}
				
				iUses = SQL_FetchInt(hResult, 3);

				if(!iUses)
				{
					DeleteKey(sKey);
					continue;
				}

				hParamsArr = CreateArray(ByteCountToCells(KEYS_MAX_LENGTH));

				for(i = 4; i < 9; ++i)
				{
					if(SQL_IsFieldNull(hResult, i))
					{
						break;
					}
					
					SQL_FetchString(hResult, i, SZF(sParam));
					PushArrayString(hParamsArr, sParam);
				}

				sParams[0] = 0;

				SetPackPosition(hDataPack, DP_Plugin);
				hPlugin = Handle:ReadPackCell(hDataPack);
				SetPackPosition(hDataPack, DP_OnPrintCallback);
				fPrintCallback = Function:ReadPackCell(hDataPack);
				Call_StartFunction(hPlugin, fPrintCallback);
				Call_PushCell(iClient);
				Call_PushString(sKeyType);
				Call_PushCell(hParamsArr);
				Call_PushStringEx(sParams, 256, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
				Call_PushCell(256);
				Call_Finish();

				CloseHandle(hParamsArr);
				
				if(bToFile)
				{
					WriteFileLine(hFile, "%d. %s\t\t%T: %12s\t\t%T: %4i\t\t%T: %s\t\t%s", ++iCount, sKey, "EXPIRES", iClient, sExpires, "USAGE_LEFT", iClient, iUses, "TYPE", iClient, sKeyType, sParams);
					continue;
				}

				UTIL_ReplyToCommand(iClient, CmdReplySource, "%d. %s\t\t%T: %12s\t\t%T: %4i\t\t%T: %s\t\t%s", ++iCount, sKey, "EXPIRES", iClient, sExpires, "USAGE_LEFT", iClient, iUses, "TYPE", iClient, sKeyType, sParams);
			}
		}
		
		if(bToFile)
		{
			CloseHandle(hFile);
		}
	}
	else
	{
		UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_LIST_NO_KEYS");
	}
}
