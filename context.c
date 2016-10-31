#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include "context.h"

/* Define nghttp2 callback that forwards call to Perl.
 *
 * DEFINE_CALLBACK(type, name, arguments, param_block, return_block)
 *
 * type - return type of the callback.
 * name - name of the callback.
 * arguments - parenthesized list of arguments of the callback.
 * param_block - code block to marshal callback parameters to perl.
 * return_block - code block to marshal callback results from perl to C.
 *
 * type and arguments are should match exactly the callback definition in nghttp2
 * documentation. name is callback name without '_callback' suffix.
 *
 * return_block should assign to a special variable 'return_value', which is used as a
 * return value of the C callback.
 *
 * FIXME: handle exceptions raised in perl callback.
 * FIXME: handle case where return_count != 1 without croak.
 */
#define DEFINE_CALLBACK(type, name, arguments, param_block, return_block)     \
    static type name##_cb arguments {                                         \
        dTHX;                                                                 \
        dSP;                                                                  \
        context_t* context = (context_t*) user_data;                          \
        int return_count;                                                     \
        type return_value;                                                    \
                                                                              \
        if (!context || !context->cb.name) {                                  \
            return 0;                                                         \
        }                                                                     \
                                                                              \
        ENTER;                                                                \
        SAVETMPS;                                                             \
                                                                              \
        PUSHMARK(SP);                                                         \
        param_block;                                                          \
        PUTBACK;                                                              \
                                                                              \
        return_count = call_sv(context->cb.name, G_SCALAR);                   \
                                                                              \
        SPAGAIN;                                                              \
                                                                              \
        if (return_count != 1) {                                              \
            croak("sub return more than 1 value in scalar context");          \
        }                                                                     \
                                                                              \
        return_block;                                                         \
                                                                              \
        PUTBACK;                                                              \
        FREETMPS;                                                             \
        LEAVE;                                                                \
                                                                              \
        return return_value;                                                  \
    }
/* end of DEFINE_CALLBACK */

DEFINE_CALLBACK(int, on_begin_headers, (nghttp2_session *session, const nghttp2_frame *frame, void *user_data), {
    mXPUSHi(frame->hd.type);
    mXPUSHi(frame->hd.length);
    mXPUSHi(frame->hd.stream_id);
}, {
        return_value = POPi;
});

DEFINE_CALLBACK(int, on_header, (
    nghttp2_session* session,
    const nghttp2_frame* frame,
    const uint8_t* name, size_t namelen,
    const uint8_t* value, size_t valuelen,
    uint8_t flags,
    void* user_data
), {
    mXPUSHi(frame->hd.type);
    mXPUSHi(frame->hd.length);
    mXPUSHi(frame->hd.stream_id);
    mXPUSHp((const char*) name, namelen);
    mXPUSHp((const char*) value, valuelen);
    mXPUSHi(flags);
}, {
    return_value = POPi;
});

DEFINE_CALLBACK(ssize_t, send, (nghttp2_session* session, const uint8_t* data, size_t length, int flags, void* user_data), {
    mXPUSHp((const char*) data, length);
}, {
    return_value = POPi;
});

DEFINE_CALLBACK(ssize_t, recv, (nghttp2_session* session, uint8_t* data, size_t length, int flags, void* user_data), {
    mXPUSHp((char*) data, length);
}, {
    return_value = POPi;
});

DEFINE_CALLBACK(int, on_frame_recv, (nghttp2_session* session, const nghttp2_frame* frame, void* user_data), {
    mXPUSHi(frame->hd.type);
    mXPUSHi(frame->hd.length);
    mXPUSHi(frame->hd.stream_id);
}, {
    return_value = POPi;
});

DEFINE_CALLBACK(int, on_data_chunk_recv, (
    nghttp2_session* session,
    uint8_t flags,
    int32_t stream_id,
    const uint8_t* data, size_t length,
    void* user_data
), {
    mXPUSHi(stream_id);
    mXPUSHi(flags);
    mXPUSHp((const char*) data, length);
}, {});

DEFINE_CALLBACK(int, on_stream_close, (nghttp2_session* session, int32_t stream_id, uint32_t error_code, void* user_data), {
    mXPUSHi(stream_id);
    mXPUSHu(error_code);
}, {
    return_value = POPi;
});

#undef DEFINE_CALLBACK

context_t* context_ctor(int type)
{
    context_t* context = (context_t*) malloc(sizeof(context_t));
    context->type = type;
    context->info = nghttp2_version(0);
    context->session = 0;
    context->cb.on_header = 0;
    context->cb.send = 0;
    context->cb.recv = 0;
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

#define install(name) nghttp2_session_callbacks_set_##name##_callback(callbacks, name##_cb);
    CALLBACK_LIST(install);
#undef install

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
