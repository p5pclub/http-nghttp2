#define PERL_NO_GET_CONTEXT     /* we want efficiency */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include <stdio.h>
#include <nghttp2/nghttp2.h>

MODULE = HTTP::NGHttp2        PACKAGE = HTTP::NGHttp2
PROTOTYPES: DISABLE

#################################################################

void
get_info()
  CODE:
    nghttp2_info* info = nghttp2_version(0);
    printf("Age: %d, Version: %d -- [%s], Proto: [%s]\n",
           info->age, info->version_num, info->version_str, info->proto_str);
