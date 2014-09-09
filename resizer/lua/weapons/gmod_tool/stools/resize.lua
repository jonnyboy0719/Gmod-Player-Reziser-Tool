TOOL.AddToMenu		= true
TOOL.Category		= "Player Resize"
TOOL.Name		= "Resizer"
TOOL.Command		= nil
TOOL.ConfigName		= nil

TOOL.ClientConVar[ "size" ] = 1
TOOL.ClientConVar[ "speed" ] = 8
TOOL.ClientConVar[ "eyeoffset" ] = 1
TOOL.ClientConVar[ "exponential" ] = 1
TOOL.ClientConVar[ "allow" ] = 1

if CLIENT then
	language.Add( "Tool.resize.name"	, "Player Resizer" 												)
	language.Add( "Tool.resize.desc"	, "Resize a player!" 												)
	language.Add( "Tool.resize.0"		, "Left Click to resize, right to set your own, reload to reset yourself, or the player you are looking at." 	)	
end

function TOOL:InitPlayerscaling( pl, restorescale, sendingplayer)
	if restorescale then
		size = 1
	else
		size = self:GetClientNumber( "size" )
	end
		
	inputspeed = self:GetClientNumber( "speed" )
	
	if(inputspeed >= 10) then
		inputspeed = 10
	end;
	
	endprogress = math.exp(1.1002*(10-inputspeed))

	local expint = self:GetClientNumber( "exponential" )

	if (expint==0) then
		exponential = false
	else
		exponential = true
	end
	
	ScalePlayer(pl, size, endprogress, exponential, sendingplayer)
	
	return true	
end


function TOOL:LeftClick( trace )
	if CLIENT then return true end;
			
	pl = trace.Entity
		
	if not pl:IsPlayer( ) then
		return false
	end
	
	return self:InitPlayerscaling(pl, false, self:GetOwner( ))
end

function TOOL:RightClick( trace )
	if CLIENT then return false end;
	
	pl = self:GetOwner( );
	
	self:InitPlayerscaling( pl, false, pl);
	return false;
end

function TOOL:Reload( trace )
	local pl, a, lpl
	
	if CLIENT then return false end;

	lpl = self:GetOwner( )
	
	if IsValid( trace.Entity ) and trace.Entity:IsPlayer( ) then

		pl = trace.Entity
		
		self:InitPlayerscaling(pl, true, lpl)
					
	else
		self:InitPlayerscaling(lpl, true, lpl)
	end

	return false	
end

function TOOL.BuildCPanel( panel )
	panel:AddControl( "Header", { Text = "#Tool_resize_name" } )
	panel:AddControl( "Slider", { Label = "Size", Type = "Float", Min = .01, Max = 100, Command = "resize_size" } )
	panel:AddControl( "Slider", { Label = "Resizing Speed", Type = "Float", Min = 0, Max = 10, Command = "resize_speed" } )	
	panel:AddControl( "Slider", { Label = "Eye height adjustment", Type = "Float", Min = 0.5, Max = 2, Command = "resize_eyeoffset" } )	
	panel:AddControl( "Checkbox", { Label = "Allow being scaled by other players", Command = "resize_allow" } )
	panel:AddControl( "Checkbox", { Label = "Exponential scaling", Command = "resize_exponential" } )
end