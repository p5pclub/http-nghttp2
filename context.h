#ifndef CONTEXT_H
#define CONTEXT_H

/* NGHTTP2 library */
#include <nghttp2/nghttp2.h>

/* Types of sessions we can open */
#define CONTEXT_TYPE_CLIENT 0
#define CONTEXT_TYPE_SERVER 1

typedef struct {
    int type;
    nghttp2_info* info;
    nghttp2_session* session;

    struct cb {
        SV* on_begin_headers;
        SV* on_header;
        SV* send;
        SV* on_frame_recv;
        SV* on_data_chunk_recv;
        SV* on_stream_close;
    } cb;
} context_t;

context_t* context_ctor(int type);
void context_dtor(context_t* context);

void context_session_open(context_t* context);
void context_session_close(context_t* context);
void context_session_terminate(context_t* context, int reason);

int context_session_want_read(context_t* context);
int context_session_want_write(context_t* context);

/*
 * TODO: expose some other functions
 *
 * These are used for sure in the examples:
 *
 * nghttp2_select_next_protocol (maybe client-only ?) (only for SSL ?)
 *
 * nghttp2_session_send (why not nghttp2_session_mem_send ?)
 * nghttp2_session_mem_recv (why not nghttp2_session_recv ?)
 *
 * nghttp2_submit_settings
 * nghttp2_submit_request (maybe client-only ?)
 * nghttp2_submit_response (server-only)
 * nghttp2_submit_rst_stream (maybe server-only ?)
 *
 *
 * Maybe also expose other existing submit functions:
 *
 * nghttp2_submit_headers
 * nghttp2_submit_data
 * nghttp2_submit_trailer
 * nghttp2_submit_priority
 * nghttp2_submit_ping
 * nghttp2_submit_push_promise
 * nghttp2_submit_goaway
 * nghttp2_submit_window_update
 * nghttp2_submit_shutdown_notice (server-only)
 */
#endif
