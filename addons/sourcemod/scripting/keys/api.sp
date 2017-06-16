
static Handle:g_hGlobalForward_OnCoreStarted;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) 
{
	MarkNativeAsOptional("GetClientAuthId");
	MarkNativeAsOptional("GetClientAuthString");
	
	g_hGlobalForward_OnCoreStarted = CreateGlobalForward("Keys_OnCoreStarted", ET_Ignore);

	CreateNative("Keys_IsCoreStarted", Native_IsCoreStarted);
	CreateNative("Keys_GetCoreDatabase", Native_GetCoreDatabase);
	CreateNative("Keys_RegKey", Native_RegKey);
	CreateNative("Keys_UnregKey", Native_UnregKey);

	/*
	CreateNative("Keys_GenerateKey", Native_GenerateKey);
	CreateNative("Keys_AddKey", Keys_AddKey);
	CreateNative("Keys_RemoveKey", Keys_RemoveKey);
	CreateNative("Keys_IsValidKey", Native_IsValidKey);
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

public Native_RegKey(Handle:hPlugin, iNumParams)
{
	decl String:sKeyType[KEYS_MAX_LENGTH];
	GetNativeString(1, sKeyType, sizeof(sKeyType));
	
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
	GetNativeString(1, sKeyType, sizeof(sKeyType));
	
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
