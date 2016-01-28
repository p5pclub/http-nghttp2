#ifndef NGHTTP2_SESSION_H
#define NGHTTP2_SESSION_H

/* #define PERL_NO_GET_CONTEXT      we want efficiency */
/* #include "EXTERN.h" */
/* #include "perl.h" */
/* #include "XSUB.h" */
/* #include "ppport.h" */

#include <nghttp2/nghttp2.h>

typedef struct nghttp2_session {
    nghttp2_info* info;
    nghttp2_session* session_ptr;
    void* user_data;
} nghttp2_session_t;

nghttp2_session_t* nghttp2_session_ctor(pTHX_ HV* opt);
void nghttp2_session_dtor(pTHX_ nghttp2_session_t* session);

void nghttp2_session_create_client(pTHX_ nghttp2_session_t* session);
void nghttp2_session_create_server(pTHX_ nghttp2_session_t* session);
void nghttp2_session_destroy(pTHX_ nghttp2_session_t* session);

int on_header_callback(nghttp2_session* session,
                       const nghttp2_frame* frame,
                       const uint8_t* name , size_t namelen,
                       const uint8_t* value, size_t valuelen,
                       uint8_t flags,
                       void* user_data);
ssize_t send_callback(nghttp2_session* session,
                      const uint8_t* data, size_t length,
                      int flags,
                      void* user_data);

#endif
