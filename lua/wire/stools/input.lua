WireToolSetup.setCategory( "I/O" )
WireToolSetup.open( "input", "Numpad Input", "gmod_wire_input", nil, "Numpad Inputs" )

if CLIENT then
	language.Add( "tool.wire_input.name", "Input Tool (Wire)" )
	language.Add( "tool.wire_input.desc", "Spawns a input for use with the wire system." )
	language.Add( "tool.wire_input.0", "Primary: Create/Update Input" )
	language.Add( "WireInputTool_keygroup", "Key:" )
	language.Add( "WireInputTool_toggle", "Toggle" )
	language.Add( "WireInputTool_value_on", "Value On:" )
	language.Add( "WireInputTool_value_off", "Value Off:" )
end
WireToolSetup.BaseLang("Inputs")
WireToolSetup.SetupMax( 20, TOOL.Mode.."s" , "You've hit the Wire "..TOOL.PluralName.." limit!" )

if SERVER then
	ModelPlug_Register("Numpad")
	
	function TOOL:GetConVars() 
		return self:GetClientNumber( "keygroup" ), self:GetClientNumber( "toggle" ), self:GetClientNumber( "value_off" ), self:GetClientNumber( "value_on" )
	end	
	function TOOL:MakeEnt( ply, model, Ang, trace )
		return MakeWireInput( ply, trace.HitPos, Ang, model, self:GetConVars() )
	end
end

TOOL.Model = "models/beer/wiremod/numpad.mdl"
TOOL.ClientConVar = {
	model = TOOL.Model,
	modelsize = "",
	keygroup = 7,
	toggle = 0,
	value_off = 0,
	value_on = 1,
}

function TOOL.BuildCPanel(panel)
	WireToolHelpers.MakePresetControl(panel, "wire_input")
	panel:AddControl("ListBox", {
		Label = "Model Size",
		Options = {
				["normal"] = { wire_input_modelsize = "" },
				["mini"] = { wire_input_modelsize = "_mini" },
				["nano"] = { wire_input_modelsize = "_nano" }
			}
	})
	ModelPlug_AddToCPanel(panel, "Numpad", "wire_input", "#ToolWireIndicator_Model")
	panel:AddControl("Numpad", {
		Label = "#WireInputTool_keygroup",
		Command = "wire_input_keygroup"
	})
	panel:CheckBox("#WireInputTool_toggle", "wire_input_toggle")
	panel:NumSlider("#WireInputTool_value_on", "wire_input_value_on", -10, 10, 1)
	panel:NumSlider("#WireInputTool_value_off", "wire_input_value_off", -10, 10, 1)
end