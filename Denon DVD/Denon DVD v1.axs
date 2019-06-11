MODULE_NAME='Denon DVD v1' (DEV vdv, DEV dv)

DEFINE_CONSTANT

PLAY        = 1
STOP        = 2
PAUSE       = 3
MENU_FUNC   = 44
MENU_UP     = 45
MENU_DN     = 46
MENU_LT     = 47
MENU_RT     = 48
MENU_SELECT = 49
DISC_NEXT   = 55
DISC_PREV   = 56

DEFINE_VARIABLE

VOLATILE INTEGER nChans[] = {
    PLAY, STOP, PAUSE,
    MENU_FUNC, MENU_UP, MENU_DN, MENU_LT, MENU_RT, MENU_SELECT,
    DISC_NEXT, DISC_PREV
}

VOLATILE CHAR sCmds[][12] = {
    '[PC,RC,44]',
    '[PC,RC,49]',
    '[PC,RC,48]',
    '[PC,RC,113]',
    '[PC,RC,88]',
    '[PC,RC,89]',
    '[PC,RC,90]',
    '[PC,RC,91]',
    '[PC,RC,92]',
    '[PC,RC,246]',
    '[PC,RC,245]'
}

DEFINE_EVENT

// DEVICE EVENTS ////////////////////////////////////////////////////////////

DATA_EVENT[dv]
{
    ONLINE:
    {
	SEND_COMMAND dv,"'SET BAUD 9600,N,8,1'"
    }
}

// VIRTUAL DEVICE EVENTS ////////////////////////////////////////////////////

// CHANNEL EVENTS ///////////////////////////////////////////////////////////

CHANNEL_EVENT[vdv,nChans]
{
    ON:
    {
	SEND_STRING dv,"sCmds[GET_LAST(nChans)],$0D"
    }
}
