#define PERL_NO_GET_CONTEXT      /* we want efficiency */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include "context.h"

typedef context_t* NGHttp2__Session;

MODULE = NGHttp2::Session        PACKAGE = NGHttp2::Session
PROTOTYPES: DISABLE

#################################################################

context_t*
new(char* CLASS, HV* opt = NULL)
CODE:
{
    /* TODO: type is hardcoded */
    RETVAL = context_ctor(CONTEXT_TYPE_CLIENT);
}
OUTPUT: RETVAL

void
DESTROY(context_t* context)
CODE:
{
    context_dtor(context);
}

void
_ping(context_t* context)
CODE:
{
    printf("Context %p is alive -- age = %d, version = %d (%s), proto = [%s]\n",
           context,
           context->info->age,
           context->info->version_num,
           context->info->version_str,
           context->info->proto_str);
}

void
open_session(context_t* context)
CODE:
{
    context_session_open(context);
}

void
close_session(context_t* context)
CODE:
{
    context_session_close(context);
}

void
terminate_session(context_t* context, int reason)
CODE:
{
    context_session_terminate(context, reason);
}

int
want_read(context_t* context)
CODE:
{
    RETVAL = context_session_want_read(context);
}
OUTPUT: RETVAL

int
want_write(context_t* context)
CODE:
{
    RETVAL = context_session_want_write(context);
}
OUTPUT: RETVAL
