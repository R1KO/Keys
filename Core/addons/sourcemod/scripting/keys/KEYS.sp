
void Keys_DeleteExpired()
{
	char szQuery[PMP], szSID[64];

	if(!g_CVAR_iServerID)
	{
		szSID[0] = 0;
	}
	else
	{
		FormatEx(SZF(szSID), " AND `k_sid` = %d", g_CVAR_iServerID);
	}

	FormatEx(SZF(szQuery), "DELETE FROM `keys_tokens` WHERE `k_expires` > 0 AND `k_expires` < %d%s;", GetTime(), szSID);

	g_hDatabase.Query(SQL_Callback_ErrorCheck, szQuery);
}

bool Keys_Check(const char[] szKey, char[] szError, int iErrLen)
{
	if(!szKey[0])
	{
		strcopy(szError, iErrLen, "ERROR_KEY_EMPTY");
		return false;
	}

	int iLength = strlen(szKey);
	if(iLength < 8)
	{
		strcopy(szError, iErrLen, "ERROR_KEY_SHORT");
		return false;
	}

	if(iLength > 64)
	{
		strcopy(szError, iErrLen, "ERROR_KEY_LONG");
		return false;
	}

	int i = 0;

	while (i < iLength)
	{
		if((szKey[i] > 0x2F && szKey[i] < 0x3A) ||
				(szKey[i] > 0x40 && szKey[i] < 0x5B) ||
				(szKey[i] > 0x60 && szKey[i] < 0x7B) ||
				szKey[i] == 0x2D)
		{
			++i;
			continue;
		}

		strcopy(szError, iErrLen, "ERROR_KEY_INVALID_CHARACTERS");
		return false;
	}

	return true;
}

void Keys_Generate(char[] szKey, int iMaxLen)
{
	szKey[0] = '\0';
	
	int i = 0;

	if(g_CVAR_sKeyTemplate[0])
	{
		int iLength = strlen(g_CVAR_sKeyTemplate);
		while (i < iLength && i < iMaxLen)
		{
			szKey[i] = view_as<char>(UTIL_GetCharTemplate(g_CVAR_sKeyTemplate[i]));
			++i;
		}
	}
	else
	{
		while (i < g_CVAR_iKeyLength && i < iMaxLen)
		{
			szKey[i] = view_as<char>(UTIL_GetCharTemplate(0x58));
			++i;
		}
	}

	szKey[i] = '\0';
}

bool Keys_Validate(char[] szKey, const char[] szKeyType, int iUses, int iLifeTime, ArrayList hParamsArr, char[] szError, int iErrLen, int iClient = LANG_SERVER)
{
	DataPack hDataPack;

	if(!g_hKeysTrie.GetValue(szKeyType, hDataPack))
	{
		FormatEx(szError, iErrLen, "%T%T", "ERROR", iClient, "ERROR_INCORRECT_TYPE", iClient);
		return false;
	}

	if(szKey[0])
	{
		if(!Keys_Check(szKey, szError, iErrLen))
		{
			return false;
		}
	}

	if(iLifeTime < 0)
	{
		FormatEx(szError, iErrLen, "%T%T", "ERROR", iClient, "ERROR_INCORRECT_LIFETIME", iClient);
		return false;
	}

	if(iUses < 1)
	{
		FormatEx(szError, iErrLen, "%T%T", "ERROR", iClient, "ERROR_INCORRECT_USES", iClient);
		return false;
	}

	hDataPack.Reset();
	Handle hPlugin = view_as<Handle>(hDataPack.ReadCell());
	Function fCallback = hDataPack.ReadFunction();

	strcopy(szError, iErrLen, "unknown");
	bool bResult = false;
	Call_StartFunction(hPlugin, fCallback);
	Call_PushCell(Validation);
	Call_PushCell(iClient);
	Call_PushString(szKeyType);
	Call_PushCell(hParamsArr);
	Call_PushStringEx(szError, iErrLen, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(iErrLen);
	Call_Finish(bResult);

	if(!bResult)
	{
		FormatEx(szError, iErrLen, "%T%s", "ERROR", iClient, szError);
		return false;
	}

	return true;
}

/*
**************************************************************************************************************************************************
**************************************************************************************************************************************************
**************************************************************************************************************************************************
**************************************************************************************************************************************************
*********************************************************									******************************************************
*********************************************************									******************************************************
*********************************************************			С О З Д А Н И Е			******************************************************
*********************************************************									******************************************************
*********************************************************									******************************************************
**************************************************************************************************************************************************
**************************************************************************************************************************************************
**************************************************************************************************************************************************
**************************************************************************************************************************************************
*/

void Keys_Add(char[] szKeySource = NULL_STRING,
		const char[] szKeyType,
		int iUses,
		int iLifeTime,
		int iExpires = -1,
		ArrayList hParamsArr,
		int iClient,
		ReplySource CmdReplySource,
		Handle hPlugin = null,
		Function fCallback = INVALID_FUNCTION,
		any iData = 0)
{
	LogMessage("Keys_Add: '%s', '%s'", szKeySource, szKeyType);

	DataPack hDP = new DataPack();
	hDP.WriteCell(hParamsArr);
	char szKey[KEYS_MAX_LENGTH];
	if(szKey[0])
	{
		strcopy(SZF(szKey), szKeySource);
		hDP.WriteString(szKey);
		hDP.WriteCell(true);
	}
	else
	{
		Keys_Generate(szKey, KEYS_MAX_LENGTH);
		LogMessage("Keys_Generate: '%s'", szKey);

		hDP.WriteString(szKey);
		hDP.WriteCell(false);
	}

	hDP.WriteCell(GET_UID(iClient));
	hDP.WriteCell(CmdReplySource);
	hDP.WriteString(szKeyType);
	hDP.WriteCell(iUses);
	hDP.WriteCell(iLifeTime);
	if(iExpires == -1)
	{
		iExpires = iLifeTime ? (iLifeTime + GetTime()):iLifeTime;
	}
	hDP.WriteCell(iExpires);

	if(hPlugin != null && fCallback != INVALID_FUNCTION)
	{
		hDP.WriteCell(true);
		hDP.WriteCell(hPlugin);
		hDP.WriteFunction(fCallback);
		hDP.WriteCell(iData);
	}
	else
	{
		hDP.WriteCell(false);
	}

	char szQuery[PMP], szSID[64];

	if(!g_CVAR_iServerID)
	{
		szSID[0] = 0;
	}
	else
	{
		FormatEx(SZF(szSID), " AND `k_sid` = %d", g_CVAR_iServerID);
	}

	FormatEx(SZF(szQuery), "SELECT `k_expires`, `k_uses` FROM `keys_tokens` WHERE `k_name` = '%s'%s;", szKey, szSID);
	g_hDatabase.Query(SQL_Callback_SearchKey, szQuery, hDP);
}

public void SQL_Callback_SearchKey(Database hDB, DBResultSet hResult, const char[] szDbError, any hCbDP)
{
	DataPack hDP = view_as<DataPack>(hCbDP);
	hDP.Reset();
	ArrayList hParamsArr = view_as<ArrayList>(hDP.ReadCell());

	if (hResult == null || szDbError[0])
	{
		LogError("SQL_Callback_SearchKey: %s", szDbError);
		delete hParamsArr;
		delete hDP;
		return;
	}

	char szQuery[1024], szKey[KEYS_MAX_LENGTH];
	int i;
	hDP.ReadString(SZF(szKey));
	
	if(hResult.FetchRow()) // Ключ уже есть в базе
	{
		i = hResult.FetchInt(0);
		if(!i || i > GetTime())
		{
			i = hResult.FetchInt(1);
			if(i)
			{
				if(hDP.ReadCell()) // Отправить ошибку о сущевствующем ключе
				{
					i = GET_CID(hDP.ReadCell());
					if(i != -1)
					{
						UTIL_ReplyToCommand(i, view_as<ReplySource>(hDP.ReadCell()), "%t%t", "ERROR", "ERROR_KEY_ALREADY_EXISTS", szKey);
					}
					else
					{
						hDP.ReadCell(); // CmdReplySource
					}
					
					hDP.ReadString(szQuery, KEYS_MAX_LENGTH); // KeyType
				//	hDP.Position = hDP.Position + view_as<DataPackPos>(27);
					hDP.ReadCell();
					hDP.ReadCell();
					hDP.ReadCell();

					if(hDP.ReadCell()) // hDP.ReadCell()
					{
						FormatEx(szQuery, 256, "%T%T", "ERROR", LANG_SERVER, "ERROR_KEY_ALREADY_EXISTS", LANG_SERVER, szKey);
						Handle hPlugin = view_as<Handle>(hDP.ReadCell());
						Function fCallback = hDP.ReadFunction();
						any iData = hDP.ReadCell();
						API_Callback(Add, hPlugin, fCallback, i, szKey, false, szQuery, iData);
					}

					delete hParamsArr;
					delete hDP;
					return;
				}
				else // Сгенерировать новый ключ
				{
					i = hDP.ReadCell();
					ReplySource CmdReplySource = view_as<ReplySource>(hDP.ReadCell());
					//char szKeyType[KEYS_MAX_LENGTH];
					hDP.ReadString(szQuery, KEYS_MAX_LENGTH); // KeyType
					
					int iUses = hDP.ReadCell();
					int iLifeTime = hDP.ReadCell();
					int iExpires = hDP.ReadCell();

					if(hDP.ReadCell()) // hDP.ReadCell()
					{
						Handle hPlugin = view_as<Handle>(hDP.ReadCell());
						Function fCallback = hDP.ReadFunction();
						any iData = hDP.ReadCell();
						Keys_Add("", szQuery, iUses, iLifeTime, iExpires, hParamsArr, i, CmdReplySource, hPlugin, fCallback, iData);
					}
					else
					{
						Keys_Add(szKey, szQuery, iUses, iLifeTime, iExpires, hParamsArr, i, CmdReplySource);
					}

					delete hDP;
				}

				return;
			}
		}

		Keys_Delete(szKey);
	}

	hDP.ReadCell(); // bDuplicateErr
	hDP.ReadCell(); // Client
	hDP.ReadCell(); // CmdReplySource

	char szKeyType[KEYS_MAX_LENGTH];

	hDP.ReadString(SZF(szKeyType));

	int iUses = hDP.ReadCell();
	hDP.ReadCell(); // iLifeTime
	int iExpires = hDP.ReadCell();

	if(!g_CVAR_iServerID)
	{
		FormatEx(SZF(szQuery), "INSERT INTO `keys_tokens` (`k_name`, `k_type`, `k_expires`, `k_uses`) VALUES ('%s', '%s', %d, %d);", szKey, szKeyType, iExpires, iUses);
	}
	else
	{
		FormatEx(SZF(szQuery), "INSERT INTO `keys_tokens` (`k_name`, `k_type`, `k_expires`, `k_uses`, `k_sid`) VALUES ('%s', '%s', %d, %d, %d);", szKey, szKeyType, iExpires, iUses, g_CVAR_iServerID);
	}
	LogMessage(szQuery);
	g_hDatabase.Query(SQL_Callback_AddKey, szQuery, hDP);
}

public void SQL_Callback_AddKey(Database hDB, DBResultSet hResult, const char[] szDbError, any hCbDP)
{
	DataPack hDP = view_as<DataPack>(hCbDP);
	hDP.Reset();
	ArrayList hParamsArr = view_as<ArrayList>(hDP.ReadCell());

	if (hResult == null || szDbError[0])
	{
		LogError("SQL_Callback_AddKey: %s", szDbError);
		delete hParamsArr;
		delete hDP;
		return;
	}

	int iKeyID = hResult.InsertId;

	char szQuery[PMP*2], sParams[KEYS_MAX_LENGTH];
	Transaction hTxn = new Transaction();
	for(int i = 0; i < hParamsArr.Length; ++i)
	{
		hParamsArr.GetString(i, SZF(sParams));
		FormatEx(SZF(szQuery), "INSERT INTO `keys_params` (`p_kid`, `p_num`, `p_value`) VALUES (%d, %d, '%s');", iKeyID, i+1, sParams);
		hTxn.AddQuery(szQuery);
	}

	SQL_FastQuery(g_hDatabase, "SET CHARSET 'utf8'");

	g_hDatabase.Execute(hTxn, SQL_Callback_AddParamsSuccess, SQL_Callback_AddParamsFailure, hDP);
}

public void SQL_Callback_AddParamsFailure(Database hDB, any hDataPack, int iNumQueries, const char[] szError, int iFailIndex, any[] queryData)
{
	DataPack hDP = view_as<DataPack>(hDataPack);
	hDP.Reset();
	ArrayList hParamsArr = view_as<ArrayList>(hDP.ReadCell());

	delete hParamsArr;
	delete hDP;

	LogError("Не удалось добавить параметры (%d): %s", iFailIndex, szError);
}
	
public void SQL_Callback_AddParamsSuccess(Database hDB, any hData, int iNumQueries, DBResultSet[] hResults, any[] queryData)
{
	DataPack hDP = view_as<DataPack>(hData);
	hDP.Reset();
	ArrayList hParamsArr = view_as<ArrayList>(hDP.ReadCell());

	char szKey[KEYS_MAX_LENGTH], szKeyType[KEYS_MAX_LENGTH], sParams[PMP*2], szName[MAX_NAME_LENGTH], szAuth[32], sExpires[64];
	int iUses, iLifeTime, iClient, iLangClient;
	hDP.ReadString(SZF(szKey));
	hDP.ReadCell();
	iClient = GET_CID(hDP.ReadCell());
	ReplySource CmdReplySource = view_as<ReplySource>(hDP.ReadCell());
	hDP.ReadString(SZF(szKeyType));

	iUses = hDP.ReadCell();
	iLifeTime = hDP.ReadCell();
	hDP.ReadCell();

	Handle hPlugin;
	Function fCallback;

	if(hDP.ReadCell())
	{
		hPlugin = view_as<Handle>(hDP.ReadCell());
		fCallback = hDP.ReadFunction();
		any iData = hDP.ReadCell();
		API_Callback(Add, hPlugin, fCallback, iClient, szKey, true, NULL_STRING, iData);
	}

	if(iClient > 0)
	{
		GetClientName(iClient, SZF(szName));
		GetClientAuthId(iClient, AuthId_Engine, SZF(szAuth));
		iLangClient = iClient;
	}
	else
	{
		iLangClient = LANG_SERVER;

		strcopy(SZF(szName), "CONSOLE");
		strcopy(SZF(szAuth), "STEAM_ID_SERVER");
	}
	
	if(iLifeTime)
	{
		Keys_GetTimeFromStamp(SZF(sExpires), iLifeTime, iLangClient);
	}
	else
	{
		FormatEx(SZF(sExpires), "%T", "FOREVER", iLangClient);
	}
	
	sParams[0] = 0;

	DataPack hDataPack;
	g_hKeysTrie.GetValue(szKeyType, hDataPack);
	hDataPack.Reset();
	hPlugin = view_as<Handle>(hDataPack.ReadCell());
	fCallback = hDataPack.ReadFunction();
	Call_StartFunction(hPlugin, fCallback);
	Call_PushCell(Print);
	Call_PushCell(LANG_SERVER);
	Call_PushString(szKeyType);
	Call_PushCell(hParamsArr);
	Call_PushStringEx(SZF(sParams), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(sizeof(sParams));
	Call_Finish();

	if(hResults[0].AffectedRows)
	{
		if(iClient != -1)
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t", "SUCCESS_CREATE_KEY", szKey);
		}
		
		LogToFile(g_sLogFile, "%T", "LOG_SUCCESS_CREATE_KEY", LANG_SERVER, szName, szAuth, szKey, sExpires, iUses, szKeyType, sParams);
	}
	else
	{
		if(iClient != -1)
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_CREATE_KEY", szKey);
		}

		LogToFile(g_sLogFile, "%T", "LOG_ERROR_CREATE_KEY", LANG_SERVER, szKey, szName, szAuth, sExpires, iUses, szKeyType, sParams);
	}

	delete hParamsArr;
	delete hDP;
}

/*
**************************************************************************************************************************************************
**************************************************************************************************************************************************
**************************************************************************************************************************************************
**************************************************************************************************************************************************
*********************************************************									******************************************************
*********************************************************									******************************************************
*********************************************************			У Д А Л Е Н И Е			******************************************************
*********************************************************									******************************************************
*********************************************************									******************************************************
**************************************************************************************************************************************************
**************************************************************************************************************************************************
**************************************************************************************************************************************************
**************************************************************************************************************************************************
*/

void Keys_Delete(const char[] szKey,
		bool bSearch = false,
		int iClient = -1,
		ReplySource CmdReplySource = SM_REPLY_TO_CONSOLE,
		Handle hPlugin = null,
		Function fCallback = INVALID_FUNCTION,
		any iData = 0)
{
	DataPack hDP = new DataPack();
	hDP.WriteString(szKey);
	hDP.WriteCell((iClient != -1));
	hDP.WriteCell(GET_UID(iClient));
	hDP.WriteCell(CmdReplySource);

	if(hPlugin != null && fCallback != INVALID_FUNCTION)
	{
		hDP.WriteCell(true);
		hDP.WriteCell(hPlugin);
		hDP.WriteFunction(fCallback);
		hDP.WriteCell(iData);
	}
	else
	{
		hDP.WriteCell(false);
	}

	char szQuery[PMP*2], szSID[64];

	if(!g_CVAR_iServerID)
	{
		szSID[0] = 0;
	}
	else
	{
		FormatEx(SZF(szSID), " AND `k_sid` = %d", g_CVAR_iServerID);
	}

	if(bSearch)
	{
		FormatEx(SZF(szQuery), "SELECT `k_id` FROM `keys_tokens` WHERE `k_name` = '%s'%s;", szKey, szSID);
		g_hDatabase.Query(SQL_Callback_SearchDelKey, szQuery, hDP);
	}
	else
	{
		// DELETE FROM `keys_params` WHERE `p_kid` = IFNULL((SELECT `k_id` FROM `keys_tokens` WHERE `k_name` = '%s'), 0);
		// DELETE FROM `keys_tokens` WHERE `k_name` = '%s';
		// DELETE FROM `keys_params` WHERE `p_kid` = IFNULL((SELECT `k_id` FROM `keys_tokens` WHERE `k_name` = '%s' AND `k_sid` = %d), 0);
		// DELETE FROM `keys_tokens` WHERE `k_name` = '%s' AND `k_sid` = %d;

		FormatEx(SZF(szQuery), "DELETE FROM `keys_params` WHERE `p_kid` = IFNULL((SELECT `k_id` FROM `keys_tokens` WHERE `k_name` = '%s'%s), 0); \
								DELETE FROM `keys_tokens` WHERE `k_name` = '%s'%s;", szKey, szSID, szKey, szSID);

		g_hDatabase.Query(SQL_Callback_RemoveKey, szQuery, hDP);
	}
}

public void SQL_Callback_SearchDelKey(Database hDB, DBResultSet hResult, const char[] szDbError, any hCbDP)
{
	DataPack hDP = view_as<DataPack>(hCbDP);

	if (hResult == null || szDbError[0])
	{
		delete hDP;
		LogError("SQL_Callback_SearchDelKey: %s", szDbError);
		return;
	}

	if(hResult.FetchRow())
	{
		int iKeyID = hResult.FetchInt(0);

		char szQuery[PMP*2];

		FormatEx(SZF(szQuery), "DELETE FROM `keys_params` WHERE `p_kid` = %d; \
								DELETE FROM `keys_tokens` WHERE `k_id` = %d;", iKeyID, iKeyID);

		g_hDatabase.Query(SQL_Callback_RemoveKey, szQuery, hDP);
		return;
	}
	
	Keys_NotifyDelResult(hDP, false);
}

public void SQL_Callback_RemoveKey(Database hDB, DBResultSet hResult, const char[] szDbError, any hCbDP)
{
	DataPack hDP = view_as<DataPack>(hCbDP);

	if (hResult == null || szDbError[0])
	{
		delete hDP;
		LogError("SQL_Callback_RemoveKey: %s", szDbError);
		return;
	}
	
	Keys_NotifyDelResult(hDP, hResult.AffectedRows != 0);
}

void Keys_NotifyDelResult(DataPack hDP, bool bResult)
{
	hDP.Reset();

	char szKey[KEYS_MAX_LENGTH];
	hDP.ReadString(SZF(szKey));
	
	bool bReply = hDP.ReadCell();

	int iClient = GET_CID(hDP.ReadCell());

	if(iClient == -1)
	{
		iClient = 0;
	}

	ReplySource CmdReplySource = view_as<ReplySource>(hDP.ReadCell());

	char szName[MAX_NAME_LENGTH], szAuth[32];
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

	if(bReply)
	{
		if(bResult)
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t", "SUCCESS_REMOVE_KEY", szKey);

			LogToFile(g_sLogFile, "%T", "LOG_SUCCESS_REMOVE_KEY", LANG_SERVER, szKey, szName, szAuth);
		}
		else
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%t", "ERROR", "ERROR_REMOVE_KEY", szKey);

			LogToFile(g_sLogFile, "%T", "LOG_ERROR_REMOVE_KEY", LANG_SERVER, szKey, szName, szAuth);
		}
	}

	if(hDP.ReadCell())
	{
		Handle hPlugin = view_as<Handle>(hDP.ReadCell());
		Function fCallback = hDP.ReadFunction();
		any iData = hDP.ReadCell();
		if(bResult)
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t", "SUCCESS_REMOVE_KEY", szKey);

			LogToFile(g_sLogFile, "%T", "LOG_SUCCESS_REMOVE_KEY", LANG_SERVER, szKey, szName, szAuth);
			API_Callback(Rem, hPlugin, fCallback, iClient, szKey, true, NULL_STRING, iData);
		}
		else
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t", "SUCCESS_REMOVE_KEY", szKey);

			LogToFile(g_sLogFile, "%T", "LOG_ERROR_REMOVE_KEY", LANG_SERVER, szKey, szName, szAuth);
			API_Callback(Rem, hPlugin, fCallback, iClient, szKey, false, "Keys don't search", iData);
		}	
	}

	delete hDP;
}

/*
**************************************************************************************************************************************************
**************************************************************************************************************************************************
**************************************************************************************************************************************************
**************************************************************************************************************************************************
*********************************************************									******************************************************
*********************************************************									******************************************************
*********************************************************	  И С П О Л Ь З О В А Н И Е		******************************************************
*********************************************************									******************************************************
*********************************************************									******************************************************
**************************************************************************************************************************************************
**************************************************************************************************************************************************
**************************************************************************************************************************************************
**************************************************************************************************************************************************
*/

void Keys_Use(const char[] szKey,
		int iClient,
		ReplySource CmdReplySource = SM_REPLY_TO_CHAT,
		bool bNotify,
		bool bIgnoreBlock,
		Handle hPlugin = null,
		Function fCallback = INVALID_FUNCTION,
		any iData = 0)
{
	DataPack hDP = new DataPack();
	hDP.WriteString(szKey);
	hDP.WriteCell(UID(iClient));
	hDP.WriteCell(CmdReplySource);
	hDP.WriteCell(bNotify);

	if(hPlugin != null && fCallback != INVALID_FUNCTION)
	{
		hDP.WriteCell(true);
		hDP.WriteCell(hPlugin);
		hDP.WriteFunction(fCallback);
		hDP.WriteCell(iData);
	}
	else
	{
		hDP.WriteCell(false);
	}

	char szQuery[PMP*2], szAuth[32];
	GetClientAuthId(iClient, AuthId_Engine, SZF(szAuth));

	char szSID[64];

	if(!g_CVAR_iServerID)
	{
		szSID[0] = 0;
	}
	else
	{
		FormatEx(SZF(szSID), " AND `k_sid` = %d", g_CVAR_iServerID);
	}
	
	FormatEx(SZF(szQuery), "SELECT `k_id`, `k_type`, `k_expires`, `k_uses` FROM `keys_tokens` WHERE `k_name` = '%s'%s LIMIT 1;", szKey, szSID);

	g_hDatabase.Query(SQL_Callback_SelectUseKey, szQuery, hDP);
}

public void SQL_Callback_SelectUseKey(Database hDB, DBResultSet hResult, const char[] szDbError, any hCbDP)
{
	DataPack hDP = view_as<DataPack>(hCbDP);

	if (hResult == null || szDbError[0])
	{
		delete hDP;
		LogError("SQL_Callback_SelectUseKey: %s", szDbError);
		return;
	}
	
	hDP.Reset();

	char szKey[KEYS_MAX_LENGTH], szError[PMP];
	hDP.ReadString(SZF(szKey));
	int iClient = CID(hDP.ReadCell());
	ReplySource CmdReplySource = view_as<ReplySource>(hDP.ReadCell());
	bool bNotify = view_as<bool>(hDP.ReadCell());

	Handle hPlugin = null;
	Function fCallback = INVALID_FUNCTION;
	any iData = 0;
	if(hDP.ReadCell())
	{
		hPlugin = view_as<Handle>(hDP.ReadCell());
		fCallback = hDP.ReadFunction();
		iData = hDP.ReadCell();
	}
	
	delete hDP;

	if (iClient)
	{
		if(hResult.FetchRow())
		{
			char szKeyType[KEYS_MAX_LENGTH];
			hResult.FetchString(1, SZF(szKeyType));
			DataPack hDataPack;
			if(g_hKeysTrie.GetValue(szKeyType, hDataPack))
			{
				int iExpires = hResult.FetchInt(2);
				if(iExpires)
				{
					if(iExpires < GetTime())
					{
						Keys_Delete(szKey);
						FormatEx(SZF(szError), "%T%T", "ERROR", iClient, "ERROR_KEY_NOT_EXIST", iClient);
						if(bNotify)
						{
							UTIL_ReplyToCommand(iClient, CmdReplySource, szError);
						}
						if(fCallback)
						{
							API_Callback(Use, hPlugin, fCallback, iClient, szKey, false, szError, iData);
						}
						return;
					}
				}

				int iUses = hResult.FetchInt(3);
				if(!iUses)
				{
					Keys_Delete(szKey);
					FormatEx(SZF(szError), "%T%T", "%t%t", "ERROR", iClient, "ERROR_KEY_NOT_EXIST", iClient);
					if(bNotify)
					{
						UTIL_ReplyToCommand(iClient, CmdReplySource, szError);
					}
					if(fCallback)
					{
						API_Callback(Use, hPlugin, fCallback, iClient, szKey, false, szError, iData);
					}
					return;
				}
	
				int iKeyID = hResult.FetchInt(0);
				
				DataPack hDP2 = new DataPack();
				hDP2.WriteString(szKey);
				hDP2.WriteString(szKeyType);
				hDP2.WriteCell(iKeyID);
				hDP2.WriteCell(iUses);
				hDP2.WriteCell(UID(iClient));
				hDP2.WriteCell(CmdReplySource);
				hDP2.WriteCell(bNotify);

				if(hPlugin != null && fCallback != INVALID_FUNCTION)
				{
					hDP2.WriteCell(true);
					hDP2.WriteCell(hPlugin);
					hDP2.WriteFunction(fCallback);
					hDP2.WriteCell(iData);
				}
				else
				{
					hDP2.WriteCell(false);
				}
				char szQuery[PMP], szAuth[32];
				GetClientAuthId(iClient, AuthId_Engine, SZF(szAuth));
				FormatEx(SZF(szQuery), "SELECT `u_auth` FROM `keys_players_used` WHERE `u_kid` = '%d' AND `u_auth` = '%s';", iKeyID, szAuth);
				g_hDatabase.Query(SQL_Callback_CheckUseKey, szQuery, hDP2);

				return;
			}

			FormatEx(SZF(szError), "%T%T", "ERROR", iClient, "ERROR_INCORRECT_TYPE", iClient);
			if(fCallback)
			{
				API_Callback(Use, hPlugin, fCallback, iClient, szKey, false, szError, iData);
			}
			return;
		}

		FormatEx(SZF(szError), "%T%T", "ERROR", iClient, "ERROR_KEY_NOT_EXIST", iClient);
		if(fCallback)
		{
			API_Callback(Use, hPlugin, fCallback, iClient, szKey, false, szError, iData);
		}
	}
}

public void SQL_Callback_CheckUseKey(Database hDB, DBResultSet hResult, const char[] szDbError, any hCbDP)
{
	DataPack hDP = view_as<DataPack>(hCbDP);

	if (hResult == null || szDbError[0])
	{
		delete hDP;
		LogError("SQL_Callback_CheckUseKey: %s", szDbError);
		return;
	}

	hDP.Reset();

	char szKey[KEYS_MAX_LENGTH], szKeyType[KEYS_MAX_LENGTH];
	hDP.ReadString(SZF(szKey));
	hDP.ReadString(SZF(szKeyType));
	int iKeyID = hDP.ReadCell();
	hDP.ReadCell();
	int iClient = CID(hDP.ReadCell());
	hDP.ReadCell();
	hDP.ReadCell();

	Handle hPlugin = null;
	Function fCallback = INVALID_FUNCTION;
	any iData = 0;
	if(hDP.ReadCell())
	{
		hPlugin = view_as<Handle>(hDP.ReadCell());
		fCallback = hDP.ReadFunction();
		iData = hDP.ReadCell();
	}

	if(hResult.FetchRow())
	{
		char szError[PMP];
		FormatEx(SZF(szError), "%T%T", "%t%t", "ERROR", iClient, "ERROR_KEY_ALREADY_USED", iClient);
		API_Callback(Use, hPlugin, fCallback, iClient, szKey, false, szError, iData);
		delete hDP;
		return;
	}
	
	char szQuery[PMP];
	FormatEx(SZF(szQuery), "SELECT `p_num`, `p_value` FROM `keys_params` WHERE `p_kid` = '%d' ORDER BY `p_num`;", iKeyID);
	g_hDatabase.Query(SQL_Callback_UseKey, szQuery, hDP);
}	

public void SQL_Callback_UseKey(Database hDB, DBResultSet hResult, const char[] szDbError, any hCbDP)
{
	DataPack hDP = view_as<DataPack>(hCbDP);

	if (hResult == null || szDbError[0])
	{
		delete hDP;
		LogError("SQL_Callback_SelectUseKey: %s", szDbError);
		return;
	}

	hDP.Reset();

	char szKey[KEYS_MAX_LENGTH], szKeyType[KEYS_MAX_LENGTH], szError[PMP];
	hDP.ReadString(SZF(szKey));
	hDP.ReadString(SZF(szKeyType));
	int iKeyID = hDP.ReadCell();
	int iUses = hDP.ReadCell();
	int iClient = CID(hDP.ReadCell());
	ReplySource CmdReplySource = view_as<ReplySource>(hDP.ReadCell());
	bool bNotify = view_as<bool>(hDP.ReadCell());

	Handle hPlugin = null;
	Function fCallback = INVALID_FUNCTION;
	any iData = 0;
	if(hDP.ReadCell())
	{
		hPlugin = view_as<Handle>(hDP.ReadCell());
		fCallback = hDP.ReadFunction();
		iData = hDP.ReadCell();

		if(!hResult.RowCount)
		{
			API_Callback(Use, hPlugin, fCallback, iClient, szKey, false, "Fail select key params", iData);
			delete hDP;
			return;
		}
	}

	if (iClient)
	{
		if(!hResult.RowCount)
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "Fail select key params");
		}
		
		ArrayList hParamsArr = new ArrayList(ByteCountToCells(KEYS_MAX_LENGTH));
		
		char szParam[KEYS_MAX_LENGTH];

		while(hResult.FetchRow())
		{
			hResult.FetchString(1, SZF(szParam));
			hParamsArr.PushString(szParam);
		}

		DataPack hDataPack;
		g_hKeysTrie.GetValue(szKeyType, hDataPack);
		hDataPack.Reset();
		hPlugin = view_as<Handle>(hDataPack.ReadCell());
		fCallback = hDataPack.ReadFunction();

		strcopy(SZF(szError), "unknown");
		bool bResult = false;
		Call_StartFunction(hPlugin, fCallback);
		Call_PushCell(Activation);
		Call_PushCell(iClient);
		Call_PushString(szKeyType);
		Call_PushCell(hParamsArr);
		Call_PushStringEx(SZF(szError), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
		Call_PushCell(sizeof(szError));
		Call_Finish(bResult);

		delete hParamsArr;

		if(!bResult && bNotify)
		{
			UTIL_ReplyToCommand(iClient, CmdReplySource, "%t%s", "ERROR", szError);
			return;
		}

		char szName[MAX_NAME_LENGTH], szAuth[32], szQuery[PMP], szSID[64];
		GetClientName(iClient, SZF(szName));
		GetClientAuthId(iClient, AuthId_Engine, SZF(szAuth));

		if(!g_CVAR_iServerID)
		{
			szSID[0] = 0;
		}
		else
		{
			FormatEx(SZF(szSID), " AND `k_sid` = %d", g_CVAR_iServerID);
		}
		if(--iUses)
		{
			if(!g_CVAR_iServerID)
			{
				FormatEx(SZF(szQuery), "INSERT INTO `keys_players_used` (`u_auth`, `u_kid`) VALUES ('%s', %d);", szAuth, iKeyID);
			}
			else
			{
				FormatEx(SZF(szQuery), "INSERT INTO `keys_players_used` (`u_auth`, `u_kid`, `u_sid`) VALUES ('%s', %d, %d);", szAuth, iKeyID, g_CVAR_iServerID);
			}
			g_hDatabase.Query(SQL_Callback_ErrorCheck, szQuery);

			FormatEx(SZF(szQuery), "UPDATE `keys_tokens` SET `k_uses` = %d WHERE `u_kid` = %d%s;", iUses, iKeyID, szSID);
			g_hDatabase.Query(SQL_Callback_ErrorCheck, szQuery);
		}
		else
		{
			Keys_Delete(szKey);
			FormatEx(SZF(szQuery), "DELETE FROM `keys_players_used` WHERE `u_kid` = %d%s;", szKey, szSID);
			g_hDatabase.Query(SQL_Callback_ErrorCheck, szQuery);
		}

		UTIL_ReplyToCommand(iClient, CmdReplySource, "%t", "SUCCESS_USE_KEY", szKey);
		LogToFile(g_sLogFile, "%T", "LOG_SUCCESS_USE_KEY", LANG_SERVER, szName, szAuth, szKey);
		return;
	}
}
