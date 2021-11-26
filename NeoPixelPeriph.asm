org 0
;input your desired GRB values for 24 bit color

loadi &b00000110
store Index

loadi &b11101000
store Red

loadi &b11010110
store Green

loadi &b00001110
store Blue

loadi &b01011
addi  &b00000000
store Red16

loadi &b000101
addi  &b00000000
store Green16

loadi &b11100
addi  &b00000000
store Blue16


Main:
	in Switches 
	shift -1
	jzero One24
	
	in Switches
	shift -2
	jzero All24
	
	in Switches
	shift -3
	jzero One16

	in Switches
	shift -4
	jzero All16

	; in Switches
	; shift -6
	; jzero Fade
	
	; in Switches 
	; shift -7
	; jzero Cascade
	
	in Switches
	shift -10
	jzero switchcontrol
	
	 

One24:
	load index
	out SHIFT_EN
	
	load Green
	out SHIFT_EN
	load Red
	out SHIFT_EN
	load Blue
	out SHIFT_EN
	
	out SHIFTOUT_EN
	out NeoPixel
	Jump Main
	
All24:
	load index
	out SHIFT_EN
	
	load Green
	out SHIFT_EN
	load Red
	out SHIFT_EN
	load Blue
	out SHIFT_EN
	
	out SHIFTOUT_EN
	out NeoPixel
	Jump Main

One16:
	load index
	out SHIFT_EN
	
	load Green16
	out SHIFT_EN
	load Red16
	out SHIFT_EN
	load Blue16
	out SHIFT_EN
	loadi &b00000000 ;padding for a clean 24 bit color value
	out SHIFT_EN
	
	out SHIFTOUT_EN
	out NeoPixel
	Jump Main
	
All16:
	load index
	out SHIFT_EN
	
	load Green16
	out SHIFT_EN
	load Red16
	out SHIFT_EN
	load Blue16
	out SHIFT_EN
	loadi &b00000000 ;padding for a clean 24 bit color value
	out SHIFT_EN
	
	out SHIFTOUT_EN
	out NeoPixel
	Jump Main
	
switchcontrol:
	load index
	out SHIFT_EN
	
	out SHIFTOUT_EN
	out NeoPixel
	
	
	
	
top3:		DW &b0111000000
mid3:		DW &b0000111000
last3:		DW &b0000000111
Index:  	DW &b00000000
Red:   		DW &b00000000
Green: 		DW &b00000000
Blue:  		DW &b00000000
Red16:		DW &b00000000
Green16:	DW &b00000000
Blue16:		DW &b00000000

; IO address constants
Switches:  	EQU &H000
LEDs:      	EQU &H001
Timer:     	EQU &H002
Hex0:      	EQU &H004
Hex1:      	EQU &H005
I2C_cmd:   	EQU &H090
I2C_data:  	EQU &H091
I2C_rdy:    EQU &H092
NeoPixel:	EQU &H0A0
SHIFT_EN:	EQU &H0A1
SHIFTOUT_EN:	EQU &H0A2