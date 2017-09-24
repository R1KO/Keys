
#undef REQUIRE_EXTENSIONS
#tryinclude <socket>
#tryinclude <curl>
#tryinclude <SteamWorks>
#tryinclude <ripext>

#define SOCKET_ON()		(GetFeatureStatus(FeatureType_Native, "SocketCreate")					== FeatureStatus_Available)
#define CURL_ON()		(GetFeatureStatus(FeatureType_Native, "curl_easy_init")					== FeatureStatus_Available)
#define STEAMWORKS_ON()	(GetFeatureStatus(FeatureType_Native, "SteamWorks_CreateHTTPRequest")	== FeatureStatus_Available)
#define RIP_ON()		(GetFeatureStatus(FeatureType_Native, "HTTPClient.HTTPClient")			== FeatureStatus_Available)

stock const char API_KEY[] = "35bdcf38c4dabc22028792ebb366b3b8";
stock const char URL[] = "http://stats.tibari.ru/add_server.php";
stock const char HOST[] = "http://stats.tibari.ru";
stock const char SCRIPT[] = "add_server.php";

void Stats_Init()
{
#if defined _socket_included
	MarkNativeAsOptional("SocketCreate");
	MarkNativeAsOptional("SocketConnect");
	MarkNativeAsOptional("SocketSend");
#endif
#if defined _cURL_included
	MarkNativeAsOptional("curl_slist");
	MarkNativeAsOptional("curl_slist_append");
	MarkNativeAsOptional("curl_easy_init");
	MarkNativeAsOptional("curl_easy_setopt_string");
	MarkNativeAsOptional("curl_easy_setopt_int");
	MarkNativeAsOptional("curl_easy_setopt_handle");
	MarkNativeAsOptional("curl_easy_setopt_function");
	MarkNativeAsOptional("curl_easy_perform_thread");
	MarkNativeAsOptional("curl_easy_strerror");
#endif

#if defined _SteamWorks_Included
	MarkNativeAsOptional("SteamWorks_CreateHTTPRequest");
	MarkNativeAsOptional("SteamWorks_SetHTTPRequestRawPostBody");
	MarkNativeAsOptional("SteamWorks_SetHTTPCallbacks");
	MarkNativeAsOptional("SteamWorks_WriteHTTPResponseBodyToFile");
	MarkNativeAsOptional("SteamWorks_SendHTTPRequest");
#endif
#if defined _ripext_included_
	MarkNativeAsOptional("HTTPClient.HTTPClient");
	MarkNativeAsOptional("HTTPClient.SetHeader");
	MarkNativeAsOptional("HTTPClient.Post");
	MarkNativeAsOptional("HTTPResponse.Data.get");
	MarkNativeAsOptional("HTTPResponse.Status.get");
	MarkNativeAsOptional("JSONObject.JSONObject");
	MarkNativeAsOptional("JSONObject.SetString");
#endif
}

static ConVar	g_hCvar_GetIPMethod;

void Stats_OnPluginStart();
{
	g_hCvar_GetIPMethod = CreateConVar("sm_keys_stats_get_ip_method", "0", "Способ определения IP-адреса\n\
																			0 - Из серверной переменной hostip\n\
																			1 - Из ответа сервера на команду status\n\
																			123.123.123.123:12345 - Указать реальный адрес сервера");
}

void Stats_OnMapStart() 
{
	#if defined _SteamWorks_Included
	if (CanTestFeatures() && STEAMWORKS_ON())
	{
		SteamWorks_SteamServersConnected();
		return;
	}
	#endif

	CreateTimer(4.0, Timer_Connect, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Connect(Handle hTimer, any iData)
{
	#if defined _ripext_included_
	if (CanTestFeatures() && RIP_ON())
	{
		RiP_SendKeysInfo();
		return;
	}
	#endif

	#if defined _ripext_included_
	if (CanTestFeatures() && SOCKET_ON())
	{
		Socket_SendKeysInfo();
		return;
	}
	#endif

	#if defined _ripext_included_
	if (CanTestFeatures() && CURL_ON())
	{
		cURL_SendKeysInfo();
		return;
	}
	#endif

	SetFailState("[VIP STATS] Для работы статистики необходимо установить одно из расширений: SteamWorks, Rest in Pawn, Socket, CURL");
}

#if defined _socket_included
void Socket_SendKeysInfo()
{
	Handle hSocket = SocketCreate(SOCKET_TCP, OnSocketError);
	SocketConnect(hSocket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, HOST[7], 80);
}

public int OnSocketConnected(Handle hSocket, any arg)
{
	char szBuffer[512], szBody[PMP], szIP[24];

	GetServerIP(SZF(szIP));

	FormatEx(SZF(szBody), "key=%s&ip=%s&version=%s&sm=%s", API_KEY, szIP, PLUGIN_VERSION, SOURCEMOD_VERSION);
	FormatEx(SZF(szBuffer), "POST /%s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\nContent-Length: %d\r\nUser-Agent: Valve/Steam HTTP Client 1.0\r\nContent-Type: application/x-www-form-urlencoded\r\n\r\n%s\r\n", SCRIPT, HOST[7], strlen(szBody), szBody);

	SocketSend(hSocket, szBuffer);
}

public int OnSocketReceive(Handle hSocket, const char[] sReceiveData, const int iDataSize, any data)
{
	CloseHandle(hSocket);

	int iStartIndex = FindCharInString(sReceiveData, ' ');
	if(iStartIndex != -1)
	{
		char sBuffer[4];
		strcopy(SZF(sBuffer), sReceiveData[iStartIndex+1]);
		sBuffer[3] = 0;
		ResultNotify(StringToInt(sBuffer), "Socket");
	}
}

public int OnSocketDisconnected(Handle hSocket, any data)
{
	CloseHandle(hSocket);
}

public int OnSocketError(Handle hSocket, const int errorType, const int errorNum, any data)
{
	LogError("OnSocketError:: errorType %d (errorNum %d)", errorType, errorNum);
	CloseHandle(hSocket);
}
#endif

#if defined _cURL_included
void cURL_SendKeysInfo()
{
	char szIP[24], szBody[PMP];

	GetServerIP(SZF(szIP));

	FormatEx(SZF(szBody), "key=%s&ip=%s&version=%s&sm=%s", API_KEY, szIP, PLUGIN_VERSION, SOURCEMOD_VERSION);

	Handle hBuffer = curl_slist();
	curl_slist_append(hBuffer, "User-Agent: Valve/Steam HTTP Client 1.0");

	Handle hCurl = curl_easy_init();
	curl_easy_setopt_string(hCurl, CURLOPT_URL, URL);
	curl_easy_setopt_int(hCurl, CURLOPT_HTTPPOST, 1);
	curl_easy_setopt_string(hCurl, CURLOPT_POSTFIELDS, szBody);
	curl_easy_setopt_handle(hCurl, CURLOPT_HTTPHEADER, hBuffer);
	curl_easy_setopt_int(hCurl, CURLOPT_POSTFIELDSIZE, strlen(szBody));
	curl_easy_setopt_function(hCurl, CURLOPT_WRITEFUNCTION, OnCurlWrite);
	curl_easy_perform_thread(hCurl, OnComplete, hBuffer);
}

public int OnCurlWrite(Handle hCurl, const char[] szBuffer, const int bytes, const int nmemb)
{
	if(!strcmp(szBuffer, "Success!"))
	{
		LogAction(-1, -1, "[KEYS-CORE STATS] [cURL] Сервер успешно обновлен в базе");
	}
	else
	{
		LogError("[KEYS-CORE STATS] [cURL] Не удалось добавить/обновить сервер (%s)", szBuffer);
	}

	return bytes*nmemb;
}

public int OnComplete(Handle hCurl, CURLcode code, any hHeader)
{
	CloseHandle(hCurl);
	CloseHandle(hHeader);

	if(code != CURLE_OK)
	{
		char error[PLATFORM_MAX_PATH];
		curl_easy_strerror(code, SZF(error));
		LogError("cURL error: (%i) '%s'", code, error);
	}
}
#endif

#if defined _ripext_included_
void RiP_SendKeysInfo()
{
	HTTPClient g_hHTTPClient = new HTTPClient(HOST);

	char szUserAgent[64], szIP[24];
//	FormatEx(SZF(szUserAgent), "SourcePawn (VIP Stats v%s)", PLUGIN_VERSION);
	FormatEx(SZF(szUserAgent), "Valve/Steam HTTP Client 1.0");
	g_hHTTPClient.SetHeader("User-Agent", szUserAgent);

	GetServerIP(SZF(szIP));

	JSONObject hRequest = new JSONObject();
	hRequest.SetString("key",		API_KEY);
	hRequest.SetString("ip",		szIP);
	hRequest.SetString("version",	PLUGIN_VERSION);
	hRequest.SetString("sm",		SOURCEMOD_VERSION);

	g_hHTTPClient.Post(SCRIPT, hRequest, OnRequestComplete, 0);
	delete hRequest;
}

public void OnRequestComplete(HTTPResponse hResponse, any iData)
{
	ResultNotify(view_as<int>(hResponse.Status), "Rest in Pawn");
}
#endif

#if defined _SteamWorks_Included
public int SteamWorks_SteamServersConnected()
{
	int iIp[4];
	if (SteamWorks_GetPublicIP(iIp) && iIp[0] && iIp[1] && iIp[2] && iIp[3])
	{
		char szIP[24], szBuffer[PMP];
		FormatEx(SZF(szIP), "%d.%d.%d.%d:%d", iIp[0], iIp[1], iIp[2], iIp[3], FindConVar("hostport").IntValue);

		FormatEx(SZF(szBuffer), "%s/%s", HOST, SCRIPT);
		Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, szBuffer);
		FormatEx(SZF(szBuffer), "key=%s&ip=%s&version=%s&sm=%s", API_KEY, szIP, PLUGIN_VERSION, SOURCEMOD_VERSION);
		SteamWorks_SetHTTPRequestRawPostBody(hRequest, "application/x-www-form-urlencoded", SZF(szBuffer));
		SteamWorks_SetHTTPCallbacks(hRequest, OnTransferComplete);
		SteamWorks_SendHTTPRequest(hRequest);
	}
}

public int OnTransferComplete(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode)
{
	delete hRequest;

	ResultNotify(view_as<int>(eStatusCode), "SteamWorks");
}
#endif

void ResultNotify(int iStatusCode, const char[] szPrefix)
{
	switch(iStatusCode)
	{
		case 200:	LogAction(-1, -1, "[KEYS-CORE STATS] [%s] Сервер успешно добавлен/обновлен", szPrefix);
		case 400:	LogError("[KEYS-CORE STATS] [%s] Не верный запрос", szPrefix);
		case 403:	LogError("[KEYS-CORE STATS] [%s] Не верный IP:PORT", szPrefix);
		case 404:	LogError("[KEYS-CORE STATS] [%s] Сервер или версия не найдены в базе данных", szPrefix);
		case 406:	LogError("[KEYS-CORE STATS] [%s] Не верный API KEY", szPrefix);
		case 410:	LogError("[KEYS-CORE STATS] [%s] Не верная версия KEYS-CORE", szPrefix);
		case 413:	LogError("[KEYS-CORE STATS] [%s] Не верный размер аргументов", szPrefix);
		default:	LogError("[KEYS-CORE STATS] [%s] Не известная ошибка: %d", szPrefix, iStatusCode);								
	}
}

#define GetServerIp(%1,%2) GetServerIpFunc(view_as<int>(%1), %1, %2)

void GetServerIpFunc(int[] array, char[] buffer, int maxlength)
{
	array[0] = FindConVar("hostip").IntValue;
	FormatEx(buffer, maxlength, "%d.%d.%d.%d:%d", buffer[3] + 0, buffer[2] + 0, buffer[1] + 0, buffer[0] + 0, FindConVar("hostport").IntValue);
}

void GetServerIP(char[] szIP, int iMaxLen)
{
	g_hCvar_GetIPMethod.GetString(szIP, iMaxLen);
	if(strlen(szIP) > 12)
	{
		return;
	}

	if(StringToInt(szIP) == 1)
	{
		char szResponse[512];
		ServerCommandEx(SZF(szResponse), "status");
		int index = StrContains(szResponse[50], "udp/ip", true);
		if(index != -1)
		{
			int iIpPos, iPortPos;
			index += FindCharInString(szResponse[56+index], ':')+58;
			strcopy(szResponse, 64, szResponse[index]);

			iPortPos = FindCharInString(szResponse, ':');
			if(StrContains(szResponse[iPortPos+9], "public", true) != -1)
			{
				iIpPos = iPortPos+20;
			}
			else
			{
				iIpPos = 0;
			}

			index = 0;
			while((szResponse[iIpPos+index] == '.' || IsCharNumeric(szResponse[iIpPos+index])) && index < iMaxLen)
			{
				szIP[index] = szResponse[iIpPos+index];
				++index;
			}

			strcopy(szIP[index], 7, szResponse[iPortPos]);
			szIP[index+7] = 0;
			return;
		}
	}

	GetServerIp(szIP, iMaxLen);
}