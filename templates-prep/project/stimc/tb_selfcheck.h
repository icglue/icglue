#ifndef __TB_SELFCHECK_H__
#define __TB_SELFCHECK_H__

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>

void tb_final_check (unsigned checks_done, unsigned errors, bool offensive);

#ifdef __cplusplus
}
#endif

#endif
