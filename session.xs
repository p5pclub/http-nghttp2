#define PERL_NO_GET_CONTEXT      /* we want efficiency */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include "context.h"

typedef context_t* NGHTTP2__Session;

MODULE = NGHTTP2::Session        PACKAGE = NGHTTP2::Session
PROTOTYPES: DISABLE

#################################################################

context_t*
new(char* CLASS, HV* opt = NULL)
PREINIT:
    SV **svp;
CODE:
{
    /* TODO: type is hardcoded */
    context_t *ctx = context_ctor(CONTEXT_TYPE_CLIENT);

    svp = hv_fetchs(opt, "on_begin_headers", 0);
    ctx->cb.on_begin_headers = svp ? SvREFCNT_inc(*svp) : 0;

    svp = hv_fetchs(opt, "on_header", 0);
    ctx->cb.on_header = svp ? SvREFCNT_inc(*svp) : 0;

    svp = hv_fetchs(opt, "on_send", 0);
    ctx->cb.send = svp ? SvREFCNT_inc(*svp) : 0;

    svp = hv_fetchs(opt, "on_recv", 0);
    ctx->cb.recv = svp ? SvREFCNT_inc(*svp) : 0;
    
    svp = hv_fetchs(opt, "on_data_chunk_recv", 0);
    ctx->cb.on_data_chunk_recv = svp ? SvREFCNT_inc(*svp) : 0;

    /* TODO: set callback pointers */
    RETVAL = ctx;
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

int recv(context_t* context)
CODE:
{
    RETVAL = nghttp2_session_recv(context->session);
}
OUTPUT:
    RETVAL

int send(context_t* context)
CODE:
{
    RETVAL = nghttp2_session_send(context->session);
}
OUTPUT:
    RETVAL
