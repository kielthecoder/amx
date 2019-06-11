MODULE_NAME='Cisco Touch 10 Button v1' (DEV vdv, CHAR sSignals[][], DEVCHAN dcUI[])

DEFINE_FUNCTION INTEGER GetSignalIndex (CHAR sName[])
{
    STACK_VAR INTEGER i
    
    FOR (i = 1; i <= LENGTH_ARRAY(sSignals); i++)
    {
	IF (sSignals[i] == sName)
	{
	    RETURN i
	}
    }
    
    RETURN 0
}

DEFINE_EVENT

DATA_EVENT[vdv]
{
    STRING:
    {
	STACK_VAR INTEGER i
	
	SELECT
	{
	    ACTIVE (FIND_STRING(DATA.TEXT, 'PUSH-', 1)):
	    {
		REMOVE_STRING(DATA.TEXT, 'PUSH-', 1)
		i = GetSignalIndex(DATA.TEXT)
		
		IF (i > 0)
		{
		    ON[dcUI[i]]
		}
	    }
	    ACTIVE (FIND_STRING(DATA.TEXT, 'RELEASE-', 1)):
	    {
		REMOVE_STRING(DATA.TEXT, 'RELEASE-', 1)
		i = GetSignalIndex(DATA.TEXT)
		
		IF (i > 0)
		{
		    OFF[dcUI[i]]
		}
	    }
	}
    }
}
