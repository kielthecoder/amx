MODULE_NAME='Polycom SoundStructure' (DEV vdv, DEV dv, CHAR sChannels[][][25], DEV faders[])

// ---------------------------------------------------------------------------
// Control module for Polycom Group 500
// Version 1 - 3/7/16
//
// Channels:
//		2			Initialize
//	Dialer:
//		5			Call
//		6			Hang Up
//		10 - 19			Keypad 0 - 9
//		20 - 21			Keypad * #
//		25			Backspace
//		26			Clear
//
// Commands:
//
// Feedback Channels:
//		1			Hook Status
//
// Faders:
//	Volume:
//		50			Up
//		51			Down
//		52			Mute Toggle
//		53			Mute Status
//		54			Mute On/Off
//	Levels:
//		1			Volume bargraph (0 - 255)
//
// ---------------------------------------------------------------------------

DEFINE_CONSTANT

MAX_CHANNELS = 16

TL_PROCESS_QUEUE = 1
TL_RAMP_UP       = 2
TL_RAMP_DOWN     = 3

DEFINE_VARIABLE

NON_VOLATILE CHAR sPhoneIn[25]
NON_VOLATILE CHAR sPhoneOut[25]
NON_VOLATILE CHAR sDialerNumber[50]

NON_VOLATILE CHAR    sChannelName[MAX_CHANNELS][25]
NON_VOLATILE INTEGER nChannelCount

NON_VOLATILE SINTEGER nFaderMax[MAX_CHANNELS]
NON_VOLATILE SINTEGER nFaderMin[MAX_CHANNELS]
NON_VOLATILE SINTEGER nFaderValue[MAX_CHANNELS]
NON_VOLATILE INTEGER  nMuteState[MAX_CHANNELS]

VOLATILE CHAR sQUEUE[50][50]
VOLATILE CHAR sBUFFER[512]
VOLATILE CHAR sTEMP[512]

VOLATILE INTEGER ix
VOLATILE INTEGER nActiveChannel
VOLATILE INTEGER nQueueIndex
VOLATILE INTEGER nQueueLast
VOLATILE SLONG   nScaledValue

VOLATILE LONG nQueuePacingTimes[] = { 300 }
VOLATILE LONG nRampTimes[] = { 300 }

VOLATILE INTEGER dcKeypad[] =
{
    10,11,12,13,14,15,16,17,18,19,						// Keypad 0 - 9
    20,21									// Keypad * #
}
VOLATILE CHAR sKeypad[][25] =
{
    '0','1','2','3','4','5','6','7','8','9',
    '*','#'
}

DEFINE_START

// Clear the command queue
nQueueIndex = 1
nQueueLast = 1

TIMELINE_CREATE(TL_PROCESS_QUEUE,nQueuePacingTimes,LENGTH_ARRAY(nQueuePacingTimes),TIMELINE_RELATIVE,TIMELINE_REPEAT)

// How many channels were defined for control?
nChannelCount = 0

FOR (ix = 1; ix <= LENGTH_ARRAY(sChannels); ix++)
{
    // Treat phone channels differently
    IF (sChannels[ix][2] == 'PHONEIN')
    {
	sPhoneIn = sChannels[ix][1]
    }
    ELSE IF (sChannels[ix][2] == 'PHONEOUT')
    {
	sPhoneOut = sChannels[ix][1]
    }
    // Mono channel control
    ELSE IF (sChannels[ix][2] == 'MONO')
    {
	nChannelCount = nChannelCount + 1
	sChannelName[nChannelCount] = sChannels[ix][1]
    }
}

// Expand the virtual device to allow channel control
SET_VIRTUAL_PORT_COUNT(vdv,(nChannelCount + 1))

sBUFFER = ''

DEFINE_FUNCTION Queue (CHAR msg[50])
{
    // Make sure the queue isn't full
    IF (nQueueLast < 50)
    {
	// Stick this message into the last slot of the queue
	sQUEUE[nQueueLast] = msg
	
	// Open up a new slot
	nQueueLast = nQueueLast + 1
    }
}

DEFINE_EVENT

TIMELINE_EVENT[TL_PROCESS_QUEUE]
{
    // Check if there are unsent items in the queue
    IF (nQueueIndex < nQueueLast)
    {
	// Transmit to the device
	SEND_STRING dv,"sQUEUE[nQueueIndex],$0D"
	
	// Move to the next item in the queue
	nQueueIndex = nQueueIndex + 1
    }
    ELSE
    {
	// Queue is empty, reset our pointers
	nQueueIndex = 1
	nQueueLast = 1
    }
}

DATA_EVENT[dv]
{
    ONLINE:
    {
	SEND_COMMAND dv,'SET BAUD 115200,N,8,1'
	
	WAIT_UNTIL (nChannelCount > 0)
	{
	    // Wait until channels are defined, then initialize values
	    PULSE[vdv,2]
	}
    }
    STRING:
    {
	// Save incoming text to our buffer
	sBUFFER = "sBUFFER,DATA.TEXT"
	
	WHILE (FIND_STRING(sBUFFER,"$0D",1) > 0)
	{
	    // Grab the next line of text from the buffer
	    sTEMP = REMOVE_STRING(sBUFFER,"$0D",1)
	    
	    SELECT
	    {
		ACTIVE (FIND_STRING(sTEMP,'val fader max',1)):
		{
		    REMOVE_STRING(sTEMP,'val fader max',1)
		    
		    FOR (ix = 1; ix <= nChannelCount; ix++)
		    {
			IF (FIND_STRING(sTEMP,sChannelName[ix],1))
			{
			    // Channel names are surrounded by double quotes
			    REMOVE_STRING(sTEMP,"'"',sChannelName[ix],'"'",1)
			    
			    nFaderMax[ix] = ATOI(sTEMP)
			    
			    BREAK
			}
		    }
		}
		ACTIVE (FIND_STRING(sTEMP,'val fader min',1)):
		{
		    REMOVE_STRING(sTEMP,'val fader min',1)
		    
		    FOR (ix = 1; ix <= nChannelCount; ix++)
		    {
			IF (FIND_STRING(sTEMP,sChannelName[ix],1))
			{
			    // Channel names are surrounded by double quotes
			    REMOVE_STRING(sTEMP,"'"',sChannelName[ix],'"'",1)
			    
			    nFaderMin[ix] = ATOI(sTEMP)
			    
			    BREAK
			}
		    }
		}
		ACTIVE (FIND_STRING(sTEMP,'val fader',1)):
		{
		    REMOVE_STRING(sTEMP,'val fader',1)
		    
		    FOR (ix = 1; ix <= nChannelCount; ix++)
		    {
			IF (FIND_STRING(sTEMP,sChannelName[ix],1))
			{
			    // Channel names are surrounded by double quotes
			    REMOVE_STRING(sTEMP,"'"',sChannelName[ix],'"'",1)
			    
			    nFaderValue[ix] = ATOI(sTEMP)
			    
			    // Scale the fader to 0 - 255
			    nScaledValue = 256
			    nScaledValue = nScaledValue * (nFaderValue[ix] - nFaderMin[ix])
			    nScaledValue = nScaledValue / (nFaderMax[ix] - nFaderMin[ix])
			    
			    // Send the level out
			    SEND_LEVEL faders[ix],1,nScaledValue
			    
			    BREAK
			}
		    }
		}
		ACTIVE (FIND_STRING(sTEMP,'val mute',1)):
		{
		    REMOVE_STRING(sTEMP,'val mute',1)
		    
		    FOR (ix = 1; ix <= nChannelCount; ix++)
		    {
			IF (FIND_STRING(sTEMP,sChannelName[ix],1))
			{
			    // Channel names are surrounded by double quotes
			    REMOVE_STRING(sTEMP,"'"',sChannelName[ix],'"'",1)
			    
			    // 1 = muted, 0 = unmuted
			    [faders[ix],53] = ATOI(sTEMP)
			    
			    BREAK
			}
		    }
		}
		ACTIVE (FIND_STRING(sTEMP,'val phone_connect',1)):
		{
		    REMOVE_STRING(sTEMP,'val phone_connect',1)
		    
		    IF (FIND_STRING(sTEMP,sPhoneOut,1))
		    {
			// Channel names are surrounded by double quotes
			REMOVE_STRING(sTEMP,"'"',sPhoneOut,'"'",1)
			
			// 1 = off hook, 0 = on hook
			[vdv,1] = ATOI(sTEMP)
		    }
		}
	    }
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

CHANNEL_EVENT[vdv,2]								// Initialize
{
    ON:
    {
	FOR (ix = 1; ix <= nChannelCount; ix++)
	{
	    Queue("'get fader min "',sChannelName[ix],'"'")
	    Queue("'get fader max "',sChannelName[ix],'"'")
	    Queue("'get fader "',sChannelName[ix],'"'")
	    Queue("'get mute "',sChannelName[ix],'"'")
	}
    }
}

CHANNEL_EVENT[vdv,5]								// Answer/Dial
{
    ON:
    {
	Queue("'set phone_connect "',sPhoneOut,'" 1'")
	
	WAIT_UNTIL ([vdv,1])
	{
	    WAIT 10
	    {
		IF (LENGTH_STRING(sDialerNumber) > 0)
		{
		    Queue("'set phone_dial "',sPhoneOut,'" "',sDialerNumber,'"'")
		}
	    }
	}
    }
}

CHANNEL_EVENT[vdv,6]								// Hang Up
{
    ON:
    {
	Queue("'set phone_connect "',sPhoneOut,'" 0'")
	
	WAIT 10
	{
	    // Clear dialer number after hang up
	    PULSE[vdv,26]
	}
    }
}

CHANNEL_EVENT[vdv,dcKeypad]							// Dialer keypad
{
    ON:
    {
	// Is the phone off-hook?
	IF ([vdv,1])
	{
	    // TODO, send DTMF
	}
	ELSE
	{
	    IF (LENGTH_STRING(sDialerNumber) < 50)
	    {
		sDialerNumber = "sDialerNumber,sKeypad[GET_LAST(dcKeypad)]"
	    }
	    
	    SEND_STRING vdv,"'DIALER-',sDialerNumber"
	}
    }
}

CHANNEL_EVENT[vdv,25]								// Backspace
{
    ON:
    {
	LOCAL_VAR INTEGER n
	
	n = LENGTH_STRING(sDialerNumber)
	
	IF (n > 0)
	{
	    sDialerNumber = LEFT_STRING(sDialerNumber, n - 1)
	}
	
	SEND_STRING vdv,"'DIALER-',sDialerNumber"
    }
}

CHANNEL_EVENT[vdv,26]								// Clear
{
    ON:
    {
	sDialerNumber = ''
	SEND_STRING vdv,"'DIALER-',sDialerNumber"
    }
}

CHANNEL_EVENT[faders,50]							// Volume Up
{
    ON:
    {
	nActiveChannel = CHANNEL.DEVICE.PORT - 1
	
	Queue("'inc fader "',sChannelName[nActiveChannel],'" 1'")
	
	TIMELINE_CREATE(TL_RAMP_UP,nRampTimes,LENGTH_ARRAY(nRampTimes),TIMELINE_RELATIVE,TIMELINE_REPEAT)
    }
    OFF:
    {
	TIMELINE_KILL(TL_RAMP_UP)
    }
}

TIMELINE_EVENT[TL_RAMP_UP]
{
    Queue("'inc fader "',sChannelName[nActiveChannel],'" 1'")
}

CHANNEL_EVENT[faders,51]							// Volume Down
{
    ON:
    {
	nActiveChannel = CHANNEL.DEVICE.PORT - 1
	
	Queue("'dec fader "',sChannelName[nActiveChannel],'" 1'")
	
	TIMELINE_CREATE(TL_RAMP_DOWN,nRampTimes,LENGTH_ARRAY(nRampTimes),TIMELINE_RELATIVE,TIMELINE_REPEAT)
    }
    OFF:
    {
	TIMELINE_KILL(TL_RAMP_DOWN)
    }
}

TIMELINE_EVENT[TL_RAMP_DOWN]
{
    Queue("'dec fader "',sChannelName[nActiveChannel],'" 1'")
}

CHANNEL_EVENT[faders,52]							// Mute Toggle
{
    ON:
    {
	nActiveChannel = CHANNEL.DEVICE.PORT - 1
	Queue("'tog mute "',sChannelName[nActiveChannel],'"'")
    }
}

CHANNEL_EVENT[faders,54]							// Mute On/Off
{
    ON:
    {
	nActiveChannel = CHANNEL.DEVICE.PORT - 1
	Queue("'set mute "',sChannelName[nActiveChannel],'" 1'")
    }
    OFF:
    {
	nActiveChannel = CHANNEL.DEVICE.PORT - 1
	Queue("'set mute "',sChannelName[nActiveChannel],'" 0'")
    }
}