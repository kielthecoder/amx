MODULE_NAME='Shure MXA910 v1' (DEV vdv, DEV dv)

DEFINE_CONSTANT

TCP_PORT_CONTROL = 2202

MAX_CMD_LENGTH  = 100
MAX_BUFFER_SIZE = 5000

// SNAPI LITE /////////////////////////////////////////////////////////////////

PWR_ON               = 27
PWR_OFF              = 28
PRIVACY_ON           = 146
PRIVACY_FB           = 146
DEVICE_COMMUNICATING = 251
DATA_INITIALIZED     = 252
POWER_ON             = 255
POWER_FB             = 255

DEFINE_VARIABLE

NON_VOLATILE CHAR sIPAddress[50]

VOLATILE CHAR sRxBuffer[MAX_BUFFER_SIZE]

// FUNCTIONS //////////////////////////////////////////////////////////////////

DEFINE_FUNCTION InitializeModule ()
{
    sRxBuffer = ''
    
    IF ([vdv,DEVICE_COMMUNICATING])
    {
	IP_CLIENT_CLOSE(dv.PORT)
    }
    
    IP_CLIENT_OPEN(dv.PORT, sIPAddress, TCP_PORT_CONTROL, IP_TCP)
}

// EVENTS /////////////////////////////////////////////////////////////////////

DEFINE_EVENT

DATA_EVENT[dv]
{
    ONLINE:
    {
	ON[vdv,DEVICE_COMMUNICATING]
	ON[vdv,DATA_INITIALIZED]
    }
    OFFLINE:
    {
	OFF[vdv,DEVICE_COMMUNICATING]
	OFF[vdv,DATA_INITIALIZED]
    }
    ONERROR:
    {
	OFF[vdv,DEVICE_COMMUNICATING]
	OFF[vdv,DATA_INITIALIZED]
    }
    STRING:
    {
	STACK_VAR CHAR sResult[MAX_CMD_LENGTH]
	
	// Tack incoming data onto end of receiver buffer
	sRxBuffer = "sRxBuffer,DATA.TEXT"
	
	WHILE (FIND_STRING(sRxBuffer, '>', 1))
	{
	    sResult = REMOVE_STRING(sRxBuffer, '>', 1)
	}
    }
}

DATA_EVENT[vdv]
{
    COMMAND:
    {
	STACK_VAR CHAR sKey[50]
	STACK_VAR CHAR sValue[50]
	
	SELECT
	{
	    ACTIVE (DATA.TEXT == 'REINIT'):
	    {
		InitializeModule()
	    }
	    ACTIVE (FIND_STRING(DATA.TEXT, 'PROPERTY-', 1)):
	    {
		REMOVE_STRING(DATA.TEXT, 'PROPERTY-', 1)
		sKey = UPPER_STRING(REMOVE_STRING(DATA.TEXT, ',', 1))
		sValue = DATA.TEXT
		
		SELECT
		{
		    ACTIVE (sKey == 'IP_ADDRESS,'):
		    {
			sIPAddress = sValue
		    }
		}
	    }
	}
    }
}

// MIC MUTE STATES/////////////////////////////////////////////////////////////

CHANNEL_EVENT[vdv,PWR_ON]
{
    ON:
    {
	SEND_STRING dv, '< SET LED_BRIGHTNESS 2 >'
	ON[vdv,POWER_FB]
    }
}

CHANNEL_EVENT[vdv,PWR_OFF]
{
    ON:
    {
	SEND_STRING dv, '< SET LED_BRIGHTNESS 0 >'
	OFF[vdv,POWER_FB]
    }
}

CHANNEL_EVENT[vdv,POWER_ON]
{
    ON:
    {
	PULSE[vdv,PWR_ON]
    }
    OFF:
    {
	PULSE[vdv,PWR_OFF]
    }
}

CHANNEL_EVENT[vdv,PRIVACY_ON]
{
    ON:
    {
	SEND_STRING dv, '< SET DEV_LED_IN_STATE OFF >'
    }
    OFF:
    {
	SEND_STRING dv, '< SET DEV_LED_IN_STATE ON >'
    }
}