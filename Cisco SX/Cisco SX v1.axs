MODULE_NAME='Cisco SX v1' (DEV vdv, DEV dv)

DEFINE_CONSTANT

TCP_PORT_TELNET  = 23

MAX_CMD_LENGTH   = 100
MAX_QUEUE_SIZE   = 10
MAX_PARAM_LENGTH = 100
MAX_BUFFER_SIZE  = 5000
MAX_CALLS        = 5

// SNAPI LITE /////////////////////////////////////////////////////////////////

PWR_ON               = 27
PWR_OFF              = 28
PRIVACY_FB           = 146
DEVICE_COMMUNICATING = 251
DATA_INITIALIZED     = 252
POWER_FB             = 255

// SNAPI CUSTOM ///////////////////////////////////////////////////////////////

AUTHENTICATED_FB     = 300
CALL_ACTIVE_FB       = 301

// TIMELINES //////////////////////////////////////////////////////////////////

TL_QUEUE = 1

DEFINE_TYPE

STRUCTURE TCALL
{
    INTEGER nConnected
    INTEGER nID
    CHAR    sProtocol[10]
    CHAR    sDirection[10]
    INTEGER nCallRate
}

DEFINE_VARIABLE

NON_VOLATILE SLONG nBaud = 115200
NON_VOLATILE CHAR  bSerial = 1

NON_VOLATILE CHAR sIPAddress[50]
NON_VOLATILE CHAR sUserName[20]
NON_VOLATILE CHAR sPassword[20]

VOLATILE LONG lQueueTimes[] = { 500 }
VOLATILE CHAR bQueueDeviceBusy

VOLATILE CHAR    sQueue[MAX_QUEUE_SIZE][MAX_CMD_LENGTH]
VOLATILE INTEGER nQueueIndex
VOLATILE INTEGER nQueueNext

VOLATILE CHAR sRxBuffer[MAX_BUFFER_SIZE]
VOLATILE CHAR sParseEvent[50]

VOLATILE TCALL Calls[MAX_CALLS]

VOLATILE INTEGER nTempCallID
VOLATILE CHAR    sTempCallProtocol[10]
VOLATILE CHAR    sTempCallDirection[10]
VOLATILE INTEGER nTempCallRate

// FUNCTIONS //////////////////////////////////////////////////////////////////

DEFINE_FUNCTION QueueCommand (CHAR sCmd[MAX_CMD_LENGTH])
{
    IF (nQueueNext < MAX_QUEUE_SIZE)
    {
	sQueue[nQueueNext] = sCmd
	nQueueNext = nQueueNext + 1
    }
    ELSE
    {
	SEND_STRING 0,"'ERROR-Queue full, command dropped: ',sCmd"
    }
}

DEFINE_FUNCTION InitializeModule ()
{
    nQueueIndex = 1
    nQueueNext  = 1
    bQueueDeviceBusy = 0
    sRxBuffer = ''

    IF (bSerial)
    {
	SEND_COMMAND dv,"'SET BAUD ',ITOA(nBaud),',N,8,1 485 DISABLE'"
	SEND_STRING  dv,"$0D,$0A"
    }
    ELSE
    {
	IF ([vdv,DEVICE_COMMUNICATING])
	{
	    IP_CLIENT_CLOSE(dv.PORT)
	}
	
	IP_CLIENT_OPEN(dv.PORT, sIPAddress, TCP_PORT_TELNET, IP_TCP)
    }
}

DEFINE_FUNCTION TelnetNegotiation (CHAR sMsg[3])
{
    SELECT
    {
	ACTIVE (sMsg == "$FF,$FD,$18"): // DO Terminal Type
	{
	    SEND_STRING dv, "$FF,$FC,$18"	// WONT Terminal Type
	}
	ACTIVE (sMsg == "$FF,$FD,$20"): // DO Terminal Speed
	{
	    SEND_STRING dv, "$FF,$FC,$20"	// WONT Terminal Speed
	}
	ACTIVE (sMsg == "$FF,$FD,$23"): // DO X Display Location
	{
	    SEND_STRING dv, "$FF,$FC,$23"	// WONT X Display Location
	}
	ACTIVE (sMsg == "$FF,$FD,$27"): // DO Environment Variables
	{
	    SEND_STRING dv, "$FF,$FC,$27"	// WONT Environment Variables
	}
	ACTIVE (sMsg == "$FF,$FB,$03"): // WILL Suppress Go Ahead
	{
	    SEND_STRING dv, "$FF,$FB,$03"	// WILL Suppress Go Ahead
	}
	ACTIVE (sMsg == "$FF,$FD,$03"): // DO Suppress Go Ahead
	{
	    SEND_STRING dv, "$FF,$FB,$03"	// WILL Suppress Go Ahead
	}
	ACTIVE (sMsg == "$FF,$FB,$01"): // WILL Echo Characters
	{
	    SEND_STRING dv, "$FF,$FC,$01"	// WONT Echo Characters
	}
	ACTIVE (sMsg == "$FF,$FD,$01"): // DO Echo Characters
	{
	    SEND_STRING dv, "$FF,$FE,$01"	// DONT Echo Characters
	}
	ACTIVE (sMsg == "$FF,$FD,$1F"): // DO Window Size
	{
	    SEND_STRING dv, "$FF,$FC,$1F"	// WONT Window Size
	}
	ACTIVE (sMsg == "$FF,$FB,$05"): // WILL Status
	{
	    SEND_STRING dv, "$FF,$FC,$05"	// WONT Status
	}
	ACTIVE (sMsg == "$FF,$FD,$21"): // DO Remote Flow Control
	{
	    SEND_STRING dv, "$FF,$FC,$21"	// WONT Remote Flow Control
	    SEND_STRING dv, "$FF,$FE,$21"	// DONT Remote Flow Control
	}
    }
}

// CODEC EVENTS ///////////////////////////////////////////////////////////////

DEFINE_FUNCTION ParseEventResponse (CHAR sMsg[MAX_CMD_LENGTH])
{
    SELECT
    {
	ACTIVE (FIND_STRING(sMsg, 'CallSuccessful', 1)):
	{
	    REMOVE_STRING(sMsg, 'CallSuccessful ', 1)
	    sParseEvent = 'CallSuccessful'
	    ProcessCallSuccessfulEvent(sMsg)
	}
	ACTIVE (FIND_STRING(sMsg, 'CallDisconnect', 1)):
	{
	    REMOVE_STRING(sMsg, 'CallDisconnect ', 1)
	    sParseEvent = 'CallDisconnect'
	    ProcessCallDisconnectEvent(sMsg)
	}
	ACTIVE (FIND_STRING(sMsg, 'UserInterface Extensions Event', 1)):
	{
	    REMOVE_STRING(sMsg, 'UserInterface Extensions Event', 1)
	    sParseEvent = 'UserInterface Extensions Event'
	    ProcessUserInterfaceEvent(sMsg)
	}
	ACTIVE (1):
	{
	    SEND_STRING 0, "'ParseEventResponse-Ignored: ',sMsg"
	}
    }
}

DEFINE_FUNCTION ProcessCallSuccessfulEvent (CHAR sInfo[MAX_PARAM_LENGTH])
{
    SELECT
    {
	ACTIVE (FIND_STRING(sInfo, 'CallId:', 1)):
	{
	    REMOVE_STRING(sInfo, 'CallId: ', 1)
	    nTempCallID = ATOI(sInfo)
	}
	ACTIVE (FIND_STRING(sInfo, 'Protocol:', 1)):
	{
	    REMOVE_STRING(sInfo, 'Protocol: "', 1)
	    sTempCallProtocol = REMOVE_STRING(sInfo, '"', 1)
	    sTempCallProtocol = LEFT_STRING(sTempCallProtocol, LENGTH_STRING(sTempCallProtocol) - 1)
	}
	ACTIVE (FIND_STRING(sInfo, 'Direction:', 1)):
	{
	    REMOVE_STRING(sInfo, 'Direction: "', 1)
	    sTempCallDirection = REMOVE_STRING(sInfo, '"', 1)
	    sTempCallDirection = LEFT_STRING(sTempCallDirection, LENGTH_STRING(sTempCallDirection) - 1)
	}
	ACTIVE (FIND_STRING(sInfo, 'CallRate:', 1)):
	{
	    REMOVE_STRING(sInfo, 'CallRate: ', 1)
	    nTempCallRate = ATOI(sInfo)
	}
	ACTIVE (1):
	{
	    SEND_STRING 0, "'ProcessCallSuccessfulEvent-Ignored: ',sInfo"
	}
    }
}

DEFINE_FUNCTION ProcessCallDisconnectEvent (CHAR sInfo[MAX_PARAM_LENGTH])
{
    SELECT
    {
	ACTIVE (FIND_STRING(sInfo, 'CallId:', 1)):
	{
	    REMOVE_STRING(sInfo, 'CallId: ', 1)
	    nTempCallID = ATOI(sInfo)
	}
	ACTIVE (1):
	{
	    SEND_STRING 0, "'ProcessCallDisconnectEvent-Ignored: ',sInfo"
	}
    }
}

DEFINE_FUNCTION ProcessUserInterfaceEvent (CHAR sAction[MAX_PARAM_LENGTH])
{
    STACK_VAR CHAR sSignal[MAX_PARAM_LENGTH]
    
    SELECT
    {
	ACTIVE (FIND_STRING(sAction, 'Pressed', 1)):
	{
	    REMOVE_STRING(sAction, 'Pressed Signal: "', 1)
	    sSignal = REMOVE_STRING(sAction, '"', 1)
	    sSignal = LEFT_STRING(sSignal, LENGTH_STRING(sSignal) - 1)
	    
	    SEND_STRING vdv,"'PUSH-',sSignal"
	}
	ACTIVE (FIND_STRING(sAction, 'Released', 1)):
	{
	    REMOVE_STRING(sAction, 'Released Signal: "', 1)
	    sSignal = REMOVE_STRING(sAction, '"', 1)
	    sSignal = LEFT_STRING(sSignal, LENGTH_STRING(sSignal) - 1)
	    
	    SEND_STRING vdv,"'RELEASE-',sSignal"
	}
	ACTIVE (FIND_STRING(sAction, 'Changed', 1)):
	{
	    REMOVE_STRING(sAction, 'Changed Signal: "', 1)
	    sSignal = REMOVE_STRING(sAction, ':', 1)
	    sSignal = LEFT_STRING(sSignal, LENGTH_STRING(sSignal) - 1)
	    sAction = REMOVE_STRING(sAction, '"', 1)
	    sAction = LEFT_STRING(sAction, LENGTH_STRING(sAction) - 1)
	    
	    SELECT
	    {
		ACTIVE (sAction == 'on'):
		{
		    SEND_STRING vdv,"'ON-',sSignal"
		}
		ACTIVE (sAction == 'off'):
		{
		    SEND_STRING vdv,"'OFF-',sSignal"
		}
	    }
	}
	ACTIVE (1):
	{
	    SEND_STRING 0, "'ProcessUserInterfaceEvent-Ignored: ',sAction"
	}
    }
}

// CODEC COMMANDS /////////////////////////////////////////////////////////////

DEFINE_FUNCTION ParseCommandResponse (CHAR sMsg[MAX_CMD_LENGTH])
{
    SELECT
    {
	ACTIVE (1):
	{
	    SEND_STRING 0, "'ParseCommandResponse-Ignored: ',sMsg"
	}
    }
}

// CODEC STATUS ///////////////////////////////////////////////////////////////

DEFINE_FUNCTION ParseStatusResponse (CHAR sMsg[MAX_CMD_LENGTH])
{
    SELECT
    {
	ACTIVE (FIND_STRING(sMsg, 'Standby State:', 1)):
	{
	    REMOVE_STRING(sMsg, 'Standby State:', 1)
	    ProcessStandby(sMsg)
	}
	ACTIVE (FIND_STRING(sMsg, 'Audio Microphones Mute:', 1)):
	{
	    REMOVE_STRING(sMsg, 'Audio Microphones Mute:', 1)
	    ProcessMicMute(sMsg)
	}
	ACTIVE (1):
	{
	    SEND_STRING 0, "'ParseStatusResponse-Ignored: ',sMsg"
	}
    }
}

DEFINE_FUNCTION ProcessStandby (CHAR sState[MAX_PARAM_LENGTH])
{
    SELECT
    {
	ACTIVE (FIND_STRING(sState, 'Off', 1)):
	{
	    ON[vdv,POWER_FB]
	}
	ACTIVE (FIND_STRING(sState, 'Halfwake', 1)):
	{
	    ON[vdv,POWER_FB]
	}
	ACTIVE (FIND_STRING(sState, 'Standby', 1)):
	{
	    OFF[vdv,POWER_FB]
	}
    }
}

DEFINE_FUNCTION ProcessMicMute (CHAR sState[MAX_PARAM_LENGTH])
{
    SELECT
    {
	ACTIVE (FIND_STRING(sState, 'Off', 1)):
	{
	    OFF[vdv,PRIVACY_FB]
	}
	ACTIVE (FIND_STRING(sState, 'On', 1)):
	{
	    ON[vdv,PRIVACY_FB]
	}
    }
}

DEFINE_FUNCTION UpdateCallStatus ()
{
    STACK_VAR INTEGER nConnectedCalls
    STACK_VAR INTEGER nIndex

    nConnectedCalls = 0
    
    FOR (nIndex = 1; nIndex <= MAX_CALLS; nIndex++)
    {
	IF (Calls[nIndex].nConnected == 1)
	{
	    nConnectedCalls = nConnectedCalls + 1
	}
    }
    
    IF (nConnectedCalls > 0)
    {
	ON[vdv,CALL_ACTIVE_FB]
    }
    ELSE
    {
	OFF[vdv,CALL_ACTIVE_FB]
    }
}

// START //////////////////////////////////////////////////////////////////////

DEFINE_START

nQueueIndex = 1
nQueueNext  = 1
bQueueDeviceBusy = 0

TIMELINE_CREATE(TL_QUEUE, lQueueTimes, LENGTH_ARRAY(lQueueTimes),
    TIMELINE_RELATIVE, TIMELINE_REPEAT)
    
// EVENTS /////////////////////////////////////////////////////////////////////

DEFINE_EVENT

DATA_EVENT[dv]
{
    ONLINE:
    {
	ON[vdv,DEVICE_COMMUNICATING]
	OFF[vdv,AUTHENTICATED_FB]
    }
    OFFLINE:
    {
	OFF[vdv,DEVICE_COMMUNICATING]
	OFF[vdv,AUTHENTICATED_FB]
    }
    ONERROR:
    {
	OFF[vdv,DEVICE_COMMUNICATING]
	OFF[vdv,AUTHENTICATED_FB]
    }
    STRING:
    {
	STACK_VAR CHAR    sResult[MAX_CMD_LENGTH]
	STACK_VAR CHAR    sControlMsg[3]
	STACK_VAR INTEGER nIndex
	
	// Tack incoming data onto end of receive buffer
	sRxBuffer = "sRxBuffer,DATA.TEXT"
	
	// Have we authenticated yet?
	IF ([vdv,AUTHENTICATED_FB])
	{
	    WHILE (FIND_STRING(sRxBuffer, "$0D,$0A", 1))
	    {
		sResult = REMOVE_STRING(sRxBuffer, "$0D,$0A", 1)
		
		SELECT
		{
		    ACTIVE (LEFT_STRING(sResult, 2) == 'OK'):
		    {
			bQueueDeviceBusy = 0
		    }
		    ACTIVE (LEFT_STRING(sResult, 5) == 'ERROR'):
		    {
			bQueueDeviceBusy = 0
		    }
		    ACTIVE (LEFT_STRING(sResult, 2) == '*e'):
		    {
			ParseEventResponse(sResult)
		    }
		    ACTIVE (LEFT_STRING(sResult, 2) == '*r'):
		    {
			ParseCommandResponse(sResult)
		    }
		    ACTIVE (LEFT_STRING(sResult, 2) == '*s'):
		    {
			ParseStatusResponse(sResult)
		    }
		    ACTIVE (LEFT_STRING(sResult, 6) == '** end'):
		    {
			SELECT
			{
			    ACTIVE (sParseEvent == 'CallSuccessful'):
			    {
				FOR (nIndex = 1; nIndex <= MAX_CALLS; nIndex++)
				{
				    IF (Calls[nIndex].nConnected == 0)
				    {
					Calls[nIndex].nConnected = 1
					Calls[nIndex].nID = nTempCallID
					Calls[nIndex].sProtocol = sTempCallProtocol
					Calls[nIndex].sDirection = sTempCallDirection
					Calls[nIndex].nCallRate = nTempCallRate
					
					BREAK
				    }
				}
				
				UpdateCallStatus();
			    }
			    ACTIVE (sParseEvent == 'CallDisconnect'):
			    {
				FOR (nIndex = 1; nIndex <= MAX_CALLS; nIndex++)
				{
				    IF (Calls[nIndex].nID == nTempCallID)
				    {
					Calls[nIndex].nConnected = 0
				    }
				}
				
				UpdateCallStatus();
			    }
			}
			
			sParseEvent = ''
		    }
		    ACTIVE (1):
		    {
			SEND_STRING 0, "'STRING-Ignored: ',sResult"
		    }
		}
	    }
	}
	ELSE
	{
	    SELECT
	    {
		ACTIVE (FIND_STRING(sRxBuffer, '*r Login successful', 1)):
		{
		    REMOVE_STRING(sRxBuffer, "'OK',$0D,$0A,$0D,$0A", 1)
		    ON[vdv,AUTHENTICATED_FB]
		}
		ACTIVE (FIND_STRING(sRxBuffer, 'login:', 1)):
		{
		    REMOVE_STRING(sRxBuffer, 'login:', 1)
		    SEND_STRING dv, "sUserName,$0D,$0A"
		}
		ACTIVE (FIND_STRING(sRxBuffer, 'Password:', 1)):
		{
		    REMOVE_STRING(sRxBuffer, 'Password:', 1)
		    SEND_STRING dv, "sPassword,$0D,$0A"
		}
		ACTIVE (1):
		{
		    // Look for Telnet control commands
		    WHILE ((LENGTH_STRING(sRxBuffer) >= 3) &&
			   (sRxBuffer[1] == $FF))
		    {
			sControlMsg = LEFT_STRING(sRxBuffer, 3)
			sRxBuffer = RIGHT_STRING(sRxBuffer, LENGTH_STRING(sRxBuffer) - 3)
			TelnetNegotiation(sControlMsg)
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
		// PROPERTY-key,value
		REMOVE_STRING(DATA.TEXT, 'PROPERTY-', 1)
		// key name is NOT case-sensitive
		sKey = UPPER_STRING(REMOVE_STRING(DATA.TEXT, ',', 1))
		// value is rest of characters in string
		sValue = DATA.TEXT
		
		SELECT
		{
		    ACTIVE (sKey == 'IP_ADDRESS,'):
		    {
			// Assigning IP address means we aren't using serial communication
			sIPAddress = sValue
			bSerial = 0
		    }
		    ACTIVE (sKey == 'USER_NAME,'):
		    {
			sUserName = sValue
		    }
		    ACTIVE (sKey == 'PASSWORD,'):
		    {
			sPassword = sValue
		    }
		    ACTIVE (sKey == 'BAUD_RATE,'):
		    {
			// Assigning baud rate means we are using serial communication
			nBaud = ATOL(sValue)
			bSerial = 1
		    }
		}
	    }
	}
    }
}

// SETUP //////////////////////////////////////////////////////////////////////

CHANNEL_EVENT[vdv,AUTHENTICATED_FB]
{
    ON:
    {
	QueueCommand('echo off')
	QueueCommand('xFeedback deregisterall')
	QueueCommand('xFeedback register Status/Standby')
	QueueCommand('xFeedback register Status/Audio/Microphones/Mute')
	QueueCommand('xFeedback register Event/CallSuccessful')
	QueueCommand('xFeedback register Event/CallDisconnect')
	QueueCommand('xFeedback register Event/UserInterface/Extensions/Event')
	QueueCommand('xFeedback register Event/UserInterface/Presentation/ExternalSource')
	
	QueueCommand('xStatus Standby')
    }
}

// STANDBY ////////////////////////////////////////////////////////////////////

CHANNEL_EVENT[vdv,PWR_ON]
{
    ON:
    {
	QueueCommand('xCommand Standby Deactivate')
    }
}

CHANNEL_EVENT[vdv,PWR_OFF]
{
    ON:
    {
	QueueCommand('xCommand Standby Activate')
    }
}

// TIMELINES //////////////////////////////////////////////////////////////////

TIMELINE_EVENT[TL_QUEUE]
{
    // Wait if we're still getting response from last command sent to device
    IF (!bQueueDeviceBusy)
    {
	// Anything waiting in the queue?
	IF (nQueueNext > nQueueIndex)
	{
	    // Send command to device
	    SEND_STRING dv, "sQueue[nQueueIndex],$0D,$0A"
	    bQueueDeviceBusy = 1
	    
	    // Advance to the next item
	    nQueueIndex = nQueueIndex + 1
	    
	    // Are we at the end of the queue?
	    IF (nQueueIndex == nQueueNext)
	    {
		// Reset our pointers so we don't overflow the array
		nQueueIndex = 1
		nQueueNext = 1
	    }
	}
    }
}