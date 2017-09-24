#if defined _keys_core_included
 #endinput
#endif
#define _keys_core_included

#define KEYS_MAX_LENGTH		64

// Прототип вызова при валидации параметров ключа
functag public bool:KeyParamsValidateCallback(iClient, const String:sKeyType[], Handle:hParamsArr, String:sError[], iErrLen);

// Прототип вызова при акцивации ключа
functag public bool:KeyUseCallback(iClient, const String:sKeyType[], Handle:hParamsArr, String:sError[], iErrLen);

// Прототип вызова при выводе параметров ключа
functag public KeyPrintCallback(iClient, const String:sKeyType[], Handle:hParamsArr, String:sBuffer[], iBufLen);

// Прототип вызова при проверке существования ключа
functag public KeyCheckValidKeyCallback(const String:sKey[], bool:bKeyExists);

// Прототип вызова при получении данных ключа
functag public KeyGetDataCallback(const String:sKey[], bool:bKeyExists, const String:sKeyType[], iUses, iExpires, Handle:hParamsArr);

// Прототип вызова при добавлении ключа
functag public KeyAddCallback(iClient, const String:sKey[], bool:bSuccess, const String:sError[]);

// Прототип вызова при использоании ключа игроком
functag public KeyUseCallback(iClient, const String:sKey[], bool:bSuccess, String:sError[]);

// Прототип вызова при удалении ключа
functag public KeyRemoveCallback(const String:sKey[], bool:bSuccess);

// Вызывается когда ядро было загружено
forward Keys_OnCoreStarted();

// Загружено ли ядро
native bool:Keys_IsCoreStarted();

// Получает Handle базы данных
native Handle:Keys_GetCoreDatabase();

// Получает тип базы данных (false - SQLite, true - MySQL)
native bool:Keys_GetDatabaseType();

// Регистрирует тип ключей
native bool:Keys_RegKey(const String:sKeyType[],
					KeyParamsValidateCallback:OnKeyParamsValidate,
					KeyUseCallback:OnKeyUse,
					KeyPrintCallback:OnKeyPrint);

// Разрегистрирует тип ключей
native Keys_UnregKey(const String:sKeyType[]);

// Проверяет существование типа ключей
native bool:Keys_IsValidKeyType(const String:sKeyType[]);

// Получает adt_array со всеми типами ключей (нужно закрывать Handle)
native Handle:Keys_FillArrayByKeyTypes();

// Проверяет существование ключа
native Keys_IsValidKey(const String:sKey[], KeyCheckValidKeyCallback:IsValidKeyCallback);

// Получает данные ключа
native Keys_GetKeyData(const String:sKey[], KeyGetDataCallback:GetKeyDataCallback);

// Генерирует ключ
native Keys_GenerateKey(String:sBuffer[], iBufLen, const String:sTemplate[] = "");

// Добавляет ключ
native Keys_AddKey(iClient = 0, const String:sKey[] = "", const String:sKeyType[], iUses, iLifeTime, Handle:hParamsArr, KeyAddCallback:AddKeyCallback);

// Удаляет ключ
native Keys_RemoveKey(const String:sKey[], KeyRemoveCallback:RemoveKeyCallback);

// Использует ключ игроком
native Keys_UseKey(iClient, const String:sKey[], bool:bNotify, KeyUseCallback:UseKeyCallback);
	
// Для использования не забыть:
// LoadTranslations("keys_core.phrases");
stock Keys_GetTimeFromStamp(String:sBuffer[], iMaxLength, iTimeStamp, iClient = LANG_SERVER)
{
	if (iTimeStamp > 31536000)
	{
		new iYears = iTimeStamp / 31536000;
		new i = iTimeStamp - (iYears*31536000);
		if(i > 2592000)
		{
			FormatEx(sBuffer, iMaxLength, "%d %T %d %T", iYears, "YEARS", iClient, i / 2592000, "MONTHS", iClient);
		}
		else
		{
			FormatEx(sBuffer, iMaxLength, "%d %T", iYears, "YEARS", iClient);
		}
		return;
	}

	if (iTimeStamp > 2592000)
	{
		new iMonths = iTimeStamp / 2592000;
		new i = iTimeStamp - (iMonths*2592000);
		if (i > 86400)
		{
			FormatEx(sBuffer, iMaxLength, "%d %T %d %T", iMonths, "MONTHS", iClient, i / 86400, "DAYS", iClient);
		}
		else
		{
			FormatEx(sBuffer, iMaxLength, "%d %T", iMonths, "MONTHS", iClient);
		}
		return;
	}

	if (iTimeStamp > 86400)
	{
		new iDays = iTimeStamp / 86400 % 365;
		new iHours = (iTimeStamp / 3600) % 24;
		if (iHours > 0)
		{
			FormatEx(sBuffer, iMaxLength, "%d %T %d %T", iDays, "DAYS", iClient, iHours, "HOURS", iClient);
		}
		else
		{
			FormatEx(sBuffer, iMaxLength, "%d %T", iDays, "DAYS", iClient);
		}
		return;
	}

	new iHours = (iTimeStamp / 3600);
	new iMins = (iTimeStamp / 60) % 60;
	new iSecs = iTimeStamp % 60;
	
	if (iHours > 0)
	{
		FormatEx(sBuffer, iMaxLength, "%02d:%02d:%02d", iHours, iMins, iSecs);
	}
	else
	{
		FormatEx(sBuffer, iMaxLength, "%02d:%02d", iMins, iSecs);
	}
}

public SharedPlugin:__pl_keys_core= 
{
	name = "keys_core",
	file = "Keys_Core.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN

public __pl_keys_core_SetNTVOptional()
{
	MarkNativeAsOptional("Keys_IsCoreStarted");
	MarkNativeAsOptional("Keys_GetCoreDatabase");
	MarkNativeAsOptional("Keys_GetDatabaseType");
	MarkNativeAsOptional("Keys_RegKey");
	MarkNativeAsOptional("Keys_UnregKey");
	MarkNativeAsOptional("Keys_IsValidKeyType");
	MarkNativeAsOptional("Keys_FillArrayByKeyTypes");
	MarkNativeAsOptional("Keys_IsValidKey");
	MarkNativeAsOptional("Keys_GetKeyData");
	MarkNativeAsOptional("Keys_GenerateKey");
	MarkNativeAsOptional("Keys_AddKey");
	MarkNativeAsOptional("Keys_RemoveKey");
	MarkNativeAsOptional("Keys_UseKey");
}
#endif
