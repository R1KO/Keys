#if defined _keys_core_included
 #endinput
#endif
#define _keys_core_included

#define KEYS_MAX_LENGTH		64

enum KeysAction
{
	Validation = 0,		// Валидация параметров ключа
	Activation,			// Активация ключа
	Print				// Вывод ключа в консоль/файл
};

enum KeysNativeAction
{
	Add = 0,			// Добавление/Генерация ключа
	Rem,				// Удаление ключа
	Use					// Использование ключа
};

// Прототип вызова при валидации параметров/акцивации/выводе параметров ключа
typedef KeyActionCallback = function bool (KeysAction eKeysAction, int iClient, const char[] szKeyType, ArrayList hParamsArr, char[] szBuffer, int iBuffLen);

typeset KeyInfoCallback
{
    // Прототип вызова при проверке существования ключа
    function void (const char[] sKey, bool bKeyExists, any iData);
 
    // Прототип вызова при получении данных ключа
    function void (const char[] sKey, bool bKeyExists, const char[] sKeyType, int iUses, int iExpires, ArrayList hParamsArr, any iData);
};

// Прототип вызова при добавлении/удалении/использовании ключа
typedef KeyNativeActionCallback = function void (KeysNativeAction eKeysAction, int iClient, const char[] sKey, bool bSuccess, const char[] sError, any iData);

// Вызывается когда ядро было загружено
forward void Keys_OnCoreStarted();

// Загружено ли ядро
native bool Keys_IsCoreStarted();

// Получает Handle базы данных
native Database Keys_GetCoreDatabase();

// Получает тип базы данных (false - SQLite, true - MySQL)
native bool Keys_GetDatabaseType();

// Регистрирует тип ключей
native bool Keys_RegKey(const char[] sKeyType, KeyActionCallback fCallback);

// Разрегистрирует тип ключей
native void Keys_UnregKey(const char[] sKeyType);

// Проверяет существование типа ключей
native bool Keys_IsValidKeyType(const char[] sKeyType);

// Получает adt_array со всеми типами ключей (нужно закрывать Handle)
native ArrayList Keys_FillArrayByKeyTypes();

// Проверяет существование ключа
native void Keys_IsValidKey(const char[] sKey, KeyInfoCallback IsValidKeyCallback, any iData = 0);

// Получает данные ключа
native void Keys_GetKeyData(const char[] sKey, KeyInfoCallback GetKeyDataCallback, any iData = 0);

// Генерирует ключ
native void Keys_GenerateKey(char[] sBuffer, iBufLen, const char[] sTemplate = NULL_STRING);

// Добавляет ключ
native void Keys_AddKey(int iClient = 0, const char[] sKey = NULL_STRING, const char[] sKeyType, int iUses, iLifeTime, ArrayList hParamsArr, KeyNativeActionCallback AddKeyCallback, any iData = 0);

// Удаляет ключ
native void Keys_RemoveKey(int iClient = 0, const char[] sKey, KeyNativeActionCallback RemoveKeyCallback, any iData = 0);

// Использует ключ игроком
native void Keys_UseKey(int iClient, const char[] sKey, bool bNotify, bool bIgnoreBlock, KeyNativeActionCallback UseKeyCallback, any iData = 0);

// Для использования не забыть 
// LoadTranslations("keys_core.phrases");
stock void Keys_GetTimeFromStamp(char[] sBuffer, int iMaxLength, int iTimeStamp, int iClient = LANG_SERVER)
{
	if (iTimeStamp > 31536000)
	{
		int iYears = iTimeStamp / 31536000;
		int i = iTimeStamp - (iYears*31536000);
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
		int iMonths = iTimeStamp / 2592000;
		int i = iTimeStamp - (iMonths*2592000);
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
		int iDays = iTimeStamp / 86400 % 365;
		int iHours = (iTimeStamp / 3600) % 24;
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

	int iHours = (iTimeStamp / 3600);
	int iMins = (iTimeStamp / 60) % 60;
	int iSecs = iTimeStamp % 60;
	
	if (iHours > 0)
	{
		FormatEx(sBuffer, iMaxLength, "%02d %02d %02d", iHours, iMins, iSecs);
	}
	else
	{
		FormatEx(sBuffer, iMaxLength, "%02d %02d", iMins, iSecs);
	}
}

public SharedPlugin __pl_keys_core= 
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

public void __pl_keys_core_SetNTVOptional()
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
