/*
 *  stimc is a leightweight verilog-vpi wrapper for stimuli generation.
 *  Copyright (C) 2019  Andreas Dixius, Felix Neumärker
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

#include "stimc.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdbool.h>

#include <assert.h>

#include <pcl.h>

#ifndef SOCC_THREAD_STACK_SIZE
/* default stack size */
#define SOCC_THREAD_STACK_SIZE    65536
#endif

#ifndef SOCC_VALVECTOR_MAX_STATIC
#define SOCC_VALVECTOR_MAX_STATIC 8
#endif

static const char *stimc_get_caller_scope (void)
{
    vpiHandle taskref = vpi_handle (vpiSysTfCall, NULL);

    assert (taskref);
    vpiHandle taskscope = vpi_handle (vpiScope, taskref);
    assert (taskscope);
    const char *scope_name = vpi_get_str (vpiFullName, taskscope);
    assert (scope_name);

    return scope_name;
}

struct stimc_method_wrap {
    void  (*methodfunc) (void *userdata);
    void *userdata;
};

static inline void stimc_valuechange_method_callback_wrapper (struct t_cb_data *cb_data, int edge)
{
    struct stimc_method_wrap *wrap = (struct stimc_method_wrap *)cb_data->user_data;

    /* correct edge? */
    if ((edge > 0) && (cb_data->value->value.scalar != vpi1)) {
        return;
    }
    if ((edge < 0) && (cb_data->value->value.scalar != vpi0)) {
        return;
    }

    wrap->methodfunc (wrap->userdata);
}

static PLI_INT32 stimc_posedge_method_callback_wrapper (struct t_cb_data *cb_data)
{
    stimc_valuechange_method_callback_wrapper (cb_data, 1);
    return 0;
}
static PLI_INT32 stimc_negedge_method_callback_wrapper (struct t_cb_data *cb_data)
{
    stimc_valuechange_method_callback_wrapper (cb_data, -1);
    return 0;
}
static PLI_INT32 stimc_change_method_callback_wrapper (struct t_cb_data *cb_data)
{
    stimc_valuechange_method_callback_wrapper (cb_data, 0);
    return 0;
}

static void stimc_register_valuechange_method (void (*methodfunc)(void *userdata), void *userdata, stimc_net net, int edge)
{
    s_cb_data   data;
    s_vpi_time  data_time;
    s_vpi_value data_value;

    struct stimc_method_wrap *wrap = (struct stimc_method_wrap *)malloc (sizeof (struct stimc_method_wrap));

    wrap->methodfunc = methodfunc;
    wrap->userdata   = userdata;

    data.reason = cbValueChange;
    if (edge > 0) {
        /* posedge */
        data.cb_rtn = stimc_posedge_method_callback_wrapper;
    } else if (edge < 0) {
        /* negedge */
        data.cb_rtn = stimc_negedge_method_callback_wrapper;
    } else {
        /* value change */
        data.cb_rtn = stimc_change_method_callback_wrapper;
    }
    data.obj           = net->net;
    data.time          = &data_time;
    data.time->type    = vpiSuppressTime;
    data.time->high    = 0;
    data.time->low     = 0;
    data.time->real    = 0;
    data.value         = &data_value;
    data.value->format = vpiScalarVal;
    data.index         = 0;
    data.user_data     = (PLI_BYTE8 *)wrap;

    assert (vpi_register_cb (&data));
}

void stimc_register_posedge_method (void (*methodfunc)(void *userdata), void *userdata, stimc_net net)
{
    stimc_register_valuechange_method (methodfunc, userdata, net, 1);
}
void stimc_register_negedge_method (void (*methodfunc)(void *userdata), void *userdata, stimc_net net)
{
    stimc_register_valuechange_method (methodfunc, userdata, net, -1);
}
void stimc_register_change_method  (void (*methodfunc)(void *userdata), void *userdata, stimc_net net)
{
    stimc_register_valuechange_method (methodfunc, userdata, net, 0);
}


coroutine_t stimc_current_thread = NULL;

static PLI_INT32 stimc_thread_callback_wrapper (struct t_cb_data *cb_data)
{
    coroutine_t *thread = (coroutine_t)cb_data->user_data;

    assert (thread);

    stimc_current_thread = thread;
    co_call (thread);
    stimc_current_thread = NULL;

    return 0;
}

void stimc_register_startup_thread (void (*threadfunc)(void *userdata), void *userdata)
{
    s_cb_data   data;
    s_vpi_time  data_time;
    s_vpi_value data_value;

    coroutine_t thread = co_create (threadfunc, userdata, NULL, SOCC_THREAD_STACK_SIZE);

    assert (thread);

    data.reason        = cbAfterDelay;
    data.cb_rtn        = stimc_thread_callback_wrapper;
    data.obj           = NULL;
    data.time          = &data_time;
    data.time->type    = vpiSimTime;
    data.time->high    = 0;
    data.time->low     = 0;
    data.time->real    = 0;
    data.value         = &data_value;
    data.value->format = vpiSuppressVal;
    data.index         = 0;
    data.user_data     = (PLI_BYTE8 *)thread;

    assert (vpi_register_cb (&data));
}

static void stimc_suspend (void)
{
    co_resume ();
}

void stimc_wait_time (uint64_t time, int exp)
{
    /* thread data ... */
    coroutine_t *thread = stimc_current_thread;

    assert (thread);

    /* time ... */
    uint64_t ltime        = time;
    int      timeunit_raw = vpi_get (vpiTimeUnit, NULL);
    while (exp > timeunit_raw) {
        ltime *= 10;
        exp--;
    }
    while (exp < timeunit_raw) {
        ltime /= 10;
        exp++;
    }
    uint64_t ltime_h = ltime >> 32;
    uint64_t ltime_l = ltime & 0xffffffff;

    /* add callback ... */
    s_cb_data   data;
    s_vpi_time  data_time;
    s_vpi_value data_value;

    data.reason        = cbAfterDelay;
    data.cb_rtn        = stimc_thread_callback_wrapper;
    data.obj           = NULL;
    data.time          = &data_time;
    data.time->type    = vpiSimTime;
    data.time->high    = ltime_h;
    data.time->low     = ltime_l;
    data.time->real    = time;
    data.value         = &data_value;
    data.value->format = vpiSuppressVal;
    data.index         = 0;
    data.user_data     = (PLI_BYTE8 *)thread;

    assert (vpi_register_cb (&data));

    /* thread handling ... */
    stimc_suspend ();
}

void stimc_wait_time_seconds (double time)
{
    /* time ... */
    int    timeunit_raw = vpi_get (vpiTimeUnit, NULL);
    double timeunit     = timeunit_raw;

    time *= pow (10, -timeunit);
    uint64_t ltime = time;
    stimc_wait_time (ltime, timeunit_raw);
}

uint64_t stimc_time (int exp)
{
    /* get time */
    s_vpi_time time;

    time.type = vpiSimTime;
    vpi_get_time (NULL, &time);

    uint64_t ltime_h = time.high;
    uint64_t ltime_l = time.low;
    uint64_t ltime   = ((ltime_h << 32) | ltime_l);

    /* timeunit */
    int timeunit_raw = vpi_get (vpiTimeUnit, NULL);

    while (exp < timeunit_raw) {
        ltime *= 10;
        exp++;
    }
    while (exp > timeunit_raw) {
        ltime /= 10;
        exp--;
    }

    return ltime;
}

double stimc_time_seconds (void)
{
    /* get time */
    s_vpi_time time;

    time.type = vpiSimTime;
    vpi_get_time (NULL, &time);

    uint64_t ltime_h = time.high;
    uint64_t ltime_l = time.low;
    uint64_t ltime   = ((ltime_h << 32) | ltime_l);

    /* timeunit */
    int timeunit_raw = vpi_get (vpiTimeUnit, NULL);

    double dtime = ltime;
    double dunit = timeunit_raw;
    dtime *= pow (10, dunit);

    return dtime;
}

struct stimc_event_s {
    size_t        threads_len;
    size_t        threads_num;
    volatile bool active;
    coroutine_t  *threads;
    coroutine_t  *threads_shadow;
};

stimc_event stimc_event_create (void)
{
    stimc_event event = (stimc_event)malloc (sizeof (struct stimc_event_s));

    event->active         = false;
    event->threads_len    = 16;
    event->threads_num    = 0;
    event->threads        = (coroutine_t *)malloc (sizeof (coroutine_t) * (event->threads_len));
    event->threads_shadow = (coroutine_t *)malloc (sizeof (coroutine_t) * (event->threads_len));
    event->threads[0]     = NULL;

    return event;
}

void stimc_wait_event (stimc_event event)
{
    /* size check */
    if (event->threads_num + 1 >= event->threads_len) {
        assert (event->active == false);
        event->threads_len   *= 2;
        event->threads        = (coroutine_t *)realloc (event->threads,        event->threads_len);
        event->threads_shadow = (coroutine_t *)realloc (event->threads_shadow, event->threads_len);
    }

    /* thread data ... */
    coroutine_t *thread = stimc_current_thread;
    assert (thread);

    event->threads[event->threads_num] = thread;
    event->threads_num++;
    event->threads[event->threads_num] = NULL;

    /* thread handling ... */
    stimc_suspend ();
}

void stimc_trigger_event (stimc_event event)
{
    if (event->active) return;
    if (event->threads_num == 0) return;

    /* copy threads to shadow... */
    for (size_t i = 0; i <= event->threads_num; i++) {
        event->threads_shadow[i] = event->threads[i];
    }

    assert (event->threads_shadow [event->threads_num] == NULL);

    event->threads[0]  = NULL;
    event->threads_num = 0;

    /* execute threads... */
    coroutine_t *old_thread = stimc_current_thread;
    for (size_t i = 0; event->threads_shadow[i] != NULL; i++) {
        coroutine_t *thread = event->threads_shadow[i];
        stimc_current_thread = thread;
        co_call (thread);
    }
    stimc_current_thread = old_thread;
}

void stimc_finish (void)
{
    vpi_control (vpiFinish, 0);
}

void stimc_module_init (stimc_module *m)
{
    assert (m);
    const char *scope = stimc_get_caller_scope ();

    m->id = (char *)malloc (sizeof (char) * (strlen (scope) + 1));
    strcpy (m->id, scope);
}

static vpiHandle stimc_module_handle_init (stimc_module *m, const char *name)
{
    const char *scope = m->id;

    size_t scope_len = strlen (scope);
    size_t name_len  = strlen (name);

    char *net_name = (char *)malloc (sizeof (char) * (scope_len + name_len + 2));

    strcpy (net_name, scope);
    net_name[scope_len] = '.';
    strcpy (&(net_name[scope_len + 1]), name);

    vpiHandle net = vpi_handle_by_name (net_name, NULL);

    free (net_name);

    assert (net);

    return net;
}

stimc_port stimc_port_init (stimc_module *m, const char *name)
{
    vpiHandle  handle = stimc_module_handle_init (m, name);
    stimc_port result = (stimc_port)malloc (sizeof (struct stimc_net_s));

    result->net           = handle;
    result->nba_cb_handle = NULL;

    return result;
}
stimc_parameter stimc_parameter_init (stimc_module *m, const char *name)
{
    return stimc_module_handle_init (m, name);
}

static inline void stimc_net_set_xz (stimc_net net, int val)
{
    unsigned size = vpi_get (vpiSize, net->net);

    static s_vpi_value v;

    int32_t flags = vpiNoDelay;

    if (size == 1) {
        v.format       = vpiScalarVal;
        v.value.scalar = val;
        vpi_put_value (net->net, &v, NULL, flags);
        return;
    }

    unsigned vsize = ((size - 1) / 32) + 1;
    if (vsize <= SOCC_VALVECTOR_MAX_STATIC) {
        s_vpi_vecval vec[SOCC_VALVECTOR_MAX_STATIC];
        for (unsigned i = 0; i < vsize; i++) {
            vec[i].aval = (val == vpiZ ? 0x00000000 : 0xffffffff);
            vec[i].bval = 0xffffffff;
        }
        v.format       = vpiVectorVal;
        v.value.vector = &(vec[0]);
        vpi_put_value (net->net, &v, NULL, flags);
        return;
    }

    s_vpi_vecval *vec = (s_vpi_vecval *)malloc (vsize * sizeof (s_vpi_vecval));
    for (unsigned i = 0; i < vsize; i++) {
        vec[i].aval = (val == vpiZ ? 0x00000000 : 0xffffffff);
        vec[i].bval = 0xffffffff;
    }
    v.format       = vpiVectorVal;
    v.value.vector = vec;
    vpi_put_value (net->net, &v, NULL, flags);

    free (vec);
}

void stimc_net_set_z (stimc_net net)
{
    stimc_net_set_xz (net, vpiZ);
}
void stimc_net_set_x (stimc_net net)
{
    stimc_net_set_xz (net, vpiX);
}

bool stimc_net_is_xz (stimc_net net)
{
    unsigned size = vpi_get (vpiSize, net->net);

    s_vpi_value v;

    if (size == 1) {
        v.format = vpiScalarVal;
        vpi_get_value (net->net, &v);
        if ((v.value.scalar == vpiX) || (v.value.scalar == vpiZ)) {
            return true;
        } else {
            return false;
        }
    }

    unsigned vsize = ((size - 1) / 32) + 1;
    v.format = vpiVectorVal;
    vpi_get_value (net->net, &v);
    for (unsigned i = 0; i < vsize; i++) {
        if (v.value.vector[i].bval != 0) return true;
    }
    return false;
}

void stimc_net_set_bits_uint64 (stimc_net net, unsigned msb, unsigned lsb, uint64_t value)
{
    unsigned size = vpi_get (vpiSize, net->net);

    static s_vpi_value v;

    int32_t flags = vpiNoDelay;

    unsigned vsize = ((size - 1) / 32) + 1;

    v.format = vpiVectorVal;
    vpi_get_value (net->net, &v);

    unsigned jstart = lsb / 32;
    unsigned s0     = lsb % 32;
    unsigned jstop  = msb / 32;

    uint64_t mask = ((2 << (msb - lsb)) - 1);
    fprintf (stderr, "DEBUG: lsb=%d, msb=%d, mask=0x%016lx\n", lsb, msb, mask);

    for (unsigned i = 0, j = jstart; (j < vsize) && (j <= jstop) && (i < 3); i++, j++) {
        uint32_t i_mask;
        uint32_t i_val;

        if (i == 0) {
            i_mask = mask << s0;
            i_val  = (value & mask) << s0;
        } else {
            i_mask = mask           >> (32 * i - s0);
            i_val  = (value & mask) >> (32 * i - s0);
        }
        fprintf (stderr, "DEBUG: i=%d, j=%d, mask=0x%08x, value=0x%08x\n", i, j, i_mask, i_val);

        v.value.vector[i].aval &= ~i_mask;
        v.value.vector[i].aval |=  i_val;
        v.value.vector[i].bval &= ~i_mask;
    }

    vpi_put_value (net->net, &v, NULL, flags);
}

uint64_t stimc_net_get_bits_uint64 (stimc_net net, unsigned lsb, unsigned msb)
{
    unsigned size = vpi_get (vpiSize, net->net);

    s_vpi_value v;

    unsigned vsize = ((size - 1) / 32) + 1;

    v.format = vpiVectorVal;
    vpi_get_value (net->net, &v);

    uint64_t result = 0;

    unsigned jstart = lsb / 32;
    unsigned s0     = lsb % 32;
    unsigned jstop  = msb / 32;

    for (unsigned i = 0, j = jstart; (j < vsize) && (j <= jstop) && (i < 3); i++, j++) {
        if (i == 0) {
            result |= (((uint64_t)v.value.vector[i].aval & ~((uint64_t)v.value.vector[i].bval)) >> s0);
        } else {
            result |= (((uint64_t)v.value.vector[i].aval & ~((uint64_t)v.value.vector[i].bval)) << (32 * i - s0));
        }
    }

    result &= ((uint64_t)2 << (msb - lsb)) - 1;

    return result;
}

void stimc_net_set_uint64 (stimc_net net, uint64_t value)
{
    unsigned size = vpi_get (vpiSize, net->net);

    static s_vpi_value v;

    int32_t flags = vpiNoDelay;

    if (size == 1) {
        v.format       = vpiScalarVal;
        v.value.scalar = (value ? vpi1 : vpi0);
        vpi_put_value (net->net, &v, NULL, flags);
        return;
    }

    unsigned vsize = ((size - 1) / 32) + 1;
    if (vsize <= SOCC_VALVECTOR_MAX_STATIC) {
        s_vpi_vecval vec[SOCC_VALVECTOR_MAX_STATIC];
        for (unsigned i = 0; (i < vsize) && (i < 2); i++) {
            vec[i].aval = (value >> (32 * i)) & 0xffffffff;
            vec[i].bval = 0;
        }
        for (unsigned i = 2; i < vsize; i++) {
            vec[i].aval = 0;
            vec[i].bval = 0;
        }
        v.format       = vpiVectorVal;
        v.value.vector = &(vec[0]);
        vpi_put_value (net->net, &v, NULL, flags);
        return;
    }

    s_vpi_vecval *vec = (s_vpi_vecval *)malloc (vsize * sizeof (s_vpi_vecval));
    for (unsigned i = 0; (i < vsize) && (i < 2); i++) {
        vec[i].aval = (value >> (32 * i)) & 0xffffffff;
        vec[i].bval = 0;
    }
    for (unsigned i = 2; i < vsize; i++) {
        vec[i].aval = 0;
        vec[i].bval = 0;
    }
    v.format       = vpiVectorVal;
    v.value.vector = vec;
    vpi_put_value (net->net, &v, NULL, flags);

    free (vec);
}

uint64_t stimc_net_get_uint64 (stimc_net net)
{
    unsigned size = vpi_get (vpiSize, net->net);

    s_vpi_value v;

    unsigned vsize = ((size - 1) / 32) + 1;

    v.format = vpiVectorVal;
    vpi_get_value (net->net, &v);

    uint64_t result = 0;
    for (unsigned i = 0; (i < vsize) && (i < 2); i++) {
        result |= (((uint64_t)v.value.vector[i].aval & ~((uint64_t)v.value.vector[i].bval)) << (32 * i));
    }

    return result;
}

static inline void stimc_net_set_uint64_callback_nonblock_gen (PLI_INT32 (*cb_rtn)(struct t_cb_data *), stimc_net net)
{
    s_cb_data   data;
    s_vpi_time  data_time;
    s_vpi_value data_value;

    data.reason        = cbReadWriteSynch;
    data.cb_rtn        = cb_rtn;
    data.obj           = NULL;
    data.time          = &data_time;
    data.time->type    = vpiSimTime;
    data.time->high    = 0;
    data.time->low     = 0;
    data.time->real    = 0;
    data.value         = &data_value;
    data.value->format = vpiSuppressVal;
    data.index         = 0;
    data.user_data     = (PLI_BYTE8 *)net;

    if (net->nba_cb_handle != NULL) {
        vpi_remove_cb (net->nba_cb_handle);
    }
    net->nba_cb_handle = vpi_register_cb (&data);
    assert (net->nba_cb_handle);
}

static PLI_INT32 stimc_net_set_x_nonblock_callback_wrapper (struct t_cb_data *cb_data)
{
    stimc_net net = (stimc_net)cb_data->user_data;

    stimc_net_set_x (net);
    vpi_remove_cb (net->nba_cb_handle);
    net->nba_cb_handle = NULL;

    return 0;
}

static PLI_INT32 stimc_net_set_z_nonblock_callback_wrapper (struct t_cb_data *cb_data)
{
    stimc_net net = (stimc_net)cb_data->user_data;

    stimc_net_set_z (net);
    vpi_remove_cb (net->nba_cb_handle);
    net->nba_cb_handle = NULL;

    return 0;
}

void stimc_net_set_z_nonblock (stimc_net net)
{
    stimc_net_set_uint64_callback_nonblock_gen (stimc_net_set_z_nonblock_callback_wrapper, net);
}
void stimc_net_set_x_nonblock (stimc_net net)
{
    stimc_net_set_uint64_callback_nonblock_gen (stimc_net_set_x_nonblock_callback_wrapper, net);
}

static PLI_INT32 stimc_net_set_uint64_nonblock_callback_wrapper (struct t_cb_data *cb_data)
{
    stimc_net net = (stimc_net)cb_data->user_data;

    stimc_net_set_uint64 (net, net->nba_value);
    vpi_remove_cb (net->nba_cb_handle);
    net->nba_cb_handle = NULL;

    return 0;
}

static PLI_INT32 stimc_net_set_bits_uint64_nonblock_callback_wrapper (struct t_cb_data *cb_data)
{
    stimc_net net = (stimc_net)cb_data->user_data;

    stimc_net_set_bits_uint64 (net, net->nba_msb, net->nba_lsb, net->nba_value);
    vpi_remove_cb (net->nba_cb_handle);
    net->nba_cb_handle = NULL;

    return 0;
}

static PLI_INT32 stimc_net_set_int32_nonblock_callback_wrapper (struct t_cb_data *cb_data)
{
    stimc_net net = (stimc_net)cb_data->user_data;

    stimc_net_set_int32 (net, net->nba_value);
    vpi_remove_cb (net->nba_cb_handle);
    net->nba_cb_handle = NULL;

    return 0;
}

void stimc_net_set_uint64_nonblock (stimc_net net, uint64_t value)
{
    net->nba_value = value;

    stimc_net_set_uint64_callback_nonblock_gen (stimc_net_set_uint64_nonblock_callback_wrapper, net);
}

void stimc_net_set_bits_uint64_nonblock (stimc_net net, unsigned msb, unsigned lsb, uint64_t value)
{
    net->nba_value = value;
    net->nba_msb   = msb;
    net->nba_lsb   = lsb;

    stimc_net_set_uint64_callback_nonblock_gen (stimc_net_set_bits_uint64_nonblock_callback_wrapper, net);
}

void stimc_net_set_int32_nonblock (stimc_net net, int32_t value)
{
    net->nba_value = value;

    stimc_net_set_uint64_callback_nonblock_gen (stimc_net_set_int32_nonblock_callback_wrapper, net);
}

