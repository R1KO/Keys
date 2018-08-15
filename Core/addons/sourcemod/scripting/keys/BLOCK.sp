
void Block_ClientDisconnect(int iClient)
{
	g_iAttempts[iClient] = 0;
	g_bIsBlocked[iClient] = false;
}

void Block_ClientConnect(int iClient)
{
	char szQuery[PMP], szAuth[32], szSID[64];
	GetClientAuthId(iClient, AuthId_Engine, SZF(szAuth));

	if(!g_CVAR_iServerID)
	{
		szSID[0] = 0;
	}
	else
	{
		FormatEx(SZF(szSID), " AND `b_sid` = %d", g_CVAR_iServerID);
	}
	
	FormatEx(SZF(szQuery), "SELECT `b_end` FROM `keys_block_players` WHERE `b_auth` = '%s'%s;", szAuth, szSID);

	g_hDatabase.Query(SQL_Callback_SearchBlockPlayer, szQuery, UID(iClient));
}

public void SQL_Callback_SearchBlockPlayer(Database hDB, DBResultSet hResult, const char[] szDbError, any UserID)
{
	if (hResult == null || szDbError[0])
	{
		LogError("SQL_Callback_SearchBlockPlayer: %s", szDbError);
		return;
	}

	int iClient = CID(UserID);
	if (iClient)
	{
		if(hResult.FetchRow())
		{
			g_iAttempts[iClient] = hResult.FetchInt(0);
			if(g_iAttempts[iClient] && g_iAttempts[iClient] < GetTime())
			{
				Block_SetClientStatus(iClient, false);
				return;
			}
			
			g_bIsBlocked[iClient] = true;
		}
	}
}

void Block_SetClientStatus(int iClient, bool bStatus)
{
	char szQuery[PMP], szAuth[32], szBuffer[64];
	GetClientAuthId(iClient, AuthId_Engine, SZF(szAuth));
	g_bIsBlocked[iClient] = bStatus;
	if(bStatus)
	{
		g_iAttempts[iClient] = GetTime()+(g_CVAR_iBlockTime*60);
		GetClientName(iClient, SZF(szBuffer));

		LogToFile(g_sLogFile, "%T", "LOG_BLOCKED", LANG_SERVER, szBuffer, szAuth);

		if(!g_CVAR_iServerID)
		{
			FormatEx(SZF(szQuery), "INSERT INTO `keys_block_players` (`b_auth`, `b_end`) VALUES ('%s', %d);", szAuth, g_iAttempts[iClient]);
		}
		else
		{
			FormatEx(SZF(szQuery), "INSERT INTO `keys_block_players` (`b_auth`, `b_end`, `b_sid`) VALUES ('%s', %d, %d);", szAuth, g_iAttempts[iClient], g_CVAR_iServerID);
		}
	}
	else
	{
		g_iAttempts[iClient] = 0;

		if(!g_CVAR_iServerID)
		{
			szBuffer[0] = 0;
		}
		else
		{
			FormatEx(SZF(szBuffer), " AND `b_sid` = %d", g_CVAR_iServerID);
		}

		FormatEx(SZF(szQuery), "DELETE FROM `keys_block_players` WHERE `b_auth` = '%s'%s;", szAuth, szBuffer);
	}

	g_hDatabase.Query(SQL_Callback_ErrorCheck, szQuery);
}