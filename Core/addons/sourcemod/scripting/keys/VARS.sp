
#define SZF(%0)           	%0, sizeof(%0)
#define SZFA(%0,%1)         %0[%1], sizeof(%0[])
#define CID(%0)             GetClientOfUserId(%0)
#define UID(%0)             GetClientUserId(%0)

#define I2S(%0,%1) 			IntToString(%0, SZF(%1))
#define S2I(%0) 			StringToInt(%0)

#define PMP                 PLATFORM_MAX_PATH
#define MNL                	MAX_NAME_LENGTH
#define MPL                 MAXPLAYERS
#define MCL                 MaxClients

char				g_sLogFile[PMP];

bool				g_bIsStarted;
Database			g_hDatabase;
bool				g_bDBMySQL;

bool				g_bIsBlocked[MPL+1];
int					g_iAttempts[MPL+1];

StringMap			g_hKeysTrie;
ArrayList			g_hKeysArray;

int					g_CVAR_iServerID;
int					g_CVAR_iKeyLength;
char				g_CVAR_sKeyTemplate[KEYS_MAX_LENGTH];
int					g_CVAR_iAttempts;
int					g_CVAR_iBlockTime;

int GET_UID(int iClient)
{
	return iClient == 0 ? 0:UID(iClient);
}

int GET_CID(int iClient)
{
	if(iClient > 0)
	{
		iClient = CID(iClient);
		if(!iClient)
		{
			return -1;
		}

		return iClient;
	}
	
	return iClient;
}