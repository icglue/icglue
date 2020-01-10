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

#ifndef __STIMCXX_H__
#define __STIMCXX_H__

#include <stimc.h>

class stimcxx_event {
    private:
        stimc_event _event;
    public:
        stimcxx_event ();
        virtual ~stimcxx_event ();

        void wait ()
        {
            stimc_wait_event (_event);
        }
        void trigger ()
        {
            stimc_trigger_event (_event);
        }
};

class stimcxx_module {
    private:
        stimc_module _module;
    public:
        stimcxx_module ();
        virtual ~stimcxx_module ();

        const char *module_id ()
        {
            return _module.id;
        }

        static void wait (double time_seconds)
        {
            stimc_wait_time_seconds (time_seconds);
        }
        static void wait (uint64_t time, int exp)
        {
            stimc_wait_time (time, exp);
        }
        static void wait (stimcxx_event &e)
        {
            e.wait ();
        }
        static double time ()
        {
            return stimc_time_seconds ();
        }
        static uint64_t time (int exp)
        {
            return stimc_time (exp);
        }

        static void finish ()
        {
            stimc_finish ();
        }

    public:
        class port {
            public:
                stimc_port _port;
            public:
                class subbits {
                    private:
                        int _lsb;
                        int _msb;
                        port &_p;
                    public:
                        subbits (port &p, int msb, int lsb) :
                            _lsb (lsb), _msb (msb), _p (p) {}
                        subbits (subbits &b) :
                            _lsb (b._lsb), _msb (b._msb), _p (b._p) {}

                        virtual ~subbits () {}

                        operator uint64_t ()
                        {
                            return stimc_net_get_bits_uint64 (_p._port, _msb, _lsb);
                        }

                        subbits& operator= (uint64_t value)
                        {
                            stimc_net_set_bits_uint64 (_p._port, _msb, _lsb, value);
                            return *this;
                        }

                        subbits& operator<<= (uint64_t value)
                        {
                            stimc_net_set_bits_uint64_nonblock (_p._port, _msb, _lsb, value);
                            return *this;
                        }
                };
            public:
                port (stimcxx_module &m, const char *name);
                virtual ~port ();

                port& operator= (uint64_t value)
                {
                    stimc_net_set_uint64 (_port, value);
                    return *this;
                }
                port& operator<<= (uint64_t value)
                {
                    stimc_net_set_uint64_nonblock (_port, value);
                    return *this;
                }
                operator uint64_t ()
                {
                    return stimc_net_get_uint64 (_port);
                }

                void nb_set_x ()
                {
                    stimc_net_set_x_nonblock (_port);
                }
                void nb_set_z ()
                {
                    stimc_net_set_z_nonblock (_port);
                }
                void set_x ()
                {
                    stimc_net_set_x (_port);
                }
                void set_z ()
                {
                    stimc_net_set_z (_port);
                }
                bool is_xz ()
                {
                    return stimc_net_is_xz (_port);
                }

                subbits bits (int msb, int lsb)
                {
                    subbits b (*this, msb, lsb);

                    return b;
                }
        };

        class parameter {
            protected:
                stimc_parameter _parameter;
                int32_t _value;
            public:
                parameter (stimcxx_module &m, const char *name);
                virtual ~parameter ();

                int value ()
                {
                    return _value;
                }
                operator uint64_t ()
                {
                    return _value;
                }
        };
};

#define STIMCXX_PARAMETER(port) \
    port (*this, #port)

#define STIMCXX_PORT(port) \
    port (*this, #port)

#define STIMCXX_REGISTER_STARTUP_THREAD(thread) \
    typedef decltype (this) thisptype; \
    class _stimcxx_thread_init_ ## thread { \
        public: \
            static void callback (void *p) { \
                thisptype m = (thisptype)p; \
                m->thread (); \
            } \
    }; \
    stimc_register_startup_thread (_stimcxx_thread_init_ ## thread::callback, (void *)this)

#define STIMCXX_REGISTER_METHOD(event, port, func) \
    typedef decltype (this) thisptype; \
    class _stimcxx_method_init_ ## event ## func { \
        public: \
            static void callback (void *p) { \
                thisptype m = (thisptype)p; \
                m->func (); \
            } \
    }; \
    stimc_register_ ## event ## _method (_stimcxx_method_init_ ## event ## func ::callback, (void *)this, port._port)


#define STIMCXX_INIT(module) \
    static int _stimcxx_module_ ## module ## _init_cptf (PLI_BYTE8 * user_data __attribute__((unused))) \
    { \
        return 0; \
    } \
    \
    static int _stimcxx_module_ ## module ## _init_cltf (PLI_BYTE8 * user_data __attribute__((unused))) \
    { \
        module *m __attribute__((unused)); \
        m = new module (); \
    \
        return 0; \
    } \
    \
    void _stimc_module_ ## module ## _register (void) \
    { \
        s_vpi_systf_data tf_data; \
        static char      tf_name[] = "$stimc_" #module "_init"; \
    \
        tf_data.type      = vpiSysTask; \
        tf_data.tfname    = tf_name; \
        tf_data.calltf    = _stimcxx_module_ ## module ## _init_cltf; \
        tf_data.compiletf = _stimcxx_module_ ## module ## _init_cptf; \
        tf_data.sizetf    = 0; \
        tf_data.user_data = NULL; \
    \
        vpi_register_systf (&tf_data); \
    }

#endif

