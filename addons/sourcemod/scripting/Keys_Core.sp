#pragma semicolon 1

#include <sourcemod>
#include <keys_core>

public Plugin:myinfo =
{
	name		= "[Keys] Core",
	author	= "R1KO",
	version	= "1.4",
	url		= "hlmod.ru"
};

#include "keys/vars.sp"
#include "keys/utils.sp"
#include "keys/api.sp"
#include "keys/cmds.sp"

public OnPluginStart()
{
	LoadTranslations("keys_core.phrases");

	g_bIsStarted = false;
	g_iServerID = 0;

	BuildPath(Path_SM, SZF(g_sLogFile), "logs/Keys.log");

	g_hKeysTrie = CreateTrie();
	g_hKeysArray = CreateArray(ByteCountToCells(KEYS_MAX_LENGTH));

	new Handle:hCvar = CreateConVar("key_length", "32", "Длина генерируемого ключа (8-64)", _, true, 8.0, true, 64.0);
	HookConVarChange(hCvar, OnKeyLengthChange);
	g_CVAR_iKeyLength = GetConVarInt(hCvar);

	hCvar = CreateConVar("key_template", "", "Шаблон для генерируемого ключа (Подробнее http://hlmod.ru/resources/keys-core.438/)
	Пример: XXXX-XXXX-XXXX-XXXX", _, false, 0.0, true, 64.0);

	HookConVarChange(hCvar, OnKeyTemplateChange);
	GetConVarString(hCvar, SZF(g_CVAR_sKeyTemplate));

	hCvar = CreateConVar("key_server_id", "0", "ID сервера", _, true, -1.0);
	HookConVarChange(hCvar, OnServerIDChange);
	g_CVAR_iServerID = GetConVarInt(hCvar);

	hCvar = CreateConVar("key_attempts", "3", "Количество попыток ввода ключа до получения блокировки (0 - Отключено)", _, true, 0.0);
	HookConVarChange(hCvar, OnAttemptsChange);
	g_CVAR_iAttempts = GetConVarInt(hCvar);

	hCvar = CreateConVar("key_block_time", "60", "На сколько минут будет заблокирован игрок при вводе неверных ключей", _, true, 1.0);
	HookConVarChange(hCvar, OnBlockTimeChange);
	g_CVAR_iBlockTime = GetConVarInt(hCvar);

	AutoExecConfig(true, "Keys_Core");

	RegAdminCmds();

	Connect_DB();
}

public OnKeyLengthChange(Handle:hCvar, const String:oldValue[], const String:newValue[])	g_CVAR_iKeyLength = GetConVarInt(hCvar);
public OnKeyTemplateChange(Handle:hCvar, const String:oldValue[], const String:newValue[])	GetConVarString(hCvar, SZF(g_CVAR_sKeyTemplate));
public OnServerIDChange(Handle:hCvar, const String:oldValue[], const String:newValue[])
{
	g_CVAR_iServerID = GetConVarInt(hCvar);
	if(g_bDBMySQL && g_bIsStarted)
	{
		GetServerID(false);
	}
}
public OnAttemptsChange(Handle:hCvar, const String:oldValue[], const String:newValue[])	g_CVAR_iAttempts = GetConVarInt(hCvar);
public OnBlockTimeChange(Handle:hCvar, const String:oldValue[], const String:newValue[])	g_CVAR_iBlockTime = GetConVarInt(hCvar);

Connect_DB()
{
	if (SQL_CheckConfig("keys_core"))
	{
		SQL_TConnect(DB_OnConnect, "keys_core", 1);
	}
	else
	{
		decl String:sError[256];
		sError[0] = '\0';
		g_hDatabase = SQLite_UseDatabase("keys_core", SZF(sError));
		DB_OnConnect(g_hDatabase, g_hDatabase, sError, 0);
	}
}

public DB_OnConnect(Handle:owner, Handle:hndl, const String:sError[], any:data)
{
	g_hDatabase = hndl;
	
	if (g_hDatabase == INVALID_HANDLE || sError[0])
	{
		SetFailState("Failed DB Connect %s", sError);
		return;
	}

	decl String:sDriver[16];
	if(data)
	{
		SQL_GetDriverIdent(owner, SZF(sDriver));
	}
	else
	{
		SQL_ReadDriver(owner, SZF(sDriver));
	}

	g_bDBMySQL = (strcmp(sDriver, "mysql", false) == 0);

	if (g_bDBMySQL)
	{
		SQL_TQuery(g_hDatabase, SQL_Callback_ErrorCheck, "SET NAMES 'utf8'");
		SQL_TQuery(g_hDatabase, SQL_Callback_ErrorCheck, "SET CHARSET 'utf8'");
	}

	CreateTables();
}

CreateTables()
{
	new Handle:hTxn = SQL_CreateTransaction();

	if (g_bDBMySQL)
	{
		SQL_AddQuery(hTxn, "CREATE TABLE IF NOT EXISTS `table_keys` (\
								`key_name` VARCHAR(64) NOT NULL, \
								`type` VARCHAR(64) NOT NULL, \
								`expires` INTEGER UNSIGNED NOT NULL default 0, \
								`uses` INTEGER UNSIGNED NOT NULL default 1, \
								`sid` INTEGER NOT NULL default 0, \
								`param1` VARCHAR(64) NULL default NULL, \
								`param2` VARCHAR(64) NULL default NULL, \
								`param3` VARCHAR(64) NULL default NULL, \
								`param4` VARCHAR(64) NULL default NULL, \
								`param5` VARCHAR(64) NULL default NULL, \
								PRIMARY KEY(`key_name`)) DEFAULT CHARSET=utf8;");

		SQL_AddQuery(hTxn, "CREATE TABLE IF NOT EXISTS `keys_blocked_players` (\
								`auth` VARCHAR(24) NOT NULL, \
								`block_end` INTEGER UNSIGNED NOT NULL, \
								`sid` INTEGER NOT NULL, \
								PRIMARY KEY(`auth`)) DEFAULT CHARSET=utf8;");

		SQL_AddQuery(hTxn, "CREATE TABLE IF NOT EXISTS `keys_players_used` (\
								`auth` VARCHAR(24) NOT NULL, \
								`key_name` VARCHAR(64) NOT NULL, \
								`sid` INTEGER NOT NULL) DEFAULT CHARSET=utf8;");

		SQL_AddQuery(hTxn, "CREATE TABLE IF NOT EXISTS `keys_servers` (\
								`sid` INTEGER NOT NULL AUTO_INCREMENT,\
								`address` VARCHAR(24) NOT NULL, \
								PRIMARY KEY(`sid`), \
								UNIQUE KEY `address` (`address`)) DEFAULT CHARSET=utf8;");
		g_iServerID = -1;
	}
	else
	{
		SQL_AddQuery(hTxn, "CREATE TABLE IF NOT EXISTS `table_keys` (\
								`key_name` VARCHAR(64) NOT NULL PRIMARY KEY, \
								`type` VARCHAR(64) NOT NULL, \
								`expires` INTEGER UNSIGNED NOT NULL default 0, \
								`uses` INTEGER UNSIGNED NOT NULL default 1, \
								`param1` VARCHAR(64) NULL default NULL, \
								`param2` VARCHAR(64) NULL default NULL, \
								`param3` VARCHAR(64) NULL default NULL, \
								`param4` VARCHAR(64) NULL default NULL, \
								`param5` VARCHAR(64) NULL default NULL);");

		SQL_AddQuery(hTxn, "CREATE TABLE IF NOT EXISTS `keys_blocked_players` (\
								`auth` VARCHAR(24) NOT NULL PRIMARY KEY, \
								`block_end` INTEGER UNSIGNED NOT NULL);");

		SQL_AddQuery(hTxn, "CREATE TABLE IF NOT EXISTS `keys_players_used` (\
								`auth` VARCHAR(24) NOT NULL, \
								`key_name` VARCHAR(64) NOT NULL);");
		g_iServerID = 0;
	}

	SQL_ExecuteTransaction(g_hDatabase, hTxn, SQL_Callback_TxnSuccess, SQL_Callback_TxnFailure, 0, DBPrio_High);
}

public SQL_Callback_TxnFailure(Handle:hDB, any:data, iNumQueries, const String:sError[], iFailIndex, any:queryData[])
{
	SetFailState("Не удалось создать таблицу (%i): %s", iFailIndex, sError);
}

public SQL_Callback_TxnSuccess(Handle:hDB, any:data, iNumQueries, Handle:hResults[], any:queryData[])
{
	if(g_bDBMySQL)
	{
		SQL_SetCharset(g_hDatabase, "utf8");

		if(g_iServerID == -1)
		{
			GetServerID(true);
			return;
		}
	}

	Notify_Started();
}

Notify_Started()
{
	g_bIsStarted = true;

	CreateForward_OnCoreStarted();

	DeleteExpiredKeys();
}

public OnConfigsExecuted()
{
	if(g_bIsStarted)
	{
		DeleteExpiredKeys();
	}
}

DeleteExpiredKeys()
{
	decl String:sQuery[256];
	if(!g_iServerID)
	{
		FormatEx(SZF(sQuery), "DELETE FROM `table_keys` WHERE `expires` > 0 AND `expires` < %d;", GetTime());
	}
	else
	{
		FormatEx(SZF(sQuery), "DELETE FROM `table_keys` WHERE `expires` > 0 AND `expires` < %d AND `sid` = %d;", GetTime(), g_iServerID);
	}
	SQL_TQuery(g_hDatabase, SQL_Callback_ErrorCheck, sQuery);
}

public SQL_Callback_ErrorCheck(Handle:hOwner, Handle:hResult, const String:sError[], any:data)
{
	if (sError[0])
	{
		LogError("SQL_Callback_ErrorCheck: %s", sError);
	}
}

#define GetServerIp(%1,%2) GetServerIpFunc(_:(%1), %1, %2)

GetServerIpFunc(array[], String:sBuffer[], iMaxLength)
{
	array[0] = GetConVarInt(FindConVar("hostip"));
	FormatEx(sBuffer, iMaxLength, "%d.%d.%d.%d:%d", sBuffer[3] + 0, sBuffer[2] + 0, sBuffer[1] + 0, sBuffer[0] + 0, GetConVarInt(FindConVar("hostport")));
}

GetServerID(bool:bNotifyStarted)
{
	if(g_CVAR_iServerID == -1)
	{
		decl String:sAddress[24], String:sQuery[256];
		GetServerIp(sAddress, sizeof(sAddress));
		FormatEx(SZF(sQuery), "SELECT `sid` FROM `keys_servers` WHERE `address` = '%s';", sAddress);
		SQL_TQuery(g_hDatabase, SQL_Callback_SelectServerID, sQuery, bNotifyStarted);
		return;
	}

	g_iServerID = g_CVAR_iServerID;

	if(bNotifyStarted)
	{
		Notify_Started();
	}
}

public SQL_Callback_SelectServerID(Handle:hOwner, Handle:hResult, const String:sError[], any:bNotifyStarted)
{
	if (hResult == INVALID_HANDLE || sError[0])
	{
		LogError("SQL_Callback_SelectServerID: %s", sError);
		return;
	}

	if(SQL_FetchRow(hResult))
	{
		g_iServerID = SQL_FetchInt(hResult, 0);

		if(bNotifyStarted)
		{
			Notify_Started();
		}
		return;
	}
	
	decl String:sAddress[24], String:sQuery[256];
	GetServerIp(sAddress, sizeof(sAddress));
	FormatEx(SZF(sQuery), "INSERT INTO `keys_servers` (`address`) VALUES ('%s');", sAddress);
	SQL_TQuery(g_hDatabase, SQL_Callback_CreateServerID, sQuery, bNotifyStarted);
}

public SQL_Callback_CreateServerID(Handle:hOwner, Handle:hResult, const String:sError[], any:bNotifyStarted)
{
	if (hResult == INVALID_HANDLE || sError[0])
	{
		LogError("SQL_Callback_CreateServerID: %s", sError);
		return;
	}

	if(SQL_GetAffectedRows(hResult))
	{
		g_iServerID = SQL_GetInsertId(g_hDatabase);

		if(bNotifyStarted)
		{
			Notify_Started();
		}
	}
}

public Action:OnClientSayCommand(iClient, const String:sCommand[], const String:sArgs[])
{
	if(StrContains(sArgs, "key") != -1)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public OnClientDisconnect(iClient)
{
	g_iAttempts[iClient] = 0;
	g_bIsBlocked[iClient] = false;
}

public OnClientPostAdminCheck(iClient)
{
	if(!IsFakeClient(iClient))
	{
		decl String:sQuery[256], String:sAuth[32];
		GetClientAuthId(iClient, AuthId_Engine, SZF(sAuth));
		if(!g_iServerID)
		{
			FormatEx(SZF(sQuery), "SELECT `block_end` FROM `keys_blocked_players` WHERE `auth` = '%s';", sAuth);
		}
		else
		{
			FormatEx(SZF(sQuery), "SELECT `block_end` FROM `keys_blocked_players` WHERE `auth` = '%s' AND `sid` = %d;", sAuth, g_iServerID);
		}
		SQL_TQuery(g_hDatabase, SQL_Callback_SearchPlayer, sQuery, UID(iClient));
	}
}

public SQL_Callback_SearchPlayer(Handle:hOwner, Handle:hResult, const String:sError[], any:UserID)
{
	if (hResult == INVALID_HANDLE || sError[0])
	{
		LogError("SQL_Callback_SearchPlayer: %s", sError);
		return;
	}

	new iClient = CID(UserID);
	if (iClient)
	{
		if(SQL_FetchRow(hResult))
		{
			g_iAttempts[iClient] = SQL_FetchInt(hResult, 0);
			if(g_iAttempts[iClient] < GetTime())
			{
				UnBlockClient(iClient);
				return;
			}
			
			g_bIsBlocked[iClient] = true;
		}
	}
}

BlockClient(iClient)
{
	g_bIsBlocked[iClient] = true;
	g_iAttempts[iClient] = GetTime()+(g_CVAR_iBlockTime*60);
	decl String:sQuery[256], String:sName[MAX_NAME_LENGTH], String:sAuth[32];
	GetClientName(iClient, SZF(sName));
	GetClientAuthId(iClient, AuthId_Engine, SZF(sAuth));
	
	LogToFile(g_sLogFile, "%T", "LOG_BLOCKED", LANG_SERVER, sName, sAuth);

	if(!g_iServerID)
	{
		FormatEx(SZF(sQuery), "INSERT INTO `keys_blocked_players` (`auth`, `block_end`) VALUES ('%s', %d);", sAuth, g_iAttempts[iClient]);
	}
	else
	{
		FormatEx(SZF(sQuery), "INSERT INTO `keys_blocked_players` (`auth`, `block_end`, `sid`) VALUES ('%s', %d, %d);", sAuth, g_iAttempts[iClient], g_iServerID);
	}

	SQL_TQuery(g_hDatabase, SQL_Callback_ErrorCheck, sQuery);
}

UnBlockClient(iClient)
{
	g_bIsBlocked[iClient] = false;
	g_iAttempts[iClient] = 0;
	decl String:sQuery[256], String:sAuth[32];
	GetClientAuthId(iClient, AuthId_Engine, SZF(sAuth));
	if(!g_iServerID)
	{
		FormatEx(SZF(sQuery), "DELETE FROM `keys_blocked_players` WHERE `auth` = '%s';", sAuth);
	}
	else
	{
		FormatEx(SZF(sQuery), "DELETE FROM `keys_blocked_players` WHERE `auth` = '%s' AND `sid` = %d;", sAuth, g_iServerID);
	}
	SQL_TQuery(g_hDatabase, SQL_Callback_ErrorCheck, sQuery);
}

DeleteKey(const String:sKey[], iClient = -1, ReplySource:CmdReplySource = SM_REPLY_TO_CONSOLE)
{
	decl String:sQuery[256], Handle:hDP;

	hDP = CreateDataPack();
	WritePackString(hDP, sKey);
	if(iClient == -1)
	{
		WritePackCell(hDP, false);
	}
	else
	{
		WritePackCell(hDP, true);
		WritePackCell(hDP, GET_UID(iClient));
		WritePackCell(hDP, CmdReplySource);
	}

	if(!g_iServerID)
	{
		FormatEx(SZF(sQuery), "DELETE FROM `table_keys` WHERE `key_name` = '%s';", sKey);
	}
	else
	{
		FormatEx(SZF(sQuery), "DELETE FROM `table_keys` WHERE `key_name` = '%s' AND `sid` = %d;", sKey, g_iServerID);
	}
	SQL_TQuery(g_hDatabase, SQL_Callback_RemoveKey, sQuery, hDP);
}