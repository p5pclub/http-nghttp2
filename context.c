/*
 * We explicitly do not define PERL_NO_GET_CONTEXT because we
 * are manually manipulating the stack in our callback functions.
 */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include "context.h"

static int on_begin_headers_cb(nghttp2_session* session,
                               const nghttp2_frame* frame,
                               void* user_data);
static int on_header_cb(nghttp2_session* session,
                        const nghttp2_frame* frame,
                        const uint8_t* name , size_t namelen,
                        const uint8_t* value, size_t valuelen,
                        uint8_t flags,
                        void* user_data);
static ssize_t send_cb(nghttp2_session* session,
                       const uint8_t* data, size_t length,
                       int flags,
                       void* user_data);
static int on_frame_recv_cb(nghttp2_session* session,
                            const nghttp2_frame* frame,
                            void* user_data);
static int on_data_chunk_recv_cb(nghttp2_session* session,
                                 uint8_t flags,
                                 int32_t stream_id,
                                 const uint8_t* data, size_t len,
                                 void* user_data);
static int on_stream_close_cb(nghttp2_session* session,
                              int32_t stream_id,
                              uint32_t error_code,
                              void* user_data);

context_t* context_ctor(int type)
{
    context_t* context = (context_t*) malloc(sizeof(context_t));
    context->type = type;
    context->info = nghttp2_version(0);
    context->session = 0;
    context->cb.on_header = 0;
    context->cb.send = 0;
    printf("Created context object %p\n", context);
    return context;
}

void context_dtor(context_t* context)
{
    printf("Destroying context object %p\n", context);
    free(context);
}

void context_session_open(context_t* context)
{
    int ret = 0;
    nghttp2_session_callbacks* callbacks = 0;

    if (context->session) {
        printf("Can't open session, one already exists\n");
        return;
    }

    ret = nghttp2_session_callbacks_new(&callbacks);

    nghttp2_session_callbacks_set_on_begin_headers_callback(callbacks, on_begin_headers_cb);
    nghttp2_session_callbacks_set_on_header_callback(callbacks, on_header_cb);
    nghttp2_session_callbacks_set_send_callback(callbacks, send_cb);
    nghttp2_session_callbacks_set_on_frame_recv_callback(callbacks, on_frame_recv_cb);
    nghttp2_session_callbacks_set_on_data_chunk_recv_callback(callbacks, on_data_chunk_recv_cb);
    nghttp2_session_callbacks_set_on_stream_close_callback(callbacks, on_stream_close_cb);

    switch (context->type) {
        case CONTEXT_TYPE_CLIENT:
            ret = nghttp2_session_client_new(&context->session,
                                             callbacks,
                                             context);
            break;

        case CONTEXT_TYPE_SERVER:
            ret = nghttp2_session_server_new(&context->session,
                                             callbacks,
                                             context);
            break;

        default:
            printf("Invalid session type %d\n", context->type);
            break;
    }

    nghttp2_session_callbacks_del(callbacks);

    printf("Opened session %p - %d (%s)\n",
           context->session, ret, nghttp2_strerror(ret));
}

void context_session_close(context_t* context)
{
    if (!context->session) {
        printf("Can't close session, none exists\n");
        return;
    }

    printf("Closing session %p\n", context->session);
    nghttp2_session_del(context->session);
    context->session = 0;
}

void context_session_terminate(context_t* context, int reason)
{
    if (!context->session) {
        printf("Can't terminate session, none exists\n");
        return;
    }

    printf("Terminating session %p, reason %d\n", context->session, reason);
    nghttp2_session_terminate_session(context->session, reason);
}

int context_session_want_read(context_t* context)
{
    if (!context->session) {
        printf("Can't inquire want_read from session, none exists\n");
        return 0;
    }

    printf("want_read for session %p\n", context->session);
    return nghttp2_session_want_read(context->session);
}

int context_session_want_write(context_t* context)
{
    if (!context->session) {
        printf("Can't inquire want_write from session, none exists\n");
        return 0;
    }

    printf("want_write for session %p\n", context->session);
    return nghttp2_session_want_write(context->session);
}


static int on_begin_headers_cb(nghttp2_session *session,
                               const nghttp2_frame *frame,
                               void *user_data)
{
    context_t* context = (context_t*) user_data;
    SV* sv_type = 0;
    SV* sv_length = 0;
    SV* sv_stream_id = 0;

    printf("on_begin_headers_cb %p\n", context);

    if (!context || !context->cb.on_begin_headers) {
        return 0;
    }

    dSP;
    ENTER;
    SAVETMPS;

    /* TODO: there is more info in headers, but it is a union... */
    sv_type      = sv_2mortal(newSViv(frame->hd.type));
    sv_length    = sv_2mortal(newSViv(frame->hd.length));
    sv_stream_id = sv_2mortal(newSViv(frame->hd.stream_id));

    PUSHMARK(SP);
    XPUSHs(sv_type);
    XPUSHs(sv_length);
    XPUSHs(sv_stream_id);
    PUTBACK;

    printf("calling Perl on_begin_headers_cb %p\n", context->cb.on_begin_headers);
    call_sv(context->cb.on_begin_headers, G_SCALAR);

    /* TODO: should return the value from Perl callback */
    SPAGAIN;
    PUTBACK;
    FREETMPS;
    LEAVE;

    return 0;
}

static int on_header_cb(nghttp2_session* session,
                        const nghttp2_frame* frame,
                        const uint8_t* name , size_t namelen,
                        const uint8_t* value, size_t valuelen,
                        uint8_t flags,
                        void* user_data)
{
    context_t* context = (context_t*) user_data;
    /* TODO: pass flags? */
    SV* sv_type = 0;
    SV* sv_length = 0;
    SV* sv_stream_id = 0;
    SV* sv_name = 0;
    SV* sv_value = 0;

    printf("on_header_cb %p\n", context);

    if (!context || !context->cb.on_header) {
        return 0;
    }

#if 0
    /*
     * frame->hd.stream_id should match the stream_id
     * we got back from nghttp2_submit_request()
     */
    if (frame->hd.type     != NGHTTP2_HEADERS ||
        frame->headers.cat != NGHTTP2_HCAT_RESPONSE ||
        context->stream_id != frame->hd.stream_id) {
        return 0;
    }
#endif

    dSP;
    ENTER;
    SAVETMPS;

    /* TODO: there is more info in headers, but it is a union... */
    sv_type      = sv_2mortal(newSViv(frame->hd.type));
    sv_length    = sv_2mortal(newSViv(frame->hd.length));
    sv_stream_id = sv_2mortal(newSViv(frame->hd.stream_id));
    if (namelen > 0) {
        sv_name = sv_2mortal(newSVpv((const char*) name, namelen));
    } else {
        sv_name = sv_2mortal(newSV(0));
    }
    if (valuelen > 0) {
        sv_value = sv_2mortal(newSVpv((const char*) value, valuelen));
    } else {
        sv_value = sv_2mortal(newSV(0));
    }

    PUSHMARK(SP);
    XPUSHs(sv_type);
    XPUSHs(sv_length);
    XPUSHs(sv_stream_id);
    XPUSHs(sv_name);
    XPUSHs(sv_value);
    PUTBACK;

    printf("calling Perl on_header_cb %p\n", context->cb.on_header);
    call_sv(context->cb.on_header, G_SCALAR);

    /* TODO: should return the value from Perl callback */
    SPAGAIN;
    PUTBACK;
    FREETMPS;
    LEAVE;

    return 0;
}

static ssize_t send_cb(nghttp2_session* session,
                       const uint8_t* data, size_t length,
                       int flags,
                       void* user_data)
{
    context_t* context = (context_t*) user_data;
    /* TODO: pass flags? */
    SV* sv_data = 0;

    printf("send_cb %p\n", context);

    if (!context || !context->cb.send) {
        return 0;
    }

    dSP;
    ENTER;
    SAVETMPS;

    if (length > 0) {
        sv_data = sv_2mortal(newSVpv((const char*) data, length));
    } else {
        sv_data = sv_2mortal(newSV(0));
    }

    PUSHMARK(SP);
    XPUSHs(sv_data);
    PUTBACK;

    printf("calling Perl send_cb %p\n", context->cb.send);
    call_sv(context->cb.send, G_SCALAR);

    /* TODO: should return the value from Perl callback */
    SPAGAIN;
    PUTBACK;
    FREETMPS;
    LEAVE;

    return 0;
}

static int on_frame_recv_cb(nghttp2_session* session,
                            const nghttp2_frame* frame,
                            void* user_data)
{
    context_t* context = (context_t*) user_data;
    SV* sv_type = 0;
    SV* sv_length = 0;
    SV* sv_stream_id = 0;

    printf("on_frame_recv_cb %p\n", context);

    if (!context || !context->cb.on_frame_recv) {
        return 0;
    }

    dSP;
    ENTER;
    SAVETMPS;

    /* TODO: there is more info in headers, but it is a union... */
    sv_type      = sv_2mortal(newSViv(frame->hd.type));
    sv_length    = sv_2mortal(newSViv(frame->hd.length));
    sv_stream_id = sv_2mortal(newSViv(frame->hd.stream_id));

    PUSHMARK(SP);
    XPUSHs(sv_type);
    XPUSHs(sv_length);
    XPUSHs(sv_stream_id);
    PUTBACK;

    printf("calling Perl on_frame_recv_cb %p\n", context->cb.on_frame_recv);
    call_sv(context->cb.on_frame_recv, G_SCALAR);

    /* TODO: should return the value from Perl callback */
    SPAGAIN;
    PUTBACK;
    FREETMPS;
    LEAVE;

    return 0;
}

static int on_data_chunk_recv_cb(nghttp2_session* session,
                                 uint8_t flags,
                                 int32_t stream_id,
                                 const uint8_t* data, size_t length,
                                 void* user_data)
{
    context_t* context = (context_t*) user_data;
    /* TODO: pass flags? */
    SV* sv_stream_id = 0;
    SV* sv_data = 0;

    printf("on_data_chunk_recv_cb %p\n", context);

    if (!context || !context->cb.on_data_chunk_recv) {
        return 0;
    }

    dSP;
    ENTER;
    SAVETMPS;

    sv_stream_id = sv_2mortal(newSViv(stream_id));
    if (length > 0) {
        sv_data = sv_2mortal(newSVpv((const char*) data, length));
    } else {
        sv_data = sv_2mortal(newSV(0));
    }

    PUSHMARK(SP);
    XPUSHs(sv_stream_id);
    XPUSHs(sv_data);
    PUTBACK;

    printf("calling Perl on_data_chunk_recv_cb %p\n", context->cb.on_data_chunk_recv);
    call_sv(context->cb.on_data_chunk_recv, G_SCALAR);

    /* TODO: should return the value from Perl callback */
    SPAGAIN;
    PUTBACK;
    FREETMPS;
    LEAVE;

    return 0;
}

static int on_stream_close_cb(nghttp2_session* session,
                              int32_t stream_id,
                              uint32_t error_code,
                              void* user_data)
{
    context_t* context = (context_t*) user_data;
    SV* sv_stream_id = 0;
    SV* sv_error_code = 0;

    printf("on_stream_close_cb %p\n", context);

    if (!context || !context->cb.on_stream_close) {
        return 0;
    }

    dSP;
    ENTER;
    SAVETMPS;

    /* TODO: there is more info in headers, but it is a union... */
    sv_stream_id  = sv_2mortal(newSViv(stream_id));
    sv_error_code = sv_2mortal(newSViv(error_code));

    PUSHMARK(SP);
    XPUSHs(sv_stream_id);
    XPUSHs(sv_error_code);
    PUTBACK;

    printf("calling Perl on_stream_close_cb %p\n", context->cb.on_stream_close);
    call_sv(context->cb.on_stream_close, G_SCALAR);

    /* TODO: should return the value from Perl callback */
    SPAGAIN;
    PUTBACK;
    FREETMPS;
    LEAVE;

    return 0;
}
