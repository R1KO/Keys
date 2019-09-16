#pragma semicolon 1

#include <sourcemod>
#include <keys_core>
#include <shop>

public Plugin:myinfo =
{
	name		= "[Keys] Shop",
	author	= "R1KO",
	version	= "1.1",
	url		= "hlmod.ru"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) 
{
	MarkNativeAsOptional("Shop_GiveClientItem");
	MarkNativeAsOptional("Shop_GiveClientGold");

	return APLRes_Success; 
}

new const String:g_sKeyType[][] = {"shop_credits", "shop_item", "shop_gold"};

public OnPluginStart()
{
	LoadTranslations("keys_core.phrases");
	LoadTranslations("keys_shop_module.phrases");
	
	if (Keys_IsCoreStarted()) Keys_OnCoreStarted();
}

public OnPluginEnd()
{
	Keys_UnregKey(g_sKeyType[0]);
	Keys_UnregKey(g_sKeyType[1]);
	Keys_UnregKey(g_sKeyType[2]);
}

public Keys_OnCoreStarted()
{
	Keys_RegKey(g_sKeyType[0], OnKeyParamsValidate, OnKeyUse, OnKeyPrint);
	Keys_RegKey(g_sKeyType[1], OnKeyParamsValidate, OnKeyUse, OnKeyPrint);
	Keys_RegKey(g_sKeyType[2], OnKeyParamsValidate, OnKeyUse, OnKeyPrint);
}

public bool:OnKeyParamsValidate(iClient, const String:sKeyType[], Handle:hParamsArr, String:sError[], iErrLen)
{
	decl String:sParam[KEYS_MAX_LENGTH];
	if(!strcmp(sKeyType, g_sKeyType[0]))
	{
		if(GetArraySize(hParamsArr) != 1)
		{
			FormatEx(sError, iErrLen, "%T", "ERROR_NUM_ARGS", iClient);
			return false;
		}

		GetArrayString(hParamsArr, 0, sParam, sizeof(sParam));
		if(StringToInt(sParam) < 1)
		{
			FormatEx(sError, iErrLen, "%T", "ERROR_INVALID_CREDITS", iClient);
			return false;
		}

		return true;
	}
	if (!strcmp(sKeyType, g_sKeyType[2]))
	{
		if(GetArraySize(hParamsArr) != 1)
		{
			FormatEx(sError, iErrLen, "%T", "ERROR_NUM_ARGS", iClient);
			return false;
		}

		GetArrayString(hParamsArr, 0, sParam, sizeof(sParam));
		if(StringToInt(sParam) < 1)
		{
			FormatEx(sError, iErrLen, "%T", "ERROR_INVALID_GOLD", iClient);
			return false;
		}

		return true;
	}

	new iSize = GetArraySize(hParamsArr);
	if(!iSize)
	{
		FormatEx(sError, iErrLen, "%T", "ERROR_NUM_ARGS", iClient);
		return false;
	}

	GetArrayString(hParamsArr, 0, sParam, sizeof(sParam));
	
	new CategoryId:iCatID = Shop_GetCategoryId(sParam);
	if(iCatID == INVALID_CATEGORY)
	{
		FormatEx(sError, iErrLen, "%T", "ERROR_INVALID_CATEGORY", iClient);
		return false;
	}

	if(iSize > 1)
	{
		GetArrayString(hParamsArr, 1, sParam, sizeof(sParam));
		new ItemId:iItemID = Shop_GetItemId(iCatID, sParam);
		if(iItemID == INVALID_ITEM)
		{
			FormatEx(sError, iErrLen, "%T", "ERROR_INVALID_ITEM", iClient);
			return false;
		}
	}

	return true;
}

GiveClientItem(iClient, ItemId:iItemID)
{
	if(CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "Shop_GiveClientItem") == FeatureStatus_Available)
	{
		Shop_GiveClientItem(iClient, iItemID);
		Shop_SetClientItemTimeleft(iClient, iItemID, Shop_GetItemValue(iItemID));
	}
	else
	{
		new iPrice = Shop_GetItemPrice(iItemID);
		Shop_GiveClientCredits(iClient, iPrice, IGNORE_FORWARD_HOOK);
		Shop_BuyClientItem(iClient, iItemID);
	}
}

public bool:OnKeyUse(iClient, const String:sKeyType[], Handle:hParamsArr, String:sError[], iErrLen)
{
	decl String:sParam[KEYS_MAX_LENGTH];
	GetArrayString(hParamsArr, 0, sParam, sizeof(sParam));
	if(!strcmp(sKeyType, g_sKeyType[0]))
	{
		Shop_GiveClientCredits(iClient, StringToInt(sParam), IGNORE_FORWARD_HOOK);
		PrintToChat(iClient, "%t%t", "CHAT_PREFIX", "YOU_RECEIVED_CREDITS", StringToInt(sParam));
		return true;
	}
	else if(!strcmp(sKeyType, g_sKeyType[2]))
	{
		Shop_GiveClientGold(iClient, StringToInt(sParam), IGNORE_FORWARD_HOOK);
		PrintToChat(iClient, "%t%t", "CHAT_PREFIX", "YOU_RECEIVED_GOLD", StringToInt(sParam));
		return true;
	}

	new CategoryId:iCatID = Shop_GetCategoryId(sParam);
	if(iCatID == INVALID_CATEGORY)
	{
		FormatEx(sError, iErrLen, "%T", "ERROR_INVALID_CATEGORY", iClient);
		return false;
	}

	if(GetArraySize(hParamsArr) > 1)
	{
		decl String:sItem[SHOP_MAX_STRING_LENGTH];
		GetArrayString(hParamsArr, 1, sItem, sizeof(sItem));
		new ItemId:iItemID = Shop_GetItemId(iCatID, sItem);
		if(iItemID < ItemId:1) // if(iItemID == INVALID_ITEM)
		{
			FormatEx(sError, iErrLen, "%T", "ERROR_INVALID_ITEM", iClient);
			return false;
		}

		switch(Shop_GetItemType(iItemID))
		{
			case Item_Finite, Item_BuyOnly:
			{
				GiveClientItem(iClient, iItemID);
			}
			case Item_Togglable:
			{
				if(Shop_IsClientHasItem(iClient, iItemID))
				{
					Shop_SetClientItemTimeleft(iClient, iItemID, Shop_GetClientItemTimeleft(iClient, iItemID)+Shop_GetItemValue(iItemID));
				}
				else
				{
					GiveClientItem(iClient, iItemID);
				}
			}
		}
		PrintToChat(iClient, "%t%t", "CHAT_PREFIX", "YOU_RECEIVED_ITEM_FROM_CATEGORY", sItem, sParam);

		return true;
	}

	decl ItemId:iItemID, i, iSize, Handle:hArray;
	hArray = Shop_CreateArrayOfItems(iSize);
	for (i = 0; i < iSize; ++i)
	{
		iItemID = Shop_GetArrayItem(view_as<ArrayList>(hArray), i);
		if(Shop_GetItemCategoryId(iItemID) == iCatID)
		{
			switch(Shop_GetItemType(iItemID))
			{
				case Item_Finite, Item_BuyOnly:
				{
					GiveClientItem(iClient, iItemID);
				}
				case Item_Togglable:
				{
					if(Shop_IsClientHasItem(iClient, iItemID))
					{
						Shop_SetClientItemTimeleft(iClient, iItemID, Shop_GetClientItemTimeleft(iClient, iItemID)+Shop_GetItemValue(iItemID));
					}
					else
					{
						GiveClientItem(iClient, iItemID);
					}
				}
			}
		}
	}
	PrintToChat(iClient, "%t%t", "CHAT_PREFIX", "YOU_RECEIVED_ALL_ITEMS_FROM_CATEGORY", sParam);

	return true;
}

public OnKeyPrint(iClient, const String:sKeyType[], Handle:hParamsArr, String:sBuffer[], iBufLen)
{
	decl String:sParam[KEYS_MAX_LENGTH];
	GetArrayString(hParamsArr, 0, sParam, sizeof(sParam));
	if(!strcmp(sKeyType, g_sKeyType[0]))
	{
		FormatEx(sBuffer, iBufLen, "%T: %s", "CREDITS", iClient, sParam);
		return;
	}
	if(!strcmp(sKeyType, g_sKeyType[2]))
	{
		FormatEx(sBuffer, iBufLen, "%T: %s", "GOLD", iClient, sParam);
		return;
	}

	FormatEx(sBuffer, iBufLen, "%T: %s", "CATEGORY", iClient, sParam);
	
	if(GetArraySize(hParamsArr) > 1)
	{
		GetArrayString(hParamsArr, 1, sParam, sizeof(sParam));
		Format(sBuffer, iBufLen, "%s, %T: %s", sBuffer, "ITEM", iClient, sParam);
	}
	else
	{
		Format(sBuffer, iBufLen, "%s, %T: %T", sBuffer, "ITEM", iClient, "ALL", iClient);
	}
}
