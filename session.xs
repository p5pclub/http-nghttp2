/* #define PERL_NO_GET_CONTEXT      we want efficiency */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include "nghttp2_session.h"

typedef nghttp2_session_t* HTTP__NGHttp2__Session;

MODULE = HTTP::NGHttp2::Session        PACKAGE = HTTP::NGHttp2::Session
PROTOTYPES: DISABLE

#################################################################

nghttp2_session_t*
new(CLASS, opt = NULL)
    char *CLASS;
    HV *opt;
  CODE:
    RETVAL = nghttp2_session_ctor(aTHX_ opt);
  OUTPUT: RETVAL

void
DESTROY(session)
    nghttp2_session_t* session;
  CODE:
    nghttp2_session_dtor(aTHX_ session);

void
ping(session)
    nghttp2_session_t* session;
  CODE:
    printf("Session %p is alive!\n", session);
    printf("Age: %d, Version: %d -- [%s], Proto: [%s]\n",
           session->info->age,
           session->info->version_num,
           session->info->version_str,
           session->info->proto_str);

void
create_client(session)
    nghttp2_session_t* session;
  CODE:
    nghttp2_session_create_client(aTHX_ session);

void
create_server(session)
    nghttp2_session_t* session;
  CODE:
    nghttp2_session_create_server(aTHX_ session);

void
destroy(session)
    nghttp2_session_t* session;
  CODE:
    nghttp2_session_destroy(aTHX_ session);
