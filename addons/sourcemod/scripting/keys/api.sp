
static Handle:g_hGlobalForward_OnCoreStarted;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) 
{
	MarkNativeAsOptional("GetClientAuthId");
	MarkNativeAsOptional("GetClientAuthString");
	
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
	CreateNative("Keys_AddKey", Keys_AddKey);
	CreateNative("Keys_RemoveKey", Keys_RemoveKey);
	CreateNative("Keys_UseKey", Keys_UseKey);
	

	/*
	- Проверка наличия типа ключа
	- Проверка наличия ключа
	- Генерация ключа
	- Добавление ключа
	- Получение массива с типами ключей
	- Активация ключа
	*/

	RegPluginLibrary("keys_core");

	return APLRes_Success; 
}

CreateForward_OnCoreStarted()
{
	Call_StartForward(g_hGlobalForward_OnCoreStarted);
	Call_Finish();
}

public Native_IsCoreStarted(Handle:hPlugin, iNumParams)
{
	return g_bIsStarted;
}

public Native_GetCoreDatabase(Handle:hPlugin, iNumParams)
{
	return _:CloneHandle(g_hDatabase, hPlugin);
}

public Native_GetDatabaseType(Handle:hPlugin, iNumParams)
{
	return g_bDBMySQL;
}

public Native_RegKey(Handle:hPlugin, iNumParams)
{
	decl String:sKeyType[KEYS_MAX_LENGTH];
	GetNativeString(1, SZF(sKeyType));
	
	if(FindStringInArray(g_hKeysArray, sKeyType) != -1)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Тип ключа \"%s\" уже зарегистрирован!", sKeyType);
		return false;
	}
	
	new Handle:hDataPack = CreateDataPack();
	WritePackCell(hDataPack, hPlugin);
	WritePackCell(hDataPack, GetNativeCell(2));
	WritePackCell(hDataPack, GetNativeCell(3));
	WritePackCell(hDataPack, GetNativeCell(4));

	SetTrieValue(g_hKeysTrie, sKeyType, hDataPack);
	PushArrayString(g_hKeysArray, sKeyType);

	return true;
}

public Native_UnregKey(Handle:hPlugin, iNumParams)
{
	decl String:sKeyType[KEYS_MAX_LENGTH], index;
	GetNativeString(1, SZF(sKeyType));
	
	if((index = FindStringInArray(g_hKeysArray, sKeyType)) != -1)
	{
		RemoveFromArray(g_hKeysArray, index);
		decl Handle:hDataPack;
		if(GetTrieValue(g_hKeysTrie, sKeyType, hDataPack))
		{
			CloseHandle(hDataPack);
		}
		RemoveFromTrie(g_hKeysTrie, sKeyType);
	}
}

public Native_IsValidKeyType(Handle:hPlugin, iNumParams)
{
	decl String:sKeyType[KEYS_MAX_LENGTH], index;
	GetNativeString(1, SZF(sKeyType));
	
	return (FindStringInArray(g_hKeysArray, sKeyType) != -1);
}

public Native_FillArrayByKeyTypes(Handle:hPlugin, iNumParams)
{
	return CloneArray(g_hKeysArray);
}

public Native_IsValidKey(Handle:hPlugin, iNumParams)
{
	decl Handle:hDP, String:sKey[KEYS_MAX_LENGTH], String:sQuery[256];
	GetNativeString(1, SZF(sKey));
	
	hDP = CreateDataPack();
	WritePackCell(hDP, hPlugin);
	WritePackCell(hDP, GetNativeCell(2));
	WritePackString(hDP, sKey);

	if(!g_iServerID)
	{
		FormatEx(SZF(sQuery), "SELECT `expires` FROM `table_keys` WHERE `key_name` = '%s' LIMIT 1;", sKey);
	}
	else
	{
		FormatEx(SZF(sQuery), "SELECT `expires` FROM `table_keys` WHERE `key_name` = '%s' AND `sid` = %d LIMIT 1;", sKey, g_iServerID);
	}

	SQL_TQuery(g_hDatabase, SQL_Callback_Ntv_IsValidKey, sQuery, hDP);
}

public SQL_Callback_Ntv_IsValidKey(Handle:hOwner, Handle:hResult, const String:sDBError[], any:hDP)
{
	if (hResult == INVALID_HANDLE || sDBError[0])
	{
		CloseHandle(hDP);
		LogError("SQL_Callback_Ntv_IsValidKey: %s", sDBError);
		return;
	}
	
	ResetPack(hDP);
	decl Handle:hPlugin, Function:fCallback, String:sKey[KEYS_MAX_LENGTH], bool:bKeyExists;
	hPlugin = Handle:ReadPackCell(hDP);
	fCallback = Function:ReadPackCell(hDP);
	ReadPackString(SZF(sKey));
	CloseHandle(hDP);
	
	bKeyExists = false;

	if(SQL_FetchRow(hResult))
	{
		iExpires = SQL_FetchInt(hResult, 0);
		if(iExpires)
		{
			if(iExpires < GetTime())
			{
				DeleteKey(sKey);
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

	Call_StartFunction(hPlugin, fUseCallback);
	Call_PushString(sKey);
	Call_PushCell(bKeyExists);
	Call_Finish();
}

public Native_GetKeyData(Handle:hPlugin, iNumParams)
{
	decl Handle:hDP, String:sKey[KEYS_MAX_LENGTH], String:sQuery[256];
	GetNativeString(1, SZF(sKey));
	
	hDP = CreateDataPack();
	WritePackCell(hDP, hPlugin);
	WritePackCell(hDP, GetNativeCell(2));
	WritePackString(hDP, sKey);

	if(!g_iServerID)
	{
		FormatEx(SZF(sQuery), "SELECT `type`, `expires`, `uses`, `param1`, `param2`, `param3`, `param4`, `param5` FROM `table_keys` WHERE `key_name` = '%s' LIMIT 1;", sKey);
	}
	else
	{
		FormatEx(SZF(sQuery), "SELECT `type`, `expires`, `uses`, `param1`, `param2`, `param3`, `param4`, `param5` FROM `table_keys` WHERE `key_name` = '%s' AND `sid` = %d LIMIT 1;", sKey, g_iServerID);
	}

	SQL_TQuery(g_hDatabase, SQL_Callback_Ntv_GetKeyData, sQuery, hDP);
}

public SQL_Callback_Ntv_GetKeyData(Handle:hOwner, Handle:hResult, const String:sDBError[], any:iData)
{
	if (hResult == INVALID_HANDLE || sDBError[0])
	{
		LogError("SQL_Callback_Ntv_GetKeyData: %s", sDBError);
		return;
	}

	ResetPack(hDP);
	decl Handle:hPlugin, Function:fCallback, String:sKey[KEYS_MAX_LENGTH], bool:bKeyExists, Handle:hParamsArr, String:sKeyType[KEYS_MAX_LENGTH], String:sParam[KEYS_MAX_LENGTH], String:sError[256], iExpires, iUses, i;
	hPlugin = Handle:ReadPackCell(hDP);
	fCallback = Function:ReadPackCell(hDP);
	ReadPackString(SZF(sKey));
	CloseHandle(hDP);

	bKeyExists = false;

	if(SQL_FetchRow(hResult))
	{
		iExpires = SQL_FetchInt(hResult, 1);
		if(!iExpires || iExpires > GetTime())
		{
			SQL_FetchString(hResult, 1, SZF(sKeyType));
			if((FindStringInArray(g_hKeysArray, sKeyType) != -1))
			{
				iUses = SQL_FetchInt(hResult, 2);
				if(iUses)
				{
					hParamsArr = CreateArray(ByteCountToCells(KEYS_MAX_LENGTH));
					for(i = 3; i < 8; ++i)
					{
						if(SQL_IsFieldNull(hResult, i))
						{
							break;
						}

						SQL_FetchString(hResult, i, SZF(sParam));
						PushArrayString(hParamsArr, sParam);
					}

					bKeyExists = true;
				}
				else
				{
					DeleteKey(sKey);
				}
			}
		}
		else
		{
			DeleteKey(sKey);
		}
	}
	
	if(!bKeyExists)
	{
		sKeyType[0] = iCount = iExpires = 0;
		hParamsArr = INVALID_HANDLE;
	}

	Call_StartFunction(hPlugin, fCallback);
	Call_PushString(sKey);
	Call_PushCell(bKeyExists);
	Call_PushString(sKeyType);
	Call_PushCell(iCount);
	Call_PushCell(iExpires);
	Call_PushCell(hParamsArr);
	Call_Finish();

	if(hParamsArr)
	{
		CloseHandle(hParamsArr);
	}
}

public Native_GenerateKey(Handle:hPlugin, iNumParams)
{
	decl String:sKey[KEYS_MAX_LENGTH], String:sTemplate[64];
	GetNativeString(3, SZF(sTemplate));

	UTIL_GenerateKey(SZF(sKey), g_CVAR_sKeyTemplate);
	SetNativeString(1, sKey, GetNativeCell(2), true);
}

// native Keys_AddKey(const String:sKey[] = "", const String:sKeyType[], iUses, iLifeTime, Handle:hParamsArr, KeyAddCallback:AddKeyCallback);
// functag public KeyAddCallback(const String:sKey[], bool:bSuccess, const String:sError[]);
public Native_AddKey(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	if(iClient && (iClient < 0 || iClient > MaxClients || !IsClientInGame(iClient) || !IsFakeClient(iClient)))
	{
		return;
	}

	decl iHandle:hDP, String:sKey[KEYS_MAX_LENGTH], String:sKeyType[KEYS_MAX_LENGTH], String:sError[256], iLifeTime, iUses, Handle:hParamsArr, String:sQuery[256];
	GetNativeString(2, SZF(sKey));
	GetNativeString(3, SZF(sKeyType));
	hParamsArr = Handle:GetNativeCell(6);

	sError[0] = 0;

	if(!UTIL_CheckKey(sKey, sKeyType, GetNativeCell(5), GetNativeCell(4), hParamsArr, SZF(sError), iClient))
	{
		CloseHandle(hParamsArr);
		CreateCallback_AddKey(hPlugin, Function:GetNativeCell(7), false, sError);
		
		return;

	//	Keys_AddKey(const String:sKey[] = "", const String:sKeyType[], iUses, iLifeTime, Handle:hParamsArr, KeyAddCallback:AddKeyCallback);
	//	KeyAddCallback(const String:sKey[], bool:bSuccess, const String:sError[]);
	}

//	CloseHandle(hParamsArr);
	
	decl Handle:hDP, String:sQuery[256], iExpires;

	iClient = GET_UID(iClient);

	iExpires = iLifeTime ? (iLifeTime + GetTime()):iLifeTime;
	
	hDP = CreateDataPack();
	WritePackCell(hDP, CloneArray(hParamsArr));

	if(sKey[0])
	{
		WritePackString(hDP, sKey);
		WritePackCell(hDP, true);
	}
	else
	{
		UTIL_GenerateKey(sKey, KEYS_MAX_LENGTH, g_CVAR_sKeyTemplate);

		WritePackString(hDP, sKey);
		WritePackCell(hDP, false);
	}

	WritePackCell(hDP, iClient);
	WritePackCell(hDP, CmdReplySource);
	WritePackString(hDP, sKeyType);
	WritePackCell(hDP, iUses);
	WritePackCell(hDP, iExpires);
	WritePackCell(hDP, iLifeTime);
	WritePackCell(hDP, hPlugin);
	WritePackCell(hDP, GetNativeCell(6));
	
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

CreateCallback_AddKey(Handle:hPlugin, Function:fCallback, const String:sKey[], bool:bSuccess = true, const String:sError[] = NULL_STRING)
{
	Call_StartFunction(hPlugin, fCallback);
	Call_PushString(sKey);
	Call_PushCell(bSuccess);
	Call_PushString(sError);
	Call_Finish();
}

public Native_RemoveKey(Handle:hPlugin, iNumParams)
{
	decl Handle:hDP, String:sKey[KEYS_MAX_LENGTH], String:sQuery[256];
	GetNativeString(1, SZF(sKey));
	
	hDP = CreateDataPack();
	WritePackCell(hDP, hPlugin);
	WritePackCell(hDP, GetNativeCell(2));
	WritePackString(hDP, sKey);

	if(!g_iServerID)
	{
		FormatEx(SZF(sQuery), "DELETE FROM `table_keys` WHERE `key_name` = '%s';", sKey);
	}
	else
	{
		FormatEx(SZF(sQuery), "DELETE FROM `table_keys` WHERE `key_name` = '%s' AND `sid` = %d;", sKey, g_iServerID);
	}
	SQL_TQuery(g_hDatabase, SQL_Callback_Ntv_RemoveKey, sQuery, hDP);
}

public SQL_Callback_Ntv_RemoveKey(Handle:hOwner, Handle:hResult, const String:sDBError[], any:iData)
{
	if (hResult == INVALID_HANDLE || sDBError[0])
	{
		LogError("SQL_Callback_Ntv_RemoveKey: %s", sDBError);
		return;
	}

	ResetPack(hDP);
	decl Handle:hPlugin, Function:fCallback, String:sKey[KEYS_MAX_LENGTH];
	hPlugin = Handle:ReadPackCell(hDP);
	fCallback = Function:ReadPackCell(hDP);
	ReadPackString(SZF(sKey));
	CloseHandle(hDP);

	Call_StartFunction(hPlugin, fCallback);
	Call_PushString(sKey);
	Call_PushCell(bool:SQL_GetAffectedRows(hOwner));
	Call_Finish();
}

// Использует ключ игроком
public Native_UseKey(Handle:hPlugin, iNumParams)
{
	
}
