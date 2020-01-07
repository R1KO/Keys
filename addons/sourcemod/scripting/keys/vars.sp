
#define UID(%0) 	GetClientUserId(%0)
#define CID(%0) 	GetClientOfUserId(%0)
#define SZF(%0) 	%0, sizeof(%0)

#define DP_Plugin						0
#define DP_OnValidateCallback		9
#define DP_OnUseCallback			18
#define DP_OnPrintCallback			27

new String:g_sLogFile[256];

new bool:g_bIsStarted;
new Handle:g_hDatabase,
	bool:g_bDBMySQL;

new bool:g_bIsBlocked[MAXPLAYERS+1],
	g_iAttempts[MAXPLAYERS+1];

new Handle:g_hKeysTrie;
new Handle:g_hKeysArray;

new g_iServerID = -1;

new g_CVAR_iServerID;
new g_CVAR_iKeyLength;
new String:g_CVAR_sKeyTemplate[64];
new g_CVAR_iAttempts;
new g_CVAR_iBlockTime;

new Handle:g_hKeysInProcessing;
