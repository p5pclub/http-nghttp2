#define PERL_NO_GET_CONTEXT      /* we want efficiency */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include "context.h"

typedef context_t* NGHTTP2__Session;

static void handle_options(pTHX_ context_t* context, HV* opt) {
#define getter(name) {\
    SV **svp = hv_fetchs(opt, #name, 0); \
    context->cb.name = svp ? SvREFCNT_inc(*svp) : 0; \
}
    CALLBACK_LIST(getter);
#undef getter
}

static int session_dtor(pTHX_ SV *sv, MAGIC *mg) {
    context_t *ctx = (context_t*) mg->mg_ptr;
#define cleanup(name) SvREFCNT_dec(ctx->cb.name)
    CALLBACK_LIST(cleanup);
#undef cleanup

    context_dtor(ctx);

    return 0;
}

static MGVTBL session_magic_vtbl = { .svt_free = session_dtor };

MODULE = NGHTTP2::Session        PACKAGE = NGHTTP2::Session
PROTOTYPES: DISABLE

#################################################################

context_t*
new(char* CLASS, HV* opt = NULL)
CODE:
{
    /* TODO: type is hardcoded */
    context_t *ctx = context_ctor(CONTEXT_TYPE_CLIENT);
    handle_options(aTHX_ ctx, opt);

    RETVAL = ctx;
}
OUTPUT: RETVAL

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
    int err = nghttp2_session_recv(context->session);
    if (err < 0) {
        warn("Error calling nghttp2_session_recv: %s",
             nghttp2_strerror(err));
    }
    RETVAL = err;
}
OUTPUT:
    RETVAL

int send(context_t* context)
CODE:
{
    int err = nghttp2_session_send(context->session);
    if (err < 0) {
        warn("Error calling nghttp2_session_send: %s",
             nghttp2_strerror(err));
    }
    RETVAL = err;
}
OUTPUT:
    RETVAL

int submit_request(context_t* context, AV* headers)
PREINIT:
    nghttp2_nv *nva;
    size_t nvlen;
    int i;
    int stream_id;
CODE:
    nvlen = av_top_index(headers) + 1;
    Newx(nva, nvlen, nghttp2_nv);
    SAVEFREEPV(nva);
    for(i = 0; i < nvlen; i++) {
        SV** hdr;
        SV** key;
        SV** val;

        hdr = av_fetch(headers, i, 0);
        if (!(hdr && SvROK(*hdr) && SvTYPE(SvRV(*hdr)) == SVt_PVAV)) {
            croak("header %d should be arrayref", i);
        }

        key = av_fetch((AV*) SvRV(*hdr), 0, 0);
        val = av_fetch((AV*) SvRV(*hdr), 1, 0);

        if (key == NULL || val == NULL) {
            croak("header %d has undefined name or value", i);
        }

        nva[i].name = (uint8_t *) savepv(SvPV(*key, nva[i].namelen));
        nva[i].value = (uint8_t *) savepv(SvPV(*val, nva[i].valuelen));
        nva[i].flags = 0;

        SAVEFREEPV(nva[i].name);
        SAVEFREEPV(nva[i].value);
    }

    stream_id = nghttp2_submit_request(context->session, NULL, nva, nvlen, NULL, NULL);
    if (stream_id < 0) {
        warn("Error calling nghttp2_submit_request: %s",
             nghttp2_strerror(stream_id));
    }
    RETVAL = stream_id;
OUTPUT:
    RETVAL
