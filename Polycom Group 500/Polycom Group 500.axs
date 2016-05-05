MODULE_NAME='Polycom Group 500' (DEV vdv, DEV dv)

// ---------------------------------------------------------------------------
// Control module for Polycom Group 500
// Version 1 - 3/7/16
//
// Channels:
//	IR Emulation:
//		10 - 19			Keypad 0 - 9
//		20 - 22			Keypad * # .
//		23			Call
//		24			Hang Up
//		25			Directory
//		26 - 30			Up/Down/Left/Right/Select
//		31 - 32			Near/Far
//		33			Home
//		34			Back
//		35			PIP
//
//	Camera Control:
//		50 - 55			Pan/Tilt/Zoom
//		60 - 61			Camera selection
//
//	Content Sharing:
//		80			Start
//		81			Stop
//
//	Audio:
//		100			Privacy On/Off
//
//	Camera Presets:
//		130 - 133		Presets 1 - 4
//
//	System:
//		254			Hang Up All
//		255			Wake/Sleep
//
// Commands:
//
// ---------------------------------------------------------------------------

DEFINE_CONSTANT

DEFINE_VARIABLE

NON_VOLATILE INTEGER nCameraSelection
NON_VOLATILE INTEGER nPresetSelection

VOLATILE CHAR sBUFFER[512]
VOLATILE CHAR sTEMP[512]

VOLATILE INTEGER dcKeypad[] =
{
    10,11,12,13,14,15,16,17,18,19,						// Keypad 0 - 9
    20,21,22,									// Keypad * # .
    23,										// Call
    24,										// Hang Up
    25,										// Directory
    26,27,28,29,30,								// Up/Down/Left/Right/Select
    31,32,									// Near/Far
    33,										// Home
    34,										// Back
    35										// PIP
}
VOLATILE CHAR sKeypad[][25] =
{
    '0','1','2','3','4','5','6','7','8','9',
    '*','#','period',
    'call',
    'hangup',
    'directory',
    'up','down','left','right','select',
    'near','far',
    'home',
    'back',
    'pip'
}
VOLATILE INTEGER dcCameraMovement[] =
{
    50,51,52,53,								// Up/Down/Left/Right
    54,55									// Zoom In/Out
}
VOLATILE CHAR sCameraMovement[][25] =
{
    'up','down','left','right',
    'zoom+','zoom-'
}
VOLATILE INTEGER dcCameraSelection[] =
{
    60,61									// Near/Far
}
VOLATILE CHAR sCameraSelection[][25] =
{
    'near','far'
}
VOLATILE INTEGER dcPresentation[] =
{
    80,81									// Start/Stop
}
VOLATILE CHAR sPresentation[][25] =
{
    'play 2','stop'
}
VOLATILE INTEGER dcPreset[] =
{
    130,131,132,133								// Preset 1 - 4
}

DEFINE_START

sBUFFER = ''

DEFINE_EVENT

DATA_EVENT[dv]
{
    ONLINE:
    {
	SEND_COMMAND dv,'SET BAUD 9600,N,8,1'
    }
    STRING:
    {
	sBUFFER = "sBUFFER,DATA.TEXT"
	
	WHILE (FIND_STRING(sBUFFER,"$0D,$0A",1) > 0)
	{
	    sTEMP = REMOVE_STRING(sBUFFER,"$0D,$0A",1)
	    
	    // TODO, process feedback from codec
	}
    }
}

DATA_EVENT[vdv]
{
    COMMAND:
    {
	// TODO
    }
}

CHANNEL_EVENT[vdv,dcKeypad]							// IR Emulation
{
    ON:
    {
	SEND_STRING dv,"'button ',sKeypad[GET_LAST(dcKeypad)],$0D,$0A"
    }
}

CHANNEL_EVENT[vdv,dcCameraMovement]						// Camera Control
{
    ON:
    {
	SEND_STRING dv,"'camera ',sCameraSelection[nCameraSelection],' move ',sCameraMovement[GET_LAST(dcCameraMovement)],$0D,$0A"
    }
    OFF:
    {
	SEND_STRING dv,"'camera ',sCameraSelection[nCameraSelection],' stop',$0D,$0A"
    }
}

CHANNEL_EVENT[vdv,dcCameraSelection]						// Near/Far selection
{
    ON:
    {
	LOCAL_VAR INTEGER i
	
	nCameraSelection = GET_LAST(dcCameraSelection)
	
	// Clear camera selection feedback
	FOR (i = 1; i <= LENGTH_ARRAY(dcCameraSelection); i++)
	{
	    OFF[vdv,(64 + i)]
	}
	
	// Selected camera feedback
	ON[vdv,(64 + nCameraSelection)]
    }
}

CHANNEL_EVENT[vdv,dcPresentation]						// Start/Stop presentation
{
    ON:
    {
	SEND_STRING dv,"'vcbutton ',sPresentation[GET_LAST(dcPresentation)],$0D,$0A"
    }
}

CHANNEL_EVENT[vdv,100]								// Privacy
{
    ON:
    {
	SEND_STRING dv,"'mute near on',$0D,$0A"
    }
    OFF:
    {
	SEND_STRING dv,"'mute near off',$0D,$0A"
    }
}

CHANNEL_EVENT[vdv,dcPreset]
{
    ON:
    {
	nPresetSelection = GET_LAST(dcPreset)
	
	WAIT 30 'Save Camera Preset'
	{
	    IF (nPresetSelection > 0)
	    {
		SEND_STRING dv,"'preset near set ',ITOA(nPresetSelection),$0D,$0A"
	    }
	}
    }
    OFF:
    {
	CANCEL_WAIT 'Save Camera Preset'
	SEND_STRING dv,"'preset near go ',ITOA(nPresetSelection),$0D,$0A"
	nPresetSelection = 0
    }
}

CHANNEL_EVENT[vdv,254]								// Hang Up All
{
    ON:
    {
	SEND_STRING dv,"'hangup all',$0D,$0A"
    }
}

CHANNEL_EVENT[vdv,255]								// Wake/Sleep
{
    ON:
    {
	SEND_STRING dv,"'wake',$0D,$0A"
    }
    OFF:
    {
	SEND_STRING dv,"'sleep',$0D,$0A"
    }
}
