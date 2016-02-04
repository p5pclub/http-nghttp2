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

#endif
