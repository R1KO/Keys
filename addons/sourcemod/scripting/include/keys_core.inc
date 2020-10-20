#if defined _keys_core_included
 #endinput
#endif
#define _keys_core_included

#define KEYS_MAX_LENGTH		64

// Прототип вызова при валидации параметров ключа
typedef KeyParamsValidateCallback = function bool (int iClient, const char[] sKeyType, ArrayList hParamsArr, char[] sError, int iErrLen);

// Прототип вызова при акцивации ключа
typedef KeyUseCallback = function bool (int iClient, const char[] sKeyType, ArrayList hParamsArr, char[] sError, int iErrLen);

// Прототип вызова при выводе параметров ключа
typedef KeyPrintCallback = function void (int iClient, const char[] sKeyType, ArrayList hParamsArr, char[] sBuffer, int iBufLen);

// Вызывается когда ядро было загружено
forward void Keys_OnCoreStarted();

// Загружено ли ядро
native bool Keys_IsCoreStarted();

// Получает Handle базы данных
native Database Keys_GetCoreDatabase();

// Регистрирует тип ключей
native bool Keys_RegKey(const char[] sKeyType,
					KeyParamsValidateCallback OnKeyParamsValidate,
					KeyUseCallback OnKeyUse,
					KeyPrintCallback OnKeyPrint);

// Разрегистрирует тип ключей
native void Keys_UnregKey(const char[] sKeyType);

// Для использования не забыть:
// LoadTranslations("keys_core.phrases");
stock void Keys_GetTimeFromStamp(char[] sBuffer, int iMaxLength, int iTimeStamp, int iClient = LANG_SERVER)
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
	MarkNativeAsOptional("Keys_RegKey");
	MarkNativeAsOptional("Keys_UnregKey");
}
#endif
