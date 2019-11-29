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

#include "stimc++.h"

stimcxx_module::stimcxx_module ()
{
    stimc_module_init (&(this->_module));
}

stimcxx_module::~stimcxx_module ()
{}

stimcxx_module::port::port (stimcxx_module &m, const char *name)
{
    this->_port = stimc_port_init (&(m._module), name);
}

stimcxx_module::port::~port ()
{}

stimcxx_module::parameter::parameter (stimcxx_module &m, const char *name)
{
    this->_parameter = stimc_parameter_init (&(m._module), name);

    s_vpi_value v;
    v.format = vpiIntVal;
    vpi_get_value (this->_parameter, &v);

    this->_value = v.value.integer;
}

stimcxx_module::parameter::~parameter ()
{}

stimcxx_event::stimcxx_event ()
{
    this->_event = stimc_event_create ();
}

stimcxx_event::~stimcxx_event ()
{
    stimc_event_free (this->_event);
}

