#if defined _levelsranks_included_
  #endinput
#endif
#define _levelsranks_included_

#define PLUGIN_VERSION "v2.3.0"

#define ST_VALUE 0
#define ST_RANK 1
#define ST_KILLS 2
#define ST_DEATHS 3
#define ST_SHOOTS 4
#define ST_HITS 5
#define ST_HEADSHOTS 6
#define ST_ASSISTS 7

int		g_iColorsOther[] = {0xFFFFFF, 0xFF0000, 0x00AD00, 0x00FF00, 0x99FF99, 0xFF4040, 0xCCCCCC, 0xFFBD6B, 0xFA8B00, 0x99CCFF, 0x3D46FF, 0xFA00FA};
char		g_sColors[][] = {"{WHITE}", "{RED}", "{GREEN}", "{LIME}", "{LIGHTGREEN}", "{LIGHTRED}", "{GRAY}", "{LIGHTOLIVE}", "{OLIVE}", "{LIGHTBLUE}", "{BLUE}", "{PURPLE}"};
char		g_sColorsCSGO[][] = {"\x01", "\x02", "\x04", "\x05", "\x06", "\x07", "\x08", "\x09", "\x10", "\x0B", "\x0C", "\x0E"};

/**
 * Checks if enough players are in this round to activate statistics
 * 
 * @return bool	-	if true - yes, otherwise - no
 */
native bool LR_CheckCountPlayers();

/**
 * Returns ID of statistics type
 * 
 * @return int		-	ID of stastics type
 */
native int LR_GetTypeStatistics();

/**
 * Gets the client's place in the TOP
 * 
 * @param iClient	-	Client index
 * @return int		-	Client position in TOP
 */
native int LR_GetClientPos(int iClient);

/**
 * Получает подробную статистику об игроке
 * 
 * @param iClient	-	Client index
 * @param iStats		ID получаемых данных (Example: iStats = ST_VALUE).
 * @return int			Значение выбранных данных
 */
native int LR_GetClientInfo(int iClient, int iStats);

/**
 * Изменяет кол-во расчетных единиц у игрока
 * 
 * @param iClient		Индекс клиента.
 * @param iAmount	Кол-во расчетных единиц (очки опыта/счетчик времени)
 * @return int			Новое значение кол-ва расчетных единиц.
 */
native int LR_ChangeClientValue(int iClient, int iAmount);

/**
 * Принудительно выставляет очки опыта клиенту (only for lr_type_statistics 2)
 * 
 * @param iClient		Индекс клиента.
 * @param iAmount	Кол-во очков опыта
 * @return bool		Если true - выдача прошла успешно, иначе false.
 */
native bool LR_SetClientValue(int iClient, int iAmount);

/**
 * Вызывает меню инвентаря (используется модулями для возможности откатиться назад по Менюшке)
 * 
 * @param iClient		Индекс клиента.
 * @noreturn
 */
native void LR_MenuInventory(int iClient);

/**
 * Проверяет на валидность VIP-группу
 * 
 * @param sGroup		Проверяемое название VIP-группы
 * @return bool		Если true - VIP-группа валидна, иначе false.
 */
native bool LR_IsValidGroupVIP(const char[] sGroup);

/**
 * Проверяет VIP-статус клиента
 * 
 * @param iClient		Индекс клиента.
 * @return bool		Если true - клиент имеет статус VIP, иначе false.
 */
native bool LR_IsClientVIP(int iClient);

/**
 * Выдает VIP-статус клиенту
 * 
 * @param iClient		Индекс клиента.
 * @param iTime		Время в Unix TimeStamp, до которого у клиента будет VIP-статус.
 * @param sGroup		Наименование присуждаемой группы
 * @return bool		Если true - VIP выдан, иначе false.
 */
native bool LR_SetClientVIP(int iClient, int iTime, const char[] sGroup);

/**
 * Возвращает информацию о VIP-статусе клиента
 * 
 * @param iClient		Индекс клиента.
 * @return DataPack	Если Валидный (1 - время окончания VIP-статуса, 2 - наименование VIP-группы)
 */
native DataPack LR_GetClientInfoVIP(int iClient);

/**
 * Изменяет параметры VIP-статуса клиента
 * 
 * @param iClient		Индекс клиента.
 * @param sGroup		Наименование группы , на которую вы хотите сменить (если пустое название - группа не меняется)
 * @param iTime		Время в UnixTime до которого будет VIP-статус (-1 - не изменять, 0 - навсегда)
 * @return bool		Если true - VIP изменен, иначе false.
 */
native bool LR_ChangeClientVIP(int iClient, const char[] sGroup = "", int iTime = -1);

/**
 * Удаляет VIP-статус клиента
 * 
 * @param iClient		Индекс клиента.
 * @return bool		Если true - VIP удален, иначе false.
 */
native bool LR_DeleteClientVIP(int iClient);

/**
 * Called when a list opens Inventory
 * 
 * @noreturn
 */
forward void LR_OnMenuCreated(int iClient, int iRank, Menu& hMenu);

/**
 * Called when a list opens Inventory
 * 
 * @noreturn
 */
forward void LR_OnMenuItemSelected(int iClient, int iRank, const char[] sInfo);

/**
 * Вызывается при изменении уровня игроком
 *
 * @param iClient		ID игрока
 * @param iNewLevel	Новый уровень
 * @param bUp		Если true - то уровень поднялся, false - упал.
 */
forward void LR_OnLevelChanged(int iClient, int iNewLevel, bool bUp);

stock bool IsValidClient(int iClient)
{
	return (1 <= iClient <= MaxClients && IsClientInGame(iClient)) ? true : false;
}

stock void LR_PrintToChat(int iClient, char[] szMessage, any ...)
{
	if(IsValidClient(iClient) && !IsFakeClient(iClient))
	{
		SetGlobalTransTarget(iClient);
		char szBuffer[PLATFORM_MAX_PATH], szNewMessage[PLATFORM_MAX_PATH];

		switch(GetEngineVersion())
		{
			case Engine_CSGO:
			{
				Format(szBuffer, sizeof(szBuffer), " \x01%s", szMessage);
				VFormat(szNewMessage, sizeof(szNewMessage), szBuffer, 3);

				for(int i = 0; i < 12; i++)
				{
					ReplaceString(szNewMessage, sizeof(szNewMessage), g_sColors[i], g_sColorsCSGO[i]);
				}
				ReplaceString(szNewMessage, sizeof(szNewMessage), "{TEAM}", "\x03");
			}

			case Engine_CSS, Engine_TF2:
			{
				char sBuff[64];
				Format(szBuffer, sizeof(szBuffer), "\x01%s", szMessage);
				VFormat(szNewMessage, sizeof(szNewMessage), szBuffer, 3);

				switch(GetClientTeam(iClient))
				{
					case 1: Format(sBuff, sizeof(sBuff), "\x07%06X", g_iColorsOther[6]);
					case 2: Format(sBuff, sizeof(sBuff), "\x07%06X", g_iColorsOther[5]);
					case 3: Format(sBuff, sizeof(sBuff), "\x07%06X", g_iColorsOther[9]);
				}
				ReplaceString(szNewMessage, sizeof(szNewMessage), "{TEAM}", sBuff);

				for(int i = 0; i < 12; i++)
				{
					Format(sBuff, sizeof(sBuff), "\x07%06X", g_iColorsOther[i]);
					ReplaceString(szNewMessage, sizeof(szNewMessage), g_sColors[i], sBuff);
				}
			}
		}

		Handle hBf = StartMessageOne("SayText2", iClient, USERMSG_RELIABLE | USERMSG_BLOCKHOOKS);
		if(hBf != null)
		{
			if(GetUserMessageType() == UM_Protobuf)
			{
				Protobuf hProtoBuffer = UserMessageToProtobuf(hBf);
				hProtoBuffer.SetInt("ent_idx", iClient);
				hProtoBuffer.SetBool("chat", true);
				hProtoBuffer.SetString("msg_name", szNewMessage);
				hProtoBuffer.AddString("params", "");
				hProtoBuffer.AddString("params", "");
				hProtoBuffer.AddString("params", "");
				hProtoBuffer.AddString("params", "");
			}
			else
			{
				BfWrite hBfBuffer = UserMessageToBfWrite(hBf);
				hBfBuffer.WriteByte(iClient);
				hBfBuffer.WriteByte(true);
				hBfBuffer.WriteString(szNewMessage);
			}
		}
		EndMessage();
	}
}

public SharedPlugin __pl_levelsranks = 
{
	name = "levelsranks",
	file = "levelsranks.smx",

	#if defined REQUIRE_PLUGIN
		required = 1,
	#else
		required = 0,
	#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_levelsranks_SetNTVOptional()
{
	MarkNativeAsOptional("LR_CheckCountPlayers");
	MarkNativeAsOptional("LR_GetTypeStatistics");
	MarkNativeAsOptional("LR_GetClientPos");
	MarkNativeAsOptional("LR_GetClientInfo");
	MarkNativeAsOptional("LR_ChangeClientValue");
	MarkNativeAsOptional("LR_SetClientValue");
	MarkNativeAsOptional("LR_MenuInventory");
	MarkNativeAsOptional("LR_IsValidGroupVIP");
	MarkNativeAsOptional("LR_IsClientVIP");
	MarkNativeAsOptional("LR_SetClientVIP");
	MarkNativeAsOptional("LR_GetClientInfoVIP");
	MarkNativeAsOptional("LR_ChangeClientVIP");
	MarkNativeAsOptional("LR_DeleteClientVIP");
}
#endif