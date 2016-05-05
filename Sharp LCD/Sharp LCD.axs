MODULE_NAME='Sharp LCD' (DEV vdv, DEV dv)

// ---------------------------------------------------------------------------
// Control module for Sharp LCD
// Version 1 - 3/8/16
//
// Channels:
//		1			Initialize
//		5			Power On/Off
//		10 - 13			Input 1 - 4
//
// Feedback:
//		6			Power On/Off feedback
//
// ---------------------------------------------------------------------------

DEFINE_CONSTANT

TL_POLL = 1

DEFINE_VARIABLE

NON_VOLATILE INTEGER bWarmingUp
NON_VOLATILE INTEGER bCoolingDown
NON_VOLATILE INTEGER bNeedToInitialize

VOLATILE CHAR sBUFFER[512]
VOLATILE CHAR sTEMP[512]

VOLATILE LONG nPollTimes[] = { 2000, 2000, 2000, 2000 }

VOLATILE INTEGER dcInputs[] =
{
    10,11,12,13									// Inputs 1 - 4
}
VOLATILE CHAR sInputs[][10] =
{
    'IAVD1   ',
    'IAVD2   ',
    'IAVD3   ',
    'IAVD4   '
}

DEFINE_START

sBUFFER = ''


DEFINE_EVENT

DATA_EVENT[dv]
{
    ONLINE:
    {
	SEND_COMMAND dv,'SET BAUD 9600,N,8,1'
	
	TIMELINE_CREATE(TL_POLL,nPollTimes,LENGTH_ARRAY(nPollTimes),TIMELINE_RELATIVE,TIMELINE_REPEAT)
    }
    OFFLINE:
    {
	TIMELINE_KILL(TL_POLL)
    }
    STRING:
    {
	sBUFFER = "sBUFFER,DATA.TEXT"
	
	WHILE (FIND_STRING(sBUFFER,"$0D",1))
	{
	    // Grab the next line of text from the buffer
	    sTEMP = REMOVE_STRING(sBUFFER,"$0D",1)
	    
	    SELECT
	    {
		ACTIVE (FIND_STRING(sTEMP,'OK',1)):
		{
		    // Ack after initialize
		    bNeedToInitialize = 0
		}
		ACTIVE (FIND_STRING(sTEMP,'ERR',1)):
		{
		    // Ack after initialize
		    bNeedToInitialize = 0
		}
		ACTIVE (FIND_STRING(sTEMP,'0',1)):
		{
		    bCoolingDown = 0
		    
		    // Set power feedback off
		    [vdv,6] = 0
		}
		ACTIVE (FIND_STRING(sTEMP,'1',1)):
		{
		    bWarmingUp = 0
		    
		    // Set power feedback on
		    [vdv,6] = 1
		}
	    }
	}
    }
}

TIMELINE_EVENT[TL_POLL]
{
    SWITCH (TIMELINE.SEQUENCE)
    {
	CASE 1:
	{
	    IF (bWarmingUp)
	    {
		SEND_STRING dv,"'POWR1   ',$0D"
	    }
	    
	    IF (bCoolingDown)
	    {
		SEND_STRING dv,"'POWR0   ',$0D"
	    }
	}
	CASE 2:
	{
	    IF (bNeedToInitialize)
	    {
		PULSE[vdv,1]
	    }
	}
	CASE 3:
	{
	    SEND_STRING dv,"'POWR????',$0D"
	}
	CASE 4:
	{
	    // TODO
	}
    }
}

CHANNEL_EVENT[vdv,1]								// Initialize
{
    ON:
    {
	SEND_STRING dv,"'RSPW1   ',$0D"
    }
}

CHANNEL_EVENT[vdv,5]								// Power On/Off
{
    ON:
    {
	bCoolingDown = 0
	bWarmingUp = 1
	bNeedToInitialize = 1
	
	SEND_STRING dv,"'POWR1   ',$0D"
    }
    OFF:
    {
	bWarmingUp = 0
	bCoolingDown = 1
	
	SEND_STRING dv,"'POWR0   ',$0D"
    }
}

CHANNEL_EVENT[vdv,dcInputs]							// Inputs 1 - 4
{
    ON:
    {
	WAIT_UNTIL ([vdv,6])
	{
	    WAIT_UNTIL (!bNeedToInitialize)
	    {
		SEND_STRING dv,"sInputs[GET_LAST(dcInputs)],$0D"
	    }
	}
    }
}