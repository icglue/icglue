/*
 *  stimc is a leightweight verilog-vpi wrapper for stimuli generation.
 *  Copyright (C) 2019-2020  Andreas Dixius, Felix Neumärker
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 */

#ifndef __STIMC_H__
#define __STIMC_H__


#include <vpi_user.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
#include <atomic>
#define stimc_thread_fence(...) std::atomic_thread_fence (std::memory_order_acq_rel)
#else
#include <stdatomic.h>
#define stimc_thread_fence(...) __atomic_thread_fence (__ATOMIC_ACQ_REL)
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* port/net/parameter types */
struct stimc_net_s {
    vpiHandle net;

    uint64_t  nba_value;
    unsigned  nba_lsb;
    unsigned  nba_msb;
    vpiHandle nba_cb_handle;
};
typedef struct stimc_net_s *stimc_net;
typedef struct stimc_net_s *stimc_port;

typedef vpiHandle stimc_parameter;

/* methods/threads */
void stimc_register_posedge_method (void (*methodfunc)(void *userdata), void *userdata, stimc_net net);
void stimc_register_negedge_method (void (*methodfunc)(void *userdata), void *userdata, stimc_net net);
void stimc_register_change_method  (void (*methodfunc)(void *userdata), void *userdata, stimc_net net);

void stimc_register_startup_thread (void (*threadfunc)(void *userdata), void *userdata);

/* time/wait */
#define SC_FS -15
#define SC_PS -12
#define SC_NS -9
#define SC_US -6
#define SC_MS -3
#define SC_S  0
void stimc_wait_time (uint64_t time, int exp);
void stimc_wait_time_seconds (double time);

uint64_t stimc_time (int exp);
double   stimc_time_seconds (void);

/* event/wait */
typedef struct stimc_event_s *stimc_event;

stimc_event stimc_event_create (void);
void        stimc_event_free (stimc_event event);
void        stimc_wait_event (stimc_event event);
void        stimc_trigger_event (stimc_event event);

/* sim control */
void stimc_finish (void);

/* ports/parameters */
static inline void stimc_net_set_int32 (stimc_net net, int32_t value)
{
    s_vpi_value v;

    v.format        = vpiIntVal;
    v.value.integer = value;
    vpi_put_value (net->net, &v, NULL, vpiNoDelay);
}

void stimc_net_set_int32_nonblock (stimc_net net, int32_t value);

static inline int32_t stimc_net_get_int32 (stimc_net net)
{
    s_vpi_value v;

    v.format = vpiIntVal;
    vpi_get_value (net->net, &v);

    return v.value.integer;
}

static inline unsigned stimc_net_size (stimc_net net)
{
    return vpi_get (vpiSize, net->net);
}

static inline uint32_t stimc_parameter_get_int32 (stimc_parameter parameter)
{
    s_vpi_value v;

    v.format = vpiIntVal;
    vpi_get_value (parameter, &v);

    return v.value.integer;
}

void stimc_net_set_z_nonblock (stimc_net net);
void stimc_net_set_x_nonblock (stimc_net net);
void stimc_net_set_z          (stimc_net net);
void stimc_net_set_x          (stimc_net net);
bool stimc_net_is_xz          (stimc_net net);

void     stimc_net_set_bits_uint64_nonblock (stimc_net net, unsigned msb, unsigned lsb, uint64_t value);
void     stimc_net_set_bits_uint64          (stimc_net net, unsigned msb, unsigned lsb, uint64_t value);
uint64_t stimc_net_get_bits_uint64          (stimc_net net, unsigned msb, unsigned lsb);
void     stimc_net_set_uint64_nonblock      (stimc_net net, uint64_t value);
void     stimc_net_set_uint64               (stimc_net net, uint64_t value);
uint64_t stimc_net_get_uint64               (stimc_net net);

/* modules */
typedef struct stimc_module_s {
    char *id;
} stimc_module;

void            stimc_module_init    (stimc_module *m);
stimc_port      stimc_port_init      (stimc_module *m, const char *name);
stimc_parameter stimc_parameter_init (stimc_module *m, const char *name);

/* module initialization routine macro
 *
 * calling STIMC_INIT (modulename)
 * {
 *   // body
 * }
 *
 */

#define STIMC_INIT(module) \
    static void _stimc_module_ ## module ## _init (void); \
\
    static int _stimc_module_ ## module ## _init_cptf (PLI_BYTE8 * user_data __attribute__((unused))) \
    { \
        return 0; \
    } \
\
    static int _stimc_module_ ## module ## _init_cltf (PLI_BYTE8 * user_data __attribute__((unused))) \
    { \
        _stimc_module_ ## module ## _init (); \
\
        return 0; \
    } \
\
    void _stimc_module_ ## module ## _register (void) \
    { \
        s_vpi_systf_data tf_data; \
\
        tf_data.type      = vpiSysTask; \
        tf_data.tfname    = "$stimc_" #module "_init"; \
        tf_data.calltf    = _stimc_module_ ## module ## _init_cltf; \
        tf_data.compiletf = _stimc_module_ ## module ## _init_cptf; \
        tf_data.sizetf    = 0; \
        tf_data.user_data = NULL; \
\
        vpi_register_systf (&tf_data); \
    } \
\
    static void _stimc_module_ ## module ## _init (void)

#define STIMC_EXPORT(module) \
    _stimc_module_ ## module ## _register,

#ifdef __cplusplus
}
#endif

#endif

