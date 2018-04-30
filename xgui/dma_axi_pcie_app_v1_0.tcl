# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "C_DATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "KEEP_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "TCQ" -parent ${Page_0}


}

proc update_PARAM_VALUE.C_DATA_WIDTH { PARAM_VALUE.C_DATA_WIDTH } {
	# Procedure called to update C_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_DATA_WIDTH { PARAM_VALUE.C_DATA_WIDTH } {
	# Procedure called to validate C_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.KEEP_WIDTH { PARAM_VALUE.KEEP_WIDTH } {
	# Procedure called to update KEEP_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.KEEP_WIDTH { PARAM_VALUE.KEEP_WIDTH } {
	# Procedure called to validate KEEP_WIDTH
	return true
}

proc update_PARAM_VALUE.TCQ { PARAM_VALUE.TCQ } {
	# Procedure called to update TCQ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TCQ { PARAM_VALUE.TCQ } {
	# Procedure called to validate TCQ
	return true
}


proc update_MODELPARAM_VALUE.C_DATA_WIDTH { MODELPARAM_VALUE.C_DATA_WIDTH PARAM_VALUE.C_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_DATA_WIDTH}] ${MODELPARAM_VALUE.C_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.KEEP_WIDTH { MODELPARAM_VALUE.KEEP_WIDTH PARAM_VALUE.KEEP_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.KEEP_WIDTH}] ${MODELPARAM_VALUE.KEEP_WIDTH}
}

proc update_MODELPARAM_VALUE.TCQ { MODELPARAM_VALUE.TCQ PARAM_VALUE.TCQ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TCQ}] ${MODELPARAM_VALUE.TCQ}
}

