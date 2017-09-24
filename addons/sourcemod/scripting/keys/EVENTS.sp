
public void OnMapStart() 
{
//	Stats_OnMapStart();
}

public void OnConfigsExecuted()
{
	if(g_bIsStarted)
	{
		Keys_DeleteExpired();
	}
}

public Action OnClientSayCommand(int iClient, const char[] sCommand, const char[] sArgs)
{
	if(StrContains(sArgs, "key") != -1)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void OnClientDisconnect(int iClient)
{
	Block_ClientDisconnect(iClient);
}

public void OnClientPostAdminCheck(int iClient)
{
	if(!IsFakeClient(iClient))
	{
		Block_ClientConnect(iClient);
	}
}