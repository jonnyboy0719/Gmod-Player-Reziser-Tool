--Set this to false and player scales will be stored to the database but not loaded anymore (defaults to 1.0)
DisableScaleLoading = false


--Script begin

if SERVER then
	AddCSLuaFile( "resizer_main.lua" )
end

--Default data for players
--accessible server and client side
Sizing = { }	
Sizing.Default = {
			StandingHull 	= {
					Minimum = Vector( -16, -16, 00 ),
					Maximum = Vector(  16,  16, 72 ),
				},
			DuckingHull 	= {
					Minimum = Vector( -16, -16, 00 ),
					Maximum = Vector(  16,  16, 36 ),
				},
			JumpPower 	= 160,
			StepSize 	= 18,
			
			--MaxRunSpeed = 1500,
			--MaxWalkSpeed= 1500,
			MaxStepSize = 500,
			MaxHullScale = 3,
			
			RunSpeed 	= 500,
			WalkSpeed 	= 250,
			Scale 		= Vector( ),
			ViewOffset 	= Vector( 0, 0, 64 ),
			ViewOffsetDuck 	= Vector( 0, 0, 28 ),
			--AdjustToHeight	= true,
		}
		
--lower the eye height for certain models which are smaller than regular human player models
EyeAdjustments = {
		["models/characters/sh/tails.mdl"] = 0.45,
		["models/characters/sh/rouge.mdl"] = 0.6,
		["models/characters/sh/knuckles.mdl"] = 0.63,
		["models/characters/sh/knuckles.mdl"] = 0.6,
		["models/characters/sh/shadow.mdl"] = 0.6,
		["models/characters/sh/sonic.mdl"] = 0.6,
		["models/characters/sh/supershadow.mdl"] = 0.6,
		["models/characters/sh/rouge_sa2.mdl"] = 0.6,
		["models/characters/sh/amy.mdl"] = 0.6,
		["models/player/headcrab.mdl"] = 0.6


	}


--server side functions
if SERVER then

	--Main function - adjusts the player height of player v
	local function AdjustSc(v)
		local scale, adjust
		local md = v:GetModel()
		
		--detect the model eye height
		psc = 1.0 --psc = player scale
		if (EyeAdjustments[md]) then
			psc=EyeAdjustments[md]
		end
		
		--each client has the ability to also set his personal eye scale - he can lower or raise his eye height
		local eyeheight = v:GetInfo("resize_eyeoffset");

		if eyeheight and tonumber(eyeheight) then
			local eyescale = tonumber(eyeheight)
			if(eyescale < 0) then
				eyescale = 0
			end;
			psc = psc * eyescale;
		end
		
		--[[this variable decides whether to send adjustment commands for that player 
		   (several adjustment commands slow down the server thus they are only called 
		    when needed)]]--
		adjust = false
		
		--[[v.Progress is a variable for each player describing if a player is currently
		   growing or shrinking - if it is -1 then no process is running]]--		
		if v.Progress!=-1  then
			adjust = true --in case a progress running adjust is always enabled
			local add = FrameTime()*100;
			v.Progress = v.Progress + add; --progress is going on
			if (v.Progress >= v.EndProgress) then --progress completed
				v.Scale = v.TargetScale           --set player scale to target scale
				v.Progress = -1;				  --process completed
			else
				if v.ExponentialScaling then
				--depending on mathematical scaling way do the correct scale calculation
					v.Scale = v.SourceScale * (1/2)^(v.Progress*v.ScaleSpeed)
				else
					v.Scale = v.SourceScale + v.Progress * v.ScaleSpeed
				end
			end
			--store the player scale to a network float so that clients can read it
			v:SetNetworkedFloat("PlScale",v.Scale);
		end
	
		--incase the psc value changed set adjust to true
		if not v.OldPsc then
			adjust=true
		elseif psc!=v.OldPsc then
			adjust=true
		end
	
		--store psc value
		v.OldPsc=psc
				
		--set local variable
		scale = v.Scale
	
		if adjust then
			local vsc=psc*scale
			
			--adjust jump power
			jumpscale = scale/math.sqrt(psc)
			if(jumpscale<1) then  --jump power shouldn't drop below normal, major issues
				jumpscale=1
			end
			v:SetJumpPower( math.sqrt(jumpscale)*Sizing.Default.JumpPower )
			
			--step size
			local ss=scale*Sizing.Default.StepSize
			if ss>Sizing.Default.MaxStepSize then --too high step size causes server issues!
				ss=Sizing.Default.MaxStepSize
			end
			v:SetStepSize( ss )
		
			--adjust view offset so that players have the felling of being small/tall
			v:SetViewOffset( 	vsc*Sizing.Default.ViewOffset 		)
			v:SetViewOffsetDucked( 	vsc*Sizing.Default.ViewOffsetDuck 	)
			v:SetNetworkedFloat("PlViewOffset",vsc) --set a network float for that, the client needs it
		
			--adjust hull scale
			local hsc=vsc
			if(hsc>Sizing.Default.MaxHullScale) then --do not go too high!
				hsc=Sizing.Default.MaxHullScale
			end
			v:SetNetworkedFloat("PlHullScale",hsc) --client needs it!
			v:SetHull( 	hsc*Sizing.Default.StandingHull.Minimum	, hsc*Sizing.Default.StandingHull.Maximum 	)
			v:SetHullDuck( 	hsc*Sizing.Default.DuckingHull.Minimum	, hsc*Sizing.Default.DuckingHull.Maximum 	)		
		end
		
		--adjust speed!
		local ws=math.sqrt(scale)*Sizing.Default.WalkSpeed		
		local rs=math.sqrt(scale)*Sizing.Default.RunSpeed
	
		gamemode.Call( "SetPlayerSpeed", v, ws, rs)	

	end

	--gets executed every tick and runs the
	--adjust function for all living players
	local function Tick( )		
		local k, v
		
		for k, v in pairs( player.GetAll( ) ) do
			if v:Alive() then --only modify living players
				AdjustSc(v)
			end
		end
				
	end

	hook.Add( "Tick", "Resizer.Tick", Tick )

	--does the player allow being rescaled by others
	function GetAllow(pl)
		local allow=tonumber(pl:GetInfo("resize_allow"))
		
		if allow then
			if allow<=0 then
				return false
			else
				return true
			end
		else
			return true
		end;
	end
	
	--store the target player size into the database
	function StoreSize(pl, scale)
		local name,lscale,allow,aallow;

		lscale = pl.TargetScale
		name = pl:UniqueID()
		allow = GetAllow(pl);

		if lscale>100 then
			lscale=100
		end

		if allow then
			aallow = 1
		else
			aallow = 0
		end;
		
		local entry_exists = sql.Query( "SELECT * FROM player_scales WHERE uniqueid = "..pl:UniqueID()..";" )
 
		if ( !entry_exists ) then 
			sql.Query( "INSERT INTO player_scales VALUES ("..pl:UniqueID()..","..lscale..","..aallow..");");
		else
			sql.Query( "UPDATE player_scales SET scale="..lscale..",allowothers="..aallow.." WHERE uniqueid = "..pl:UniqueID()..";");
		end

	end
	
	--read the player scale from the database if existing
	--otherwise set default scales and default vars
	function SetOrgScale( pl )
		local name,scale,sztab,allow,result
		name=pl:UniqueID()

		--CreateTable();
		
		if DisableScaleLoading then
			result = false
		else
			result = sql.Query("SELECT * FROM player_scales WHERE uniqueid="..name..";");
		end

		if not result then
			scale = 1
			allow = 1
		else
			for k,row in pairs(result) do
				scale = tonumber(row['scale']);
				if row['allowothers']=="1" then
					allow = 1
				else
					allow = 0
				end
			end
		end
		
		--set variables
		pl:SetNetworkedFloat("PlScale",scale);
		pl:SetNetworkedFloat("PlViewOffset",1);
		pl:SetNetworkedFloat("PlHullScale",1);
		pl:ConCommand("resize_allow "..allow);
		pl.Scale = scale
		pl.TargetScale = scale
		pl.ScaleSpeed = 0
		pl.EndProgress = 0;
		pl.Progress = 0
		pl.ExponentialScaling = true
		AdjustSc(pl)
	end
	hook.Add( "PlayerInitialSpawn", "Resizer.InitScale", SetOrgScale ); 
	
	
	--function for sending messages to the client screen
	local SUCCESS = 1
	local ERROR = 2

	local function HudMSG( ply, message, type, print )    
		if( !type ) then type = SUCCESS end

		if (type == SUCCESS) then
			notify_type  = "NOTIFY_GENERIC"
			notify_sound = "ambient/water/drip" .. math.random(1, 4) .. ".wav"

		elseif (type == ERROR) then
			notify_type  = "NOTIFY_ERROR"
			notify_sound = "buttons/button10.wav"
		end
    
		ply:SendLua( "GAMEMODE:AddNotify( \"" .. message .. "\", " .. notify_type .. ", 5 ); surface.PlaySound( \"" .. notify_sound .. "\" )" )

		if ( print ) then
			ply:PrintMessage( HUD_PRINTCONSOLE, message )
		end
	end



	
	local divider = math.log(1.0/2.0); --for exponential scaling
	
	--function to call to set a player to wished scale
	function ScalePlayer(pl, scale, endprogress, exponential, sendingplayer)
		--am I allowed to do that
		if ( pl:EntIndex()!=sendingplayer:EntIndex() and not GetAllow(pl) ) then
			HudMSG(sendingplayer,"This player disallows external resizing",ERROR,false)
			return
		end
		
		--make sure we do not scale anyone to 0
		if scale <= 0 then
			scale = 0.00001
		end
		--set the variables
		if not pl.Scale then pl.Scale = scale end
		pl.SourceScale = pl.Scale
		pl.TargetScale = scale
		pl.Progress = 0
		pl.EndProgress = endprogress
		pl.ExponentialScaling = exponential
		if exponential then
			pl.ScaleSpeed = math.log(pl.TargetScale / pl.Scale) / endprogress / divider;
		else
			pl.ScaleSpeed = (pl.TargetScale - pl.Scale) / endprogress;
		end
		--store network variables
		pl:SetNetworkedFloat("PlScale",pl.SourceScale)
		--store size to database
		StoreSize(pl,pl.TargetScale)
	end
	
	--create database table if required
	sql.Query("CREATE TABLE IF NOT EXISTS player_scales ( 'uniqueid' INT NOT NULL PRIMARY KEY, 'scale' DOUBLE NOT NULL, 'allowothers' BOOL NOT NULL);");
end


--client specific stuff
if CLIENT then
	--size update on client side
	local function Tick( )
		local k, v
		
		for k, v in pairs( player.GetAll( ) ) do
			--get scale and set model size and render bounds with it
			local pscale = v:GetNetworkedFloat("PlScale")
			if not pscale then
				pscale = 1
			end
			local ScaleVector = pscale
			v:SetModelScale( ScaleVector, 0 )
		--	Msg( pscale )
			v:SetRenderBounds( pscale * Sizing.Default.StandingHull.Minimum, pscale * Sizing.Default.StandingHull.Maximum )			

			--get the view offset (shared function but executing it on client side fixes some screen shaking issues)
			local vsc = v:GetNetworkedFloat("PlViewOffset")
			if not vsc then
				vsc = 1
			end
			v:SetViewOffset( vsc*Sizing.Default.ViewOffset )
			v:SetViewOffsetDucked( vsc*Sizing.Default.ViewOffsetDuck )

			--get the player hull (again shared function but executing it on client side fixes some screen shaking issues)
			local hsc = v:GetNetworkedFloat("PlHullScale")
			if not hsc then
				hsc = 1
			end
			v:SetHull( hsc*Sizing.Default.StandingHull.Minimum, hsc*Sizing.Default.StandingHull.Maximum )
			v:SetHullDuck( hsc*Sizing.Default.DuckingHull.Minimum, hsc*Sizing.Default.DuckingHull.Maximum )		

		end				
	end

	hook.Add( "Tick", "Resizer.ClientTick", Tick )
end
