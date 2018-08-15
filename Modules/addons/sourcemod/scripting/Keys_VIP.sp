#pragma semicolon 1

#include <sourcemod>
#include "keys_core.inc"
#include <vip_core>

public Plugin:myinfo =
{
	name	= "[Keys] VIP",
	author	= "R1KO",
	version	= "1.3",
	url		= "hlmod.ru"
};

#define EXT_STATUS		1	// Разрешить ли ключам типа vip_add продлевать VIP-статус
#define GC_STATUS		0	// Разрешить ли ключам типа vip_add изменять VIP-группу (работает только если включен EXT_STATUS)
#define CMP_VGRP		1	// Ключ типа vip_add может продлевать VIP-статус только если VIP-группа совпадает (работает только если включен EXT_STATUS)
							// Если включено - отключает GC_STATUS

#define USE_VIP_V3		0	// Для компиляции под ядро 3.0

#if CMP_VGRP == 1 && GC_STATUS == 1
#undef GC_STATUS
#define GC_STATUS		0
#endif

new const String:g_sKeyType[][] = {"vip_add", "vip_ext", "vip_gc"};

public OnPluginStart()
{
	LoadTranslations("keys_core.phrases");
	LoadTranslations("keys_vip_module.phrases");

	if (Keys_IsCoreStarted()) Keys_OnCoreStarted();
}

public OnPluginEnd()
{
	for(new i = 0; i < sizeof(g_sKeyType); ++i)
	{
		Keys_UnregKey(g_sKeyType[i]);
	}
}

public Keys_OnCoreStarted()
{
	for(new i = 0; i < sizeof(g_sKeyType); ++i)
	{
		Keys_RegKey(g_sKeyType[i], KeyCallback);
	}
}

#if USE_VIP_V3 == 0
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) 
{
	MarkNativeAsOptional("VIP_GetClientID");

	return APLRes_Success; 
}
#endif

public bool:KeyCallback(KeysAction:eKeysAction, iClient, const String:szKeyType[], Handle:hParamsArr, String:szBuffer[], iBuffLen)
{
	decl String:sParam[KEYS_MAX_LENGTH];
	switch(eKeysAction)
	{
		case Validation:
		{
			if(!strcmp(szKeyType, g_sKeyType[0]))
			{
				if(GetArraySize(hParamsArr) != 2)
				{
					FormatEx(szBuffer, iBuffLen, "%T", "ERROR_NUM_ARGS", iClient);
					return false;
				}

				GetArrayString(hParamsArr, 0, sParam, sizeof(sParam));
				if(!VIP_IsValidVIPGroup(sParam))
				{
					FormatEx(szBuffer, iBuffLen, "%T", "ERROR_INVALID_GROUP", iClient);
					return false;
				}

				GetArrayString(hParamsArr, 1, sParam, sizeof(sParam));
				new iTime = StringToInt(sParam);
				if(iTime < 0)
				{
					FormatEx(szBuffer, iBuffLen, "%T", "ERROR_INVALID_TIME", iClient);
					return false;
				}

				IntToString(VIP_TimeToSeconds(iTime), sParam, sizeof(sParam));
				SetArrayString(hParamsArr, 1, sParam);

				return true;
			}

			if(GetArraySize(hParamsArr) != 1)
			{
				FormatEx(szBuffer, iBuffLen, "%T", "ERROR_NUM_ARGS", iClient);
				return false;
			}
			
			GetArrayString(hParamsArr, 0, sParam, sizeof(sParam));

			if(!strcmp(szKeyType, g_sKeyType[1]))
			{
				new iTime = StringToInt(sParam);
				if(iTime < 0)
				{
					FormatEx(szBuffer, iBuffLen, "%T", "ERROR_INVALID_TIME", iClient);
					return false;
				}

				IntToString(VIP_TimeToSeconds(iTime), sParam, sizeof(sParam));
				SetArrayString(hParamsArr, 0, sParam);

				return true;
			}

			if(!VIP_IsValidVIPGroup(sParam))
			{
				FormatEx(szBuffer, iBuffLen, "%T", "ERROR_INVALID_GROUP", iClient);
				return false;
			}

			return true;
		}
		case Activation:
		{
			decl String:sGroup[KEYS_MAX_LENGTH];
			new iClientID = -1;
			new bool:bVip = VIP_IsClientVIP(iClient);
			if(bVip)
			{
			#if USE_VIP_V3 == 1
				iClientID = VIP_GetClientID(iClient);
			#else
				if(CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "VIP_GetClientID") == FeatureStatus_Available)
				{
					iClientID = VIP_GetClientID(iClient);
				}
				else
				{
					GetTrieValue(VIP_GetVIPClientTrie(iClient), "ClientID", iClientID);
				}
			#endif
			}

			if(!strcmp(szKeyType, g_sKeyType[0]))
			{
				GetArrayString(hParamsArr, 0, sGroup, sizeof(sGroup));
				if(!VIP_IsValidVIPGroup(sGroup))
				{
					FormatEx(szBuffer, iBuffLen, "%T", "ERROR_INVALID_GROUP", iClient);
					return false;
				}

				if(bVip)
				{
					//  && VIP_GetClientAuthType(iClient) < VIP_AuthType:3
					if(iClientID != -1)
					{
					#if EXT_STATUS == 1
						new iClientTime = VIP_GetClientAccessTime(iClient);
						if(!iClientTime)
						{
							FormatEx(szBuffer, iBuffLen, "%T", "ERROR_CAN_NOT_USE", iClient);
							return false;
						}

					#if GC_STATUS == 1 || CMP_VGRP == 1
						if(VIP_IsValidVIPGroup(sGroup))
						{
							decl String:sClientGroup[64];
							VIP_GetClientVIPGroup(iClient, sClientGroup, sizeof(sClientGroup));
							if(strcmp(sClientGroup, sGroup) != 0)
							{
								#if CMP_VGRP == 1
								FormatEx(szBuffer, iBuffLen, "%T", "ERROR_CAN_NOT_USE", iClient);
								return false;
								#elseif GC_STATUS == 1
								VIP_SetClientVIPGroup(iClient, sGroup, true);
								PrintToChat(iClient, "%t%t", "CHAT_PREFIX", "USE_KEY_GRP_CNG", sGroup);
								#endif
							}
						}
					#endif

						GetArrayString(hParamsArr, 1, sParam, sizeof(sParam));
						new iTime = StringToInt(sParam);
						if(iTime)
						{
							Keys_GetTimeFromStamp(sParam, sizeof(sParam), iTime, iClient);
							iTime += iClientTime;
						}
						else
						{
							FormatEx(sParam, sizeof(sParam), "%T", "FOREVER", iClient);
						}

						VIP_SetClientAccessTime(iClient, iTime, true);

						PrintToChat(iClient, "%t%t", "CHAT_PREFIX", "USE_KEY_EXT", sParam);

						return true;
					#else
						FormatEx(szBuffer, iBuffLen, "%T", "ERROR_VIP_ALREADY", iClient);
						return false;
					#endif
					}

					VIP_RemoveClientVIP(iClient, false, false);
				}

				decl String:sTime[64], iTime;
				GetArrayString(hParamsArr, 1, sTime, sizeof(sTime));
				iTime = StringToInt(sTime);
				#if USE_VIP_V3 == 1
				VIP_SetClientVIP(0, iClient, iTime, sParam, true);
				#else
				VIP_SetClientVIP(iClient, iTime, AUTH_STEAM, sParam, true);
				#endif
				
				if(iTime)
				{
					Keys_GetTimeFromStamp(sTime, sizeof(sTime), iTime, iClient);
				}
				else
				{
					FormatEx(sTime, sizeof(sTime), "%T", "FOREVER", iClient);
				}

				PrintToChat(iClient, "%t%t", "CHAT_PREFIX", "USE_KEY_GOT", sParam, sTime);
				return true;
			}

			if(!bVip || (bVip && iClientID == -1))
			{
				FormatEx(szBuffer, iBuffLen, "%T", "ERROR_CAN_NOT_USE", iClient);
				return false;
			}

			GetArrayString(hParamsArr, 0, sParam, sizeof(sParam));

			if(!strcmp(szKeyType, g_sKeyType[1]))
			{
				new iTime = StringToInt(sParam);
				VIP_SetClientAccessTime(iClient, iTime ? (VIP_GetClientAccessTime(iClient)+iTime):iTime, true);

				if(iTime)
				{
					Keys_GetTimeFromStamp(sParam, sizeof(sParam), iTime, iClient);
				}
				else
				{
					FormatEx(sParam, sizeof(sParam), "%T", "FOREVER", iClient);
				}

				PrintToChat(iClient, "%t%t", "CHAT_PREFIX", "USE_KEY_EXT", sParam);
				
				return true;
			}

			if(!VIP_IsValidVIPGroup(sParam))
			{
				FormatEx(szBuffer, iBuffLen, "%T", "ERROR_INVALID_GROUP", iClient);
				return false;
			}

			decl String:sClientGroup[64];
			VIP_GetClientVIPGroup(iClient, sClientGroup, sizeof(sClientGroup));
			if(!strcmp(sClientGroup, sParam))
			{
				FormatEx(szBuffer, iBuffLen, "%T", "ERROR_ALREADY_VIP_GROUP", iClient);
				return false;
			}

			VIP_SetClientVIPGroup(iClient, sParam, true);
			PrintToChat(iClient, "%t%t", "CHAT_PREFIX", "USE_KEY_GRP_CNG", sParam);

			return true;
		}
		case Print:
		{
			GetArrayString(hParamsArr, 0, sParam, sizeof(sParam));
			if(!strcmp(szKeyType, g_sKeyType[0]))
			{
				decl iTime, String:sTime[32];
				GetArrayString(hParamsArr, 1, sTime, sizeof(sTime));
				iTime = StringToInt(sTime);
				if(iTime)
				{
					Keys_GetTimeFromStamp(sTime, sizeof(sTime), iTime, iClient);
				}
				else
				{
					FormatEx(sTime, sizeof(sTime), "%T", "FOREVER", iClient);
				}
				
				FormatEx(szBuffer, iBuffLen, "%T: %s\t%T: %s", "VIP_GROUP", iClient, sParam, "TERM", iClient, sTime);

				return true;
			}

			if(!strcmp(szKeyType, g_sKeyType[1]))
			{
				decl iTime, String:sTime[32];
				iTime = StringToInt(sParam);
				if(iTime)
				{
					Keys_GetTimeFromStamp(sTime, sizeof(sTime), iTime, iClient);
				}
				else
				{
					FormatEx(sTime, sizeof(sTime), "%T", "FOREVER", iClient);
				}
				
				FormatEx(szBuffer, iBuffLen, "%T: %s", "TERM", iClient, sTime);

				return true;
			}

			FormatEx(szBuffer, iBuffLen, "%T: %s", "VIP_GROUP", iClient, sParam);

			return true;
		}
	}
	
	return false;
}