MODULE_NAME='Sharp PN v1' (DEV vdv, DEV dv)

DEFINE_CONSTANT

POWER_POLL  = 10
POWER_ON    = 27
POWER_OFF   = 28
INPUT_HDMI1 = 31
WARMING_FB  = 253
COOLING_FB  = 254
POWER_ON_FB = 255

TL_POLL      = 1
TL_WARM_UP   = 2
TL_COOL_DOWN = 3

DEFINE_VARIABLE

VOLATILE LONG    lPollTimes[] = { 15000 }
VOLATILE LONG    lWarmUpTimes[] = { 2000, 2000 }
VOLATILE LONG    lCoolDownTimes[] = { 2000, 2000 }
VOLATILE INTEGER nLastCmd

DEFINE_START

TIMELINE_CREATE(TL_POLL, lPollTimes, LENGTH_ARRAY(lPollTimes),
    TIMELINE_ABSOLUTE, TIMELINE_REPEAT)

DEFINE_EVENT

// DEVICE EVENTS ////////////////////////////////////////////////////////////

DATA_EVENT[dv]
{
    ONLINE:
    {
	SEND_COMMAND dv,"'SET BAUD 9600,N,8,1'"
    }
    STRING:
    {
	SWITCH (nLastCmd)
	{
	    CASE POWER_POLL:
	    {
		IF (LEFT_STRING(DATA.TEXT, 1) == '1')
		{
		    // Are we done turning on?
		    IF ([vdv,WARMING_FB])
		    {
			OFF[vdv,WARMING_FB]
		    }
		    
		    ON[vdv,POWER_ON_FB]
		}
		IF (LEFT_STRING(DATA.TEXT, 1) == '0')
		{
		    // Are we done turning off?
		    IF ([vdv,COOLING_FB])
		    {
			OFF[vdv,COOLING_FB]
		    }
		    
		    OFF[vdv,POWER_ON_FB]
		}
	    }
	}
    }
}

// VIRTUAL DEVICE EVENTS ////////////////////////////////////////////////////

DATA_EVENT[vdv]
{
    COMMAND:
    {
	SELECT
	{
	    ACTIVE (DATA.TEXT == 'POWER=ON'):
	    {
		nLastCmd = POWER_ON
		SEND_STRING dv,"'POWR0001',$0D"
	    }
	    ACTIVE (DATA.TEXT == 'POWER=OFF'):
	    {
		nLastCmd = POWER_OFF
		SEND_STRING dv,"'POWR0000',$0D"
	    }
	    ACTIVE (DATA.TEXT == '?POWER'):
	    {
		nLastCmd = POWER_POLL
		SEND_STRING dv,"'POWR????',$0D"
	    }
	    ACTIVE (DATA.TEXT == 'INPUT=HDMI1'):
	    {
		nLastCmd = INPUT_HDMI1
		SEND_STRING dv,"'INPS0009',$0D"
	    }
	}
    }
}

// CHANNEL EVENTS ///////////////////////////////////////////////////////////

CHANNEL_EVENT[vdv,POWER_ON]
{
    ON:
    {
	IF (![vdv,POWER_ON_FB])
	{
	    ON[vdv,WARMING_FB]
	}
	ELSE
	{
	    // Already on, just send 1 power on command anyway
	    SEND_COMMAND vdv,'POWER=ON'
	}
	
	// Automatically select HDMI1 once display is turned on
	WAIT_UNTIL ([vdv,POWER_ON_FB])
	{
	    SEND_COMMAND vdv,'INPUT=HDMI1'
	}
    }
}

CHANNEL_EVENT[vdv,WARMING_FB]
{
    ON:
    {
	// Cancel cool down if now we're warming up
	IF ([vdv,COOLING_FB])
	{
	    OFF[vdv,COOLING_FB]
	}
	
	TIMELINE_CREATE(TL_WARM_UP, lWarmUpTimes, LENGTH_ARRAY(lWarmUpTimes),
	    TIMELINE_RELATIVE, TIMELINE_REPEAT);
    }
    OFF:
    {
	IF (TIMELINE_ACTIVE(TL_WARM_UP))
	{
	    TIMELINE_KILL(TL_WARM_UP)
	}
    }
}

CHANNEL_EVENT[vdv,POWER_OFF]
{
    ON:
    {
	IF ([vdv,POWER_ON_FB])
	{
	    ON[vdv,COOLING_FB]
	}
	ELSE
	{
	    // Already off, just send 1 power off command anyway
	    SEND_COMMAND vdv,'POWER=OFF'
	}
    }
}

CHANNEL_EVENT[vdv,COOLING_FB]
{
    ON:
    {
	// Cancel warm up if now we're cooling down
	IF ([vdv,WARMING_FB])
	{
	    OFF[vdv,WARMING_FB]
	}
	
	TIMELINE_CREATE(TL_COOL_DOWN, lCoolDownTimes, LENGTH_ARRAY(lCoolDownTimes),
	    TIMELINE_RELATIVE, TIMELINE_REPEAT);
    }
    OFF:
    {
	IF (TIMELINE_ACTIVE(TL_COOL_DOWN))
	{
	    TIMELINE_KILL(TL_COOL_DOWN)
	}
    }
}

// TIMELINES ////////////////////////////////////////////////////////////////

TIMELINE_EVENT[TL_POLL]
{
    // Only poll when we're sitting idle
    IF (![vdv,WARMING_FB] && ![vdv,COOLING_FB])
    {
	SEND_COMMAND vdv,'?POWER'
    }
}

TIMELINE_EVENT[TL_WARM_UP]
{
    SWITCH (TIMELINE.SEQUENCE)
    {
	CASE 1:
	{
	    SEND_COMMAND vdv,'POWER=ON'
	}
	CASE 2:
	{
	    SEND_COMMAND vdv,'?POWER'
	}
    }
}

TIMELINE_EVENT[TL_COOL_DOWN]
{
    SWITCH (TIMELINE.SEQUENCE)
    {
	CASE 1:
	{
	    SEND_COMMAND vdv,'POWER=OFF'
	}
	CASE 2:
	{
	    SEND_COMMAND vdv,'?POWER'
	}
    }
}
