#pragma newdecls required
#pragma semicolon 1

#include <keys_core>
#include <vip_core>

public Plugin myinfo = {
	name	= "[Keys] VIP",
	author	= "R1KO & T1MOX4",
	version	= "1.4",
	url		= "hlmod.ru"
};

#define EXT_STATUS		1	// Разрешить ли ключам типа vip_add продлевать VIP-статус
#define GC_STATUS		0	// Разрешить ли ключам типа vip_add изменять VIP-группу (работает только если включен EXT_STATUS)
#define CMP_VGRP		1	// Ключ типа vip_add может продлевать VIP-статус только если VIP-группа совпадает (работает только если включен EXT_STATUS)
							// Если включено - отключает GC_STATUS

#if CMP_VGRP == 1 && GC_STATUS == 1
#undef GC_STATUS
#define GC_STATUS		0
#endif

static const char g_sKeyType[][] = {"vip_add", "vip_ext", "vip_gc"};

public void OnPluginStart() {
	LoadTranslations("keys_core.phrases");
	LoadTranslations("keys_vip_module.phrases");

	if (Keys_IsCoreStarted()) Keys_OnCoreStarted();
}

public void OnPluginEnd() {
	for(int i; i < sizeof(g_sKeyType); ++i) {
		Keys_UnregKey(g_sKeyType[i]);
	}
}

public void Keys_OnCoreStarted() {
	for(int i; i < sizeof(g_sKeyType); ++i) {
		Keys_RegKey(g_sKeyType[i], KeyCallback);
	}
}

public bool KeyCallback(KeysAction eKeysAction, int iClient, const char[] szKeyType, ArrayList hParamsArr, char[] szBuffer, int iBuffLen) {
	char sGroup[KEYS_MAX_LENGTH];
	switch(eKeysAction) {
		case Validation: {
			if (!strcmp(szKeyType, g_sKeyType[0])) {
				if (hParamsArr.Length != 2) {
					FormatEx(szBuffer, iBuffLen, "%T", "ERROR_NUM_ARGS", iClient);
					return false;
				}

				hParamsArr.GetString(0, sGroup, sizeof(sGroup));
				
				if (!VIP_IsValidVIPGroup(sGroup)) {
					FormatEx(szBuffer, iBuffLen, "%T", "ERROR_INVALID_GROUP", iClient);
					return false;
				}

				hParamsArr.GetString(1, sGroup, sizeof(sGroup));
				int iTime = StringToInt(sGroup);
				
				if (iTime < 0) {
					FormatEx(szBuffer, iBuffLen, "%T", "ERROR_INVALID_TIME", iClient);
					return false;
				}

				IntToString(VIP_TimeToSeconds(iTime), sGroup, sizeof(sGroup));
				hParamsArr.SetString(1, sGroup);

				return true;
			}

			if (hParamsArr.Length != 1) {
				FormatEx(szBuffer, iBuffLen, "%T", "ERROR_NUM_ARGS", iClient);
				return false;
			}
			
			hParamsArr.GetString(0, sGroup, sizeof(sGroup));

			if (!strcmp(szKeyType, g_sKeyType[1])) {
				int iTime = StringToInt(sGroup);
				
				if (iTime < 0) {
					FormatEx(szBuffer, iBuffLen, "%T", "ERROR_INVALID_TIME", iClient);
					return false;
				}

				IntToString(VIP_TimeToSeconds(iTime), sGroup, sizeof(sGroup));
				hParamsArr.SetString(0, sGroup);

				return true;
			}

			if (!VIP_IsValidVIPGroup(sGroup)) {
				FormatEx(szBuffer, iBuffLen, "%T", "ERROR_INVALID_GROUP", iClient);
				return false;
			}

			return true;
		}
		
		case Activation: {
			int iClientID = -1;
			bool bVip = VIP_IsClientVIP(iClient);
			
			if (bVip) {
				iClientID = VIP_GetClientID(iClient);
			}

			if (!strcmp(szKeyType, g_sKeyType[0])) {
				hParamsArr.GetString(0, sGroup, sizeof(sGroup));
				
				if (!VIP_IsValidVIPGroup(sGroup)) {
					FormatEx(szBuffer, iBuffLen, "%T", "ERROR_INVALID_GROUP", iClient);
					return false;
				}

				if (bVip) {
					//  && VIP_GetClientAuthType(iClient) < VIP_AuthType:3
					if (iClientID != -1) {
					#if EXT_STATUS == 1
						int iClientTime = VIP_GetClientAccessTime(iClient);
						if (!iClientTime) {
							FormatEx(szBuffer, iBuffLen, "%T", "ERROR_CAN_NOT_USE", iClient);
							return false;
						}

					#if GC_STATUS == 1 || CMP_VGRP == 1
						if (VIP_IsValidVIPGroup(sGroup)) {
							char sClientGroup[64];
							VIP_GetClientVIPGroup(iClient, sClientGroup, sizeof(sClientGroup));
							
							if (strcmp(sClientGroup, sGroup)) {
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

						hParamsArr.GetString(1, sGroup, sizeof(sGroup));
						int iTime = StringToInt(sGroup);
						
						if (iTime) {
							Keys_GetTimeFromStamp(sGroup, sizeof(sGroup), iTime, iClient);
							iTime += iClientTime;
						} else {
							FormatEx(sGroup, sizeof(sGroup), "%T", "FOREVER", iClient);
						}

						VIP_SetClientAccessTime(iClient, iTime, true);

						PrintToChat(iClient, "%t%t", "CHAT_PREFIX", "USE_KEY_EXT", sGroup);

						return true;
					#else
						FormatEx(szBuffer, iBuffLen, "%T", "ERROR_VIP_ALREADY", iClient);
						return false;
					#endif
					}

					VIP_RemoveClientVIP2(-1, iClient, false, false);
				}

				char sTime[64];
				hParamsArr.GetString(1, sTime, sizeof(sTime));
				int iTime = StringToInt(sTime);
				VIP_GiveClientVIP(-1, iClient, iTime, sGroup, true);
				
				if (iTime) {
					Keys_GetTimeFromStamp(sTime, sizeof(sTime), iTime, iClient);
				} else {
					FormatEx(sTime, sizeof(sTime), "%T", "FOREVER", iClient);
				}

				PrintToChat(iClient, "%t%t", "CHAT_PREFIX", "USE_KEY_GOT", sGroup, sTime);
				return true;
			}

			if (!bVip || (bVip && iClientID == -1)) {
				FormatEx(szBuffer, iBuffLen, "%T", "ERROR_CAN_NOT_USE", iClient);
				return false;
			}

			hParamsArr.GetString(0, sGroup, sizeof(sGroup));

			if (!strcmp(szKeyType, g_sKeyType[1])) {
				int iTime = StringToInt(sGroup);
				VIP_SetClientAccessTime(iClient, iTime ? (VIP_GetClientAccessTime(iClient)+iTime):iTime, true);

				if (iTime) {
					Keys_GetTimeFromStamp(sGroup, sizeof(sGroup), iTime, iClient);
				} else {
					FormatEx(sGroup, sizeof(sGroup), "%T", "FOREVER", iClient);
				}

				PrintToChat(iClient, "%t%t", "CHAT_PREFIX", "USE_KEY_EXT", sGroup);
				
				return true;
			}

			if (!VIP_IsValidVIPGroup(sGroup)) {
				FormatEx(szBuffer, iBuffLen, "%T", "ERROR_INVALID_GROUP", iClient);
				return false;
			}

			char sClientGroup[64];
			VIP_GetClientVIPGroup(iClient, sClientGroup, sizeof(sClientGroup));
			
			if (!strcmp(sClientGroup, sGroup)) {
				FormatEx(szBuffer, iBuffLen, "%T", "ERROR_ALREADY_VIP_GROUP", iClient);
				return false;
			}

			VIP_SetClientVIPGroup(iClient, sGroup, true);
			PrintToChat(iClient, "%t%t", "CHAT_PREFIX", "USE_KEY_GRP_CNG", sGroup);

			return true;
		}
		
		case Print: {
			hParamsArr.GetString(0, sGroup, sizeof(sGroup));
			
			if (!strcmp(szKeyType, g_sKeyType[0])) {
				char sTime[64];
				hParamsArr.GetString(1, sTime, sizeof(sTime));
				int iTime = StringToInt(sTime);
				
				if (iTime) {
					Keys_GetTimeFromStamp(sTime, sizeof(sTime), iTime, iClient);
				} else {
					FormatEx(sTime, sizeof(sTime), "%T", "FOREVER", iClient);
				}
				
				FormatEx(szBuffer, iBuffLen, "%T: %s\t%T: %s", "VIP_GROUP", iClient, sGroup, "TERM", iClient, sTime);

				return true;
			}

			if (!strcmp(szKeyType, g_sKeyType[1])) {
				char sTime[64];
				int iTime = StringToInt(sGroup);
				
				if (iTime) {
					Keys_GetTimeFromStamp(sTime, sizeof(sTime), iTime, iClient);
				} else {
					FormatEx(sTime, sizeof(sTime), "%T", "FOREVER", iClient);
				}
				
				FormatEx(szBuffer, iBuffLen, "%T: %s", "TERM", iClient, sTime);

				return true;
			}

			FormatEx(szBuffer, iBuffLen, "%T: %s", "VIP_GROUP", iClient, sGroup);

			return true;
		}
	}
	
	return false;
}
