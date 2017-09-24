
static Handle g_hGlobalForward_OnCoreStarted;

public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] szError, int iErr_max) 
{
//	Stats_Init();

	g_hGlobalForward_OnCoreStarted = CreateGlobalForward("Keys_OnCoreStarted", ET_Ignore);

	CreateNative("Keys_IsCoreStarted", Native_IsCoreStarted);
	CreateNative("Keys_GetCoreDatabase", Native_GetCoreDatabase);
	CreateNative("Keys_GetDatabaseType", Native_GetDatabaseType);
	CreateNative("Keys_RegKey", Native_RegKey);
	CreateNative("Keys_UnregKey", Native_UnregKey);

	CreateNative("Keys_IsValidKeyType", Native_IsValidKeyType);
	CreateNative("Keys_FillArrayByKeyTypes", Native_FillArrayByKeyTypes);

	CreateNative("Keys_IsValidKey", Native_IsValidKey);
	CreateNative("Keys_GetKeyData", Native_GetKeyData);
	CreateNative("Keys_GenerateKey", Native_GenerateKey);
	CreateNative("Keys_AddKey", Native_AddKey);
	CreateNative("Keys_RemoveKey", Native_RemoveKey);
	CreateNative("Keys_UseKey", Native_UseKey);

	RegPluginLibrary("keys_core");

	return APLRes_Success; 
}

void API_CreateForward_OnCoreStarted()
{
	Call_StartForward(g_hGlobalForward_OnCoreStarted);
	Call_Finish();
}

public int Native_IsCoreStarted(Handle hPlugin, int iNumParams)
{
	return view_as<int>(g_bIsStarted);
}

public int Native_GetCoreDatabase(Handle hPlugin, int iNumParams)
{
	return view_as<int>(CloneHandle(g_hDatabase, hPlugin));
}

public int Native_GetDatabaseType(Handle hPlugin, int iNumParams)
{
	return view_as<int>(g_bDBMySQL);
}

public int Native_RegKey(Handle hPlugin, int iNumParams)
{
	char szKeyType[KEYS_MAX_LENGTH];
	GetNativeString(1, SZF(szKeyType));

	if(g_hKeysArray.FindString(szKeyType) != -1)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Тип ключа \"%s\" уже зарегистрирован!", szKeyType);
		return false;
	}

	DataPack hDataPack = new DataPack();
	hDataPack.WriteCell(hPlugin);
	hDataPack.WriteFunction(GetNativeCell(2));

	g_hKeysTrie.SetValue(szKeyType, hDataPack);
	g_hKeysArray.PushString(szKeyType);

	return true;
}

public int Native_UnregKey(Handle hPlugin, int iNumParams)
{
	char szKeyType[KEYS_MAX_LENGTH];
	GetNativeString(1, SZF(szKeyType));

	int index;
	if((index = g_hKeysArray.FindString(szKeyType)) != -1)
	{
		g_hKeysArray.Erase(index);
		DataPack hDataPack;
		if(g_hKeysTrie.GetValue(szKeyType, hDataPack))
		{
			delete hDataPack;
		}
		g_hKeysTrie.Remove(szKeyType);
	}
}

public int Native_IsValidKeyType(Handle hPlugin, int iNumParams)
{
	char szKeyType[KEYS_MAX_LENGTH];
	GetNativeString(1, SZF(szKeyType));

	return (FindStringInArray(g_hKeysArray, szKeyType) != -1);
}

public int Native_FillArrayByKeyTypes(Handle hPlugin, int iNumParams)
{
	return view_as<int>(g_hKeysArray.Clone());
}

public int Native_IsValidKey(Handle hPlugin, int iNumParams)
{
	char szKey[KEYS_MAX_LENGTH], szQuery[PMP], szSID[64];
	GetNativeString(1, SZF(szKey));
	
	DataPack hDP = new DataPack();
	hDP.WriteCell(hPlugin);
	hDP.WriteFunction(GetNativeCell(2));
	hDP.WriteString(szKey);
	hDP.WriteCell(GetNativeCell(3));

	if(!g_CVAR_iServerID)
	{
		szSID[0] = 0;
	}
	else
	{
		FormatEx(SZF(szSID), " AND `k_sid` = %d", g_CVAR_iServerID);
	}

	FormatEx(SZF(szQuery), "SELECT `k_id` FROM `keys_tokens` WHERE `k_name` = '%s'%s LIMIT 1;", szKey, szSID);

	g_hDatabase.Query(SQL_Callback_Ntv_IsValidKey, szQuery, hDP);
}

public void SQL_Callback_Ntv_IsValidKey(Database hDB, DBResultSet hResult, const char[] szDbError, any hCbDP)
{
	DataPack hDP = view_as<DataPack>(hCbDP);

	if (hResult == null || szDbError[0])
	{
		delete hDP;
		LogError("SQL_Callback_Ntv_IsValidKey: %s", szDbError);
		return;
	}
	
	hDP.Reset();
	Handle hPlugin = view_as<Handle>(hDP.ReadCell());
	Function fCallback = hDP.ReadFunction();
	char szKey[KEYS_MAX_LENGTH];
	hDP.ReadString(SZF(szKey));
	any iData = hDP.ReadCell();
	delete hDP;
	
	bool bKeyExists = false;

	if(hResult.FetchRow())
	{
		int iExpires = hResult.FetchInt(0);
		if(iExpires)
		{
			if(iExpires < GetTime())
			{
				Keys_Delete(szKey);
			}
			else
			{
				bKeyExists = true;
			}
		}
		else
		{
			bKeyExists = true;
		}
	}

	Call_StartFunction(hPlugin, fCallback);
	Call_PushString(szKey);
	Call_PushCell(bKeyExists);
	Call_PushCell(iData);
	Call_Finish();
}

public int Native_GetKeyData(Handle hPlugin, int iNumParams)
{
	char szKey[KEYS_MAX_LENGTH], szQuery[PMP], szSID[64];
	GetNativeString(1, SZF(szKey));
	
	DataPack hDP = new DataPack();
	hDP.WriteCell(hPlugin);
	hDP.WriteFunction(GetNativeCell(2));
	hDP.WriteString(szKey);
	hDP.WriteCell(GetNativeCell(3));

	if(!g_CVAR_iServerID)
	{
		szSID[0] = 0;
	}
	else
	{
		FormatEx(SZF(szSID), " AND `k_sid` = %d", g_CVAR_iServerID);
	}

	FormatEx(SZF(szQuery), "SELECT `k_id`, `k_type`, `k_expires`, `k_uses` FROM `keys_tokens` WHERE `k_name` = '%s'%s LIMIT 1;", szKey, szSID);

	g_hDatabase.Query(SQL_Callback_Ntv_GetKeyData, szQuery, hDP);
}

public void SQL_Callback_Ntv_GetKeyData(Database hDB, DBResultSet hResult, const char[] szDbError, any hCbDP)
{
	DataPack hDP = view_as<DataPack>(hCbDP);

	if (hResult == null || szDbError[0])
	{
		delete hDP;
		LogError("SQL_Callback_Ntv_GetKeyData: %s", szDbError);
		return;
	}

	hDP.Reset();

	char szKey[KEYS_MAX_LENGTH], szKeyType[KEYS_MAX_LENGTH];
	Handle hPlugin = view_as<Handle>(hDP.ReadCell());
	Function fCallback = hDP.ReadFunction();
	hDP.ReadString(SZF(szKey));
	any iData = hDP.ReadCell();

	bool bKeyExists = false;
	int iKeyID, iExpires, iUses;

	if(hResult.FetchRow())
	{
		iExpires = hResult.FetchInt(2);
		if(!iExpires || iExpires > GetTime())
		{
			hResult.FetchString(1, SZF(szKeyType));
			if(g_hKeysArray.FindString(szKeyType) != -1)
			{
				iUses = hResult.FetchInt(3);
				if(iUses)
				{
					bKeyExists = true;
					iKeyID = hResult.FetchInt(0);
				}
				else
				{
					Keys_Delete(szKey);
				}
			}
		}
		else
		{
			Keys_Delete(szKey);
		}
	}
	
	if(!bKeyExists)
	{
		Call_StartFunction(hPlugin, fCallback);
		Call_PushString(szKey);
		Call_PushCell(false);
		Call_PushString(NULL_STRING);
		Call_PushCell(0);
		Call_PushCell(0);
		Call_PushCell(0);
		Call_PushCell(iData);
		Call_Finish();
		delete hDP;
		return;
	}

	hDP.WriteString(szKeyType);
	hDP.WriteCell(iUses);
	hDP.WriteCell(iExpires);

	char szQuery[PMP];

	FormatEx(SZF(szQuery), "SELECT `p_num`, `p_value` FROM `keys_params` WHERE `p_kid` = '%d' ORDER BY `p_num`;", iKeyID);

	g_hDatabase.Query(SQL_Callback_Ntv_GetKeyDataParams, szQuery, hDP);
}

public void SQL_Callback_Ntv_GetKeyDataParams(Database hDB, DBResultSet hResult, const char[] szDbError, any hCbDP)
{
	DataPack hDP = view_as<DataPack>(hCbDP);

	if (hResult == null || szDbError[0])
	{
		delete hDP;
		LogError("SQL_Callback_Ntv_GetKeyDataParams: %s", szDbError);
		return;
	}

	hDP.Reset();

	char szKey[KEYS_MAX_LENGTH], szKeyType[KEYS_MAX_LENGTH], szParam[KEYS_MAX_LENGTH];
	Handle hPlugin = view_as<Handle>(hDP.ReadCell());
	Function fCallback = hDP.ReadFunction();
	hDP.ReadString(SZF(szKey));
	any iData = hDP.ReadCell();
	hDP.ReadString(SZF(szKeyType));
	int iUses = hDP.ReadCell();
	int iExpires = hDP.ReadCell();
	delete hDP;

	ArrayList hParamsArr = new ArrayList(ByteCountToCells(KEYS_MAX_LENGTH));
	while(hResult.FetchRow())
	{
		hResult.FetchString(1, SZF(szParam));
		hParamsArr.PushString(szParam);
	}

	Call_StartFunction(hPlugin, fCallback);
	Call_PushString(szKey);
	Call_PushCell(true);
	Call_PushString(szKeyType);
	Call_PushCell(iUses);
	Call_PushCell(iExpires);
	Call_PushCell(hParamsArr);
	Call_PushCell(iData);
	Call_Finish();
}

public int Native_GenerateKey(Handle hPlugin, int iNumParams)
{
	char szKey[KEYS_MAX_LENGTH], sTemplate[64];
	GetNativeString(3, SZF(sTemplate));

	Keys_Generate(SZF(szKey));
	SetNativeString(1, szKey, GetNativeCell(2), true);
}

// Keys_AddKey(int iClient = 0, const char[] szKey = NULL_STRING, const char[] szKeyType, int iUses, iLifeTime, ArrayList hParamsArr, KeyNativeActionCallback AddKeyCallback, any iData);
public int Native_AddKey(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if(iClient && (iClient < 0 || iClient > MaxClients || !IsClientInGame(iClient) || IsFakeClient(iClient)))
	{
		return 0;
	}

	char szKey[KEYS_MAX_LENGTH], szKeyType[KEYS_MAX_LENGTH], szError[PMP];
	GetNativeString(2, SZF(szKey));
	GetNativeString(3, SZF(szKeyType));
	int iUses = GetNativeCell(4);
	int iLifeTime = GetNativeCell(5);
	ArrayList hParamsArr = view_as<ArrayList>(GetNativeCell(6));
	Function fCallback = GetNativeFunction(7);
	any iData = GetNativeCell(8);

	szError[0] = 0;

	if(!Keys_Validate(szKey, szKeyType, iUses, iLifeTime, hParamsArr, SZF(szError), iClient))
	{
		delete hParamsArr;
		API_Callback(Add, hPlugin, fCallback, iClient, szKey, false, szError, iData);

		return 0;
	}

	Keys_Add(szKey, szKeyType, iUses, iLifeTime, -1, hParamsArr, iClient, iClient ? SM_REPLY_TO_CHAT:SM_REPLY_TO_CONSOLE, hPlugin, fCallback, iData);
	return 0;
}

//Keys_RemoveKey(int iClient = 0, const char[] szKey, KeyNativeActionCallback RemoveKeyCallback, any iData = 0);
public int Native_RemoveKey(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if(iClient && (iClient < 0 || iClient > MaxClients || !IsClientInGame(iClient) || IsFakeClient(iClient)))
	{
		return 0;
	}

	char szKey[KEYS_MAX_LENGTH];
	GetNativeString(2, SZF(szKey));

	Function fCallback = GetNativeFunction(3);
	any iData = GetNativeCell(4);
	
	Keys_Delete(szKey, true, iClient, iClient ? SM_REPLY_TO_CHAT:SM_REPLY_TO_CONSOLE, hPlugin, fCallback, iData);
	return 0;
}

// Keys_UseKey(int iClient, const char[] szKey, bool bNotify, bool bIgnoreBlock, KeyNativeActionCallback UseKeyCallback, any iData = 0);
public int Native_UseKey(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if(iClient < 1 || iClient > MaxClients || !IsClientInGame(iClient) || IsFakeClient(iClient))
	{
		return 0;
	}

	char szKey[KEYS_MAX_LENGTH];
	GetNativeString(2, SZF(szKey));
	bool bNotify = GetNativeCell(3);
	bool bIgnoreBlock = GetNativeCell(4);

	Function fCallback = GetNativeFunction(5);
	any iData = GetNativeCell(6);

	if(!bIgnoreBlock && g_bIsBlocked[iClient])
	{
		char szError[PMP];
		FormatEx(SZF(szError), "%T%T", "ERROR", iClient, "ERROR_BLOCKED", iClient);
		API_Callback(Use, hPlugin, fCallback, iClient, szKey, false, szError, iData);
		return 0;
	}
	
	Keys_Use(szKey, iClient, SM_REPLY_TO_CHAT, bNotify, bIgnoreBlock, hPlugin, fCallback, iData);
	return 0;
}

// function void (int iClient, const char[] szKey, bool bSuccess, const char[] szError, any iData);
void API_Callback(KeysNativeAction eKeysAction, Handle hPlugin, Function fCallback, int iClient, const char[] szKey, bool bSuccess = true, const char[] szError = NULL_STRING, any iData)
{
	Call_StartFunction(hPlugin, fCallback);
	Call_PushCell(eKeysAction);
	Call_PushCell(iClient);
	Call_PushString(szKey);
	Call_PushCell(bSuccess);
	Call_PushString(szError);
	Call_PushCell(iData);
	Call_Finish();
}
