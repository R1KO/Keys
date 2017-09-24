#pragma semicolon 1

#include <sourcemod>
#include <keys_core>

#pragma newdecls required
#define PLUGIN_VERSION	"2.0"

public Plugin myinfo =
{
	name	= "[Keys] Core",
	author	= "R1KO",
	version	= PLUGIN_VERSION,
	url		= "hlmod.ru"
};

#include "Keys/VARS.sp"
#include "Keys/UTIL.sp"
#include "Keys/KEYS.sp"
#include "Keys/API.sp"
#include "Keys/CMD.sp"
#include "Keys/EVENTS.sp"
#include "Keys/BLOCK.sp"
// #include "Keys/STATS.sp"

public void OnPluginStart()
{
	LoadTranslations("keys_core.phrases");

	g_bIsStarted = false;

	BuildPath(Path_SM, SZF(g_sLogFile), "logs/Keys.log");

	g_hKeysTrie = new StringMap();
	g_hKeysArray = new ArrayList(ByteCountToCells(KEYS_MAX_LENGTH));

	CreateConVar("sm_keys_core_version", PLUGIN_VERSION, "KEYS-CORE VERSION", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_CHEAT|FCVAR_DONTRECORD);

	ConVar hCvar = CreateConVar("key_length", "32", "Длина генерируемого ключа (8-64)", _, true, 8.0, true, 64.0);
	hCvar.AddChangeHook(OnKeyLengthChange);
	g_CVAR_iKeyLength = hCvar.IntValue;

	hCvar = CreateConVar("key_template", "", "Шаблон для генерируемого пароля (Подробнее http://hlmod.ru/resources/keys-core.438/)\n\
	Пример: XXXX-XXXX-XXXX-XXXX", _, false, 0.0, true, 64.0);

	hCvar.AddChangeHook(OnKeyTemplateChange);
	hCvar.GetString(SZF(g_CVAR_sKeyTemplate));

	hCvar = CreateConVar("key_server_id", "0", "ID сервера (0 - Не использовать. 1 и больше - Использовать указанный)", _, true, 0.0);
	hCvar.AddChangeHook(OnServerIDChange);
	g_CVAR_iServerID = hCvar.IntValue;

	hCvar = CreateConVar("key_attempts", "3", "Количество попыток ввода ключа до получения блокировки (0 - Отключено)", _, true, 0.0);
	hCvar.AddChangeHook(OnAttemptsChange);
	g_CVAR_iAttempts = hCvar.IntValue;

	hCvar = CreateConVar("key_block_time", "60", "На сколько минут будет заблокирован игрок при вводе неверных ключей (0 - Навсегда)", _, true, 0.0);
	hCvar.AddChangeHook(OnBlockTimeChange);
	g_CVAR_iBlockTime = hCvar.IntValue;
	
//	Stats_OnPluginStart();

	AutoExecConfig(true, "Keys_Core");

	CMD_Reg();

	Connect_DB();
}

public void OnKeyLengthChange(ConVar hCvar, const char[] oldValue, const char[] newValue)
{
	g_CVAR_iKeyLength = hCvar.IntValue;
}

public void OnKeyTemplateChange(ConVar hCvar, const char[] oldValue, const char[] newValue)
{
	hCvar.GetString(SZF(g_CVAR_sKeyTemplate));
}

public void OnServerIDChange(ConVar hCvar, const char[] oldValue, const char[] newValue)
{
	g_CVAR_iServerID = hCvar.IntValue;
}

public void OnAttemptsChange(ConVar hCvar, const char[] oldValue, const char[] newValue)
{
	g_CVAR_iAttempts = hCvar.IntValue;
}

public void OnBlockTimeChange(ConVar hCvar, const char[] oldValue, const char[] newValue)
{
	g_CVAR_iBlockTime = hCvar.IntValue;
}

void Connect_DB()
{
	if (SQL_CheckConfig("keys_core"))
	{
		Database.Connect(DB_OnConnect, "keys_core", 1);
	}
	else
	{
		char szError[PMP];
		szError[0] = '\0';
		g_hDatabase = SQLite_UseDatabase("keys_core", SZF(szError));
		DB_OnConnect(g_hDatabase, szError, 0);
	}
}

public void DB_OnConnect(Database hDatabase, const char[] szError, any data)
{
	if (hDatabase == null || szError[0])
	{
		SetFailState("Failed DB Connect %s", szError);
		return;
	}

	g_hDatabase = hDatabase;

	char sDriver[16];
	g_hDatabase.Driver.GetIdentifier(SZF(sDriver));

	g_bDBMySQL = (strcmp(sDriver, "mysql", false) == 0);

	if (g_bDBMySQL)
	{
		g_hDatabase.Query(SQL_Callback_ErrorCheck, "SET NAMES 'utf8'");
		g_hDatabase.Query(SQL_Callback_ErrorCheck, "SET CHARSET 'utf8'");
	}

	CreateTables();
}

void CreateTables()
{
	Transaction hTxn = new Transaction();

	if (g_bDBMySQL)
	{
		hTxn.AddQuery("CREATE TABLE IF NOT EXISTS `keys_tokens` (\
						`k_id` INT UNSIGNED NOT NULL AUTO_INCREMENT, \
						`k_name` VARCHAR(64) NOT NULL, \
						`k_type` VARCHAR(64) NOT NULL, \
						`k_expires` INT UNSIGNED NOT NULL default 0, \
						`k_uses` INT UNSIGNED NOT NULL default 1, \
						`k_sid` INT UNSIGNED NOT NULL default 0, \
						PRIMARY KEY (`k_id`), \
						UNIQUE (`k_name`)) DEFAULT CHARSET=utf8;");

		hTxn.AddQuery("CREATE TABLE IF NOT EXISTS `keys_params` (\
						`p_kid` INT UNSIGNED NOT NULL, \
						`p_num` TINYINT UNSIGNED NOT NULL, \
						`p_value` VARCHAR(64) NOT NULL) DEFAULT CHARSET=utf8;");

		hTxn.AddQuery("CREATE TABLE IF NOT EXISTS `keys_block_players` (\
						`b_auth` VARCHAR(24) NOT NULL, \
						`b_end` INT UNSIGNED NOT NULL, \
						`b_sid` INT UNSIGNED NOT NULL default 0, \
						PRIMARY KEY (`b_auth`)) DEFAULT CHARSET=utf8;");

		hTxn.AddQuery("CREATE TABLE IF NOT EXISTS `keys_players_used` (\
						`u_auth` VARCHAR(24) NOT NULL, \
						`u_kid` INT UNSIGNED NOT NULL, \
						`u_sid` INT UNSIGNED NOT NULL default 0) DEFAULT CHARSET=utf8;");
	}
	else
	{
		hTxn.AddQuery("CREATE TABLE IF NOT EXISTS `keys_tokens` (\
						`k_id` INTEGER PRIMARY KEY AUTOINCREMENT, \
						`k_name` VARCHAR(64) NOT NULL UNIQUE, \
						`k_type` VARCHAR(64) NOT NULL, \
						`k_expires` INTEGER UNSIGNED NOT NULL default 0, \
						`k_uses` INTEGER UNSIGNED NOT NULL default 1);");

		hTxn.AddQuery("CREATE TABLE IF NOT EXISTS `keys_params` (\
						`p_kid` INTEGER UNSIGNED NOT NULL, \
						`p_num` INTEGER UNSIGNED NOT NULL, \
						`p_value` VARCHAR(64) NOT NULL);");

		hTxn.AddQuery("CREATE TABLE IF NOT EXISTS `keys_block_players` (\
						`b_auth` VARCHAR(24) NOT NULL PRIMARY KEY, \
						`b_end` INTEGER UNSIGNED NOT NULL);");

		hTxn.AddQuery("CREATE TABLE IF NOT EXISTS `keys_players_used` (\
						`u_auth` VARCHAR(24) NOT NULL, \
						`u_kid` INTEGER UNSIGNED NOT NULL);");
	}

	g_hDatabase.Execute(hTxn, SQL_Callback_CreateTablesSuccess, SQL_Callback_CreateTablesFailure, 0, DBPrio_High);
}

public void SQL_Callback_CreateTablesFailure(Database hDB, any data, int iNumQueries, const char[] szError, int iFailIndex, any[] queryData)
{
	SetFailState("Не удалось создать таблицу (%d): %s", iFailIndex, szError);
}

public void SQL_Callback_CreateTablesSuccess(Database hDB, any data, int iNumQueries, DBResultSet[] hResults, any[] queryData)
{
	if(g_bDBMySQL)
	{
		g_hDatabase.SetCharset("utf8");
	}

	Notify_Started();
}

public void SQL_Callback_ErrorCheck(Database hDB, DBResultSet hResult, const char[] szError, any data)
{
	if (szError[0])
	{
		LogError("SQL_Callback_ErrorCheck: %s", szError);
	}
}

void Notify_Started()
{
	g_bIsStarted = true;

	API_CreateForward_OnCoreStarted();

	Keys_DeleteExpired();
}