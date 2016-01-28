#define PERL_NO_GET_CONTEXT     /* we want efficiency */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include "nghttp2_session.h"

nghttp2_session_t* nghttp2_session_ctor(pTHX_ HV* opt)
{
    /* TODO: do something with opts */
    nghttp2_session_t* session = (nghttp2_session_t*) malloc(sizeof(nghttp2_session_t));
    session->info = nghttp2_version(0);
    session->session_ptr = 0;
    session->user_data = 0;
    printf("Created nghttp2_session_t object %p\n", session);
    return session;
}

void nghttp2_session_dtor(pTHX_ nghttp2_session_t* session)
{
    printf("Destroyed nghttp2_session_t object %p\n", session);
    free(session);
}

static void nghttp2_session_create_something(int server,
                                             nghttp2_session_t* session)
{
    int ret = 0;
    nghttp2_session_callbacks* callbacks_ptr = 0;
    const char* what = server ? "server" : "client";

    if (session->session_ptr) {
        printf("Can't create %s session, one already exists\n", what);
        return;
    }

    ret = nghttp2_session_callbacks_new(&callbacks_ptr);
    printf("Created %s session callbacks %d (%s) - %p\n",
           what, ret, nghttp2_strerror(ret), callbacks_ptr);

    /* Set all our callbacks */
    nghttp2_session_callbacks_set_on_header_callback(callbacks_ptr, on_header_callback);
    nghttp2_session_callbacks_set_send_callback(callbacks_ptr, send_callback);

    if (server) {
        ret = nghttp2_session_server_new(&session->session_ptr,
                                         callbacks_ptr,
                                         session->user_data);
    } else {
        ret = nghttp2_session_client_new(&session->session_ptr,
                                         callbacks_ptr,
                                         session->user_data);
    }
    printf("Created %s session %d (%s) - %p\n",
           what, ret, nghttp2_strerror(ret), session->session_ptr);

    nghttp2_session_callbacks_del(callbacks_ptr);
    printf("Destroyed %s session callbacks\n", what);
}

void nghttp2_session_create_client(pTHX_ nghttp2_session_t* session)
{
    nghttp2_session_create_something(0, session);
}

void nghttp2_session_create_server(pTHX_ nghttp2_session_t* session)
{
    nghttp2_session_create_something(1, session);
}

void nghttp2_session_destroy(pTHX_ nghttp2_session_t* session)
{
    if (!session->session_ptr) {
        printf("Can't destroy session, none exists\n");
        return;
    }

    nghttp2_session_del(session->session_ptr);
    session->session_ptr = 0;
    printf("Destroyed session\n");
}

int on_header_callback(nghttp2_session* session,
                       const nghttp2_frame* frame,
                       const uint8_t* name , size_t namelen,
                       const uint8_t* value, size_t valuelen,
                       uint8_t flags,
                       void* user_data)
{
    printf("on_header_callback\n");
    return 0;
}

ssize_t send_callback(nghttp2_session* session,
                      const uint8_t* data, size_t length,
                      int flags,
                      void* user_data)
{
    printf("send_callback\n");
    return 0;
}
