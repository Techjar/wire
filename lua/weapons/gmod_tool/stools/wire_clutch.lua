TOOL.Category		= "Wire - Physics"
TOOL.Name			= "Clutch"
TOOL.Command		= nil
TOOL.ConfigName		= ""
TOOL.Tab			= "Wire"


if CLIENT then
    language.Add( "Tool.wire_clutch.name", "Clutch Tool (Wire)" )
    language.Add( "Tool.wire_clutch.desc", "Control rotational friction between props" )
    language.Add( "Tool.wire_clutch.0", "Primary: Place/Select a clutch controller\nSecondary: Select an entity to apply the clutch to\nReload: Remove clutch from entity/deselect controller" )
    language.Add( "Tool.wire_clutch.1", "Right click on the second entity you want the clutch to apply to" )
	language.Add( "undone_wireclutch", "Undone Wire Clutch" )
end

if SERVER then
	CreateConVar( "wire_clutch_maxlinks", 10 )	-- how many constraints can be added per controller
	CreateConVar( "wire_clutch_maxrate", 40 )	-- how many constraints/sec may be changed per controller
	CreateConVar( 'sbox_maxwire_clutches', 8 )	-- maximum number of clutch controllers per player (shouldn't need to be set very high)
end

TOOL.ClientConVar[ "model" ] = "models/jaanus/wiretool/wiretool_siren.mdl"
cleanup.Register( "wire_clutch" )


/*---------------------------------------------------------
   -- Server Usermessages --
   Send entity tables for the DrawHUD display
---------------------------------------------------------*/
local Send_Links

if SERVER then
	// Send info: constraints associated with the selected clutch controller
	Send_Links = function( ply, constrained_pairs )
		umsg.Start( "wire_clutch_links", ply )
			local num_constraints = #constrained_pairs
			umsg.Short( num_constraints )

			for k, v in pairs( constrained_pairs ) do
				umsg.Entity( v.Ent1 )
				umsg.Entity( v.Ent2 )
			end
		umsg.End()
	end
end


/*---------------------------------------------------------
   -- Client Usermessages --
   Receive entity tables for the DrawHUD display
---------------------------------------------------------*/
local Linked_Ents = {}		-- Table of constrained ents, with Ent1 as k and Ent2 as v
local Unique_Ents = {}		-- Table of entities as keys

if CLIENT then
	// Receive stage 0 info
	local function Receive_links( um )
		table.Empty( Linked_Ents )
		local num_constraints = um:ReadShort() or 0

		if num_constraints ~= 0 then
			for i = 1, num_constraints do
				local Ent1 = um:ReadEntity()
				local Ent2 = um:ReadEntity()
				table.insert( Linked_Ents, {Ent1 = Ent1, Ent2 = Ent2} )

				Unique_Ents[Ent1] = true
				Unique_Ents[Ent2] = true
			end
		end
	end

	usermessage.Hook( "wire_clutch_links", Receive_links )
end


/*---------------------------------------------------------
   -- DrawHUD --
   Display clutch constraints associated with a controller
---------------------------------------------------------*/
local function InView( pos2D )
	if pos2D.x > 0 and pos2D.y > 0 and pos2D.x < ScrW() and pos2D.y < ScrH() then
		return true
	end
	return false
end


// Client function for drawing a line to represent constraint to world
local function DrawBaseLine( pos, viewpos )
	local dist = math.Clamp( viewpos:Distance( pos ), 50, 5000 )
	local linelength = 3000 / dist

	local pos2D = pos:ToScreen()
	local pos1 = { x = pos2D.x + linelength, y = pos2D.y }
	local pos2 = { x = pos2D.x - linelength, y = pos2D.y }

	surface.DrawLine( pos1.x, pos1.y, pos2.x, pos2.y )
end


// Client function for drawing a circle around the currently selected controller
local function DrawSelectCircle( pos, viewpos )
	local pos2D = pos:ToScreen()

	if InView( pos2D ) then
		surface.DrawCircle( pos2D.x, pos2D.y, 7, Color(255, 100, 100, 255 ) )
	end
end


function TOOL:DrawHUD()
	local DrawnEnts = {}	-- Used to keep track of which ents already have a circle

	local controller = self:GetWeapon():GetNetworkedEntity( "WireClutchController" )
	if !IsValid( controller ) then return end

	// Draw circle around the controller
	local viewpos = LocalPlayer():GetViewModel():GetPos()
	local controllerpos = controller:LocalToWorld( controller:OBBCenter() )
	DrawSelectCircle( controllerpos, viewpos )

	local numconstraints_0 = #Linked_Ents
	if numconstraints_0 ~= 0 then
		// Draw lines between each pair of constrained ents
		surface.SetDrawColor( 100, 255, 100, 255 )


		// Check whether each entity/position can be drawn
		for k, v in pairs( Linked_Ents ) do
			local basepos
			local pos1, pos2

			local IsValid1 = IsValid( v.Ent1 )
			local IsValid2 = IsValid( v.Ent2 )

			if IsValid1 then pos1 = v.Ent1:GetPos():ToScreen() end
			if IsValid2 then pos2 = v.Ent2:GetPos():ToScreen() end

			if !IsValid1 and !IsValid2 then
				table.remove( Linked_Ents, k )
			elseif v.Ent1:IsWorld() then
				basepos = v.Ent2:GetPos() + Vector(0, 0, -30)
				pos1 = basepos:ToScreen()
			elseif v.Ent2:IsWorld() then
				basepos = v.Ent1:GetPos() + Vector(0, 0, -30)
				pos2 = basepos:ToScreen()
			end

			if pos1 and pos2 then
				if InView( pos1 ) and InView( pos2 ) then
					surface.DrawLine( pos1.x, pos1.y, pos2.x, pos2.y )

					if !DrawnEnts[v.Ent1] and IsValid1 then
						surface.DrawCircle( pos1.x, pos1.y, 5, Color(100, 255, 100, 255 ) )
						DrawnEnts[v.Ent1] = true
					end

					if !DrawnEnts[v.Ent2] and IsValid2 then
						surface.DrawCircle( pos2.x, pos2.y, 5, Color(100, 255, 100, 255 ) )
						DrawnEnts[v.Ent2] = true
					end

					if basepos then
						DrawBaseLine( basepos, viewpos )
					end
				end
			end
		end
	end
end


function TOOL:SelectController( controller )
	self.controller = controller
	self:GetWeapon():SetNetworkedEntity( "WireClutchController", controller or Entity(0) ) -- Must use null entity since nil won't send

	// Send constraint from the controller to the client
	local constrained_pairs = {}
	if IsValid( controller ) then
		constrained_pairs = controller:GetConstrainedPairs()
	end

	Send_Links( ply, constrained_pairs )
end


/*---------------------------------------------------------
   -- Left click --
   Creates/selects a clutch controller
---------------------------------------------------------*/
function TOOL:LeftClick( trace )
	self:ClearObjects()
	self:SetStage(0)

	if trace.Entity:IsValid() and trace.Entity:IsPlayer() then return end
	if CLIENT then return true end
	if not util.IsValidPhysicsObject( trace.Entity, trace.PhysicsBone ) then return false end

	// Select an existing controller
	if IsValid( trace.Entity ) and trace.Entity:GetClass() == "gmod_wire_clutch" then
		self:SelectController( trace.Entity )
		return true
	end

	if !self:GetSWEP():CheckLimit( "wire_clutches" ) then return end

	// Get vars for placing a new controller
	local ply = self:GetOwner()
	local Pos = trace.HitPos
	local Ang = trace.HitNormal:Angle()
		Ang.pitch = Ang.pitch + 90

	// Spawn a new clutch controller
	local controller = MakeClutchController( ply, Pos, Ang, self:GetModel() )
	local const = WireLib.Weld( controller, trace.Entity, trace.PhysicsBone, true )

	undo.Create("Wire Clutch")
		undo.AddEntity( controller )
		undo.AddEntity( const )
		undo.SetPlayer( ply )
	undo.Finish()

	ply:AddCleanup( "wire_clutch", controller )

	self:SelectController( controller )

	return true
end


/*---------------------------------------------------------
   -- Right click --
   Associates ents with the currently selected controller
---------------------------------------------------------*/
function TOOL:RightClick( trace )
	if CLIENT then return true end

	local ply = self:GetOwner()
	local stage = self:NumObjects()

	if !IsValid( self.controller ) then
		ply:PrintMessage( HUD_PRINTTALK, "Select a clutch controller with left click first" )
		return
	end

	if ( !IsValid( trace.Entity ) and !trace.Entity:IsWorld() ) or trace.Entity:IsPlayer() then return end

	// First click: select the first entity
	if stage == 0 then
		if trace.Entity:IsWorld() then
			ply:PrintMessage( HUD_PRINTTALK, "Select a valid entity" )
			return
		end

		// Check that we won't be going over the max number of links allowed
		local maxlinks = GetConVarNumber( "wire_clutch_maxlinks", 10 )
		if table.Count( self.controller.clutch_ballsockets ) >= maxlinks then
			ply:PrintMessage( HUD_PRINTTALK, "A maximum of " .. tostring( maxlinks ) .. " links are allowed per clutch controller" )
			return
		end

		// Store this entity for use later
		local Phys = trace.Entity:GetPhysicsObjectNum( trace.PhysicsBone )
		self:SetObject( 1, trace.Entity, trace.HitPos, Phys, trace.PhysicsBone, trace.HitNormal )

		self:SetStage(1)

	// Second click: select the second entity, and update the controller
	else
		local Ent1, Ent2 = self:GetEnt(1), trace.Entity

		if Ent1 == Ent2 then
			ply:PrintMessage( HUD_PRINTTALK, "Select a different entity" )
			return false
		end

		// Check that these ents aren't already registered on this controller
		if self.controller:ClutchExists( Ent1, Ent2 ) then
			ply:PrintMessage( HUD_PRINTTALK, "Entities have already been registered to this controller!" )
			return true
		end

		// Add this constraint to the clutch controller
		self.controller:AddClutch( Ent1, Ent2 )
		WireLib.AddNotify( ply, "Entities registered with clutch controller", NOTIFY_GENERIC, 7 )

		// Update client
		Send_Links( ply, self.controller:GetConstrainedPairs() )

		self:ClearObjects()
		self:SetStage(0)

	end

	return true
end


/*---------------------------------------------------------
   -- Reload --
   Remove clutch association between current controller and
	the traced entity
   Removes all current selections if hits world
---------------------------------------------------------*/
function TOOL:Reload( trace )
	local stage = self:NumObjects()

	if stage == 1 then
		self:ClearObjects()
		self:SetStage(0)
		return

	// Remove clutch associations with this entity
	elseif IsValid( self.controller ) then
		if trace.Entity:IsWorld() then
			self:ClearObjects()
			self:SetStage(0)
			self.controller = nil

		else
			for k, v in pairs( self.controller.clutch_ballsockets ) do
				if k.Ent1 == trace.Entity or k.Ent2 == trace.Entity then
					self.controller:RemoveClutch( k )
				end
			end

		end

		// Update client with new constraint info
		self:SelectController( self.controller )
	end

	return true
end


function TOOL:Holster()
	self:ClearObjects()
	self:SetStage(0)
	self:ReleaseGhostEntity()
end


/*---------------------------------------------------------
   -- Misc tool functions --
---------------------------------------------------------*/

function TOOL:GetModel()
	local model = "models/jaanus/wiretool/wiretool_siren.mdl"
	local modelcheck = self:GetClientInfo( "model" )

	if util.IsValidModel(modelcheck) and util.IsValidProp(modelcheck) then
		model = modelcheck
	end

	return model
end


if SERVER then
	function MakeClutchController( ply, Pos, Ang, model )
		local controller = ents.Create("gmod_wire_clutch")

		controller:SetPlayer( ply )
		controller:SetModel( Model( model or "models/jaanus/wiretool/wiretool_siren.mdl" ) )
		controller:SetPos( Pos - Ang:Up() * controller:OBBMins().z )
		controller:SetAngles( Ang )

		controller:Spawn()

		return controller
	end
	duplicator.RegisterEntityClass("gmod_wire_clutch", MakeClutchController, "Pos", "Ang", "Model")
end


function TOOL:UpdateGhostWireClutch( ent, ply )
	if !IsValid( ent ) then return end
	if IsValid( self:GetWeapon():GetNetworkedEntity( "WireClutchController" ) ) then
		ent:SetNoDraw( true )
		return
	end

	local trace = ply:GetEyeTrace()

	if !trace.Hit or trace.Entity:IsPlayer() or trace.Entity:GetClass() == "gmod_wire_clutch" then
		ent:SetNoDraw( true )
		return
	end

	local Ang = trace.HitNormal:Angle()
	Ang.pitch = Ang.pitch + 90

	local minZ = ent:OBBMins().z
	ent:SetPos( trace.HitPos - trace.HitNormal * minZ )
	ent:SetAngles( Ang )

	ent:SetNoDraw( false )
end


function TOOL:Think()
	if !IsValid(self.GhostEntity) or self.GhostEntity:GetModel() != self:GetModel() then
		self:MakeGhostEntity( self:GetModel(), Vector(0,0,0), Angle(0,0,0) )
	end

	self:UpdateGhostWireClutch( self.GhostEntity, self:GetOwner() )
end


function TOOL.BuildCPanel( panel )
	panel:AddControl( "Header", { Text = "#Tool.wire_clutch.name", Description = "#Tool.wire_clutch.desc" } )
	WireDermaExts.ModelSelect(panel, "wire_clutch_model", list.Get( "Wire_Misc_Tools_Models" ), 1)
end


if CLIENT then return end
/*---------------------------------------------------------
   -- Clutch controller server functions --
---------------------------------------------------------*/
// When a ball socket is removed, clear the entry for each clutch controller
local function OnBallSocketRemoved( const )
	if const.Type and const.Type == "" and const:GetClass() == "phys_ragdollconstraint" then
		for k, v in pairs( ents.FindByClass("gmod_wire_clutch") ) do
			if v.clutch_ballsockets[const] then
				v.clutch_ballsockets[const] = nil
				v:UpdateOverlay()
			end
		end
	end
end

hook.Add( "EntityRemoved", "wire_clutch_ballsocket_removed", function( ent )
	local r, e = pcall( OnBallSocketRemoved, ent )
	if !r then ErrorNoHalt( e .. "\n" ) end
end )
