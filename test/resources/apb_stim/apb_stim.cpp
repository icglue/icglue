#include "apb_stim.h"

apb_stim::apb_stim () :
    STIMCXX_PARAMETER (ID),

    STIMCXX_PORT (apb_clk_i),
    STIMCXX_PORT (apb_resetn_i),
    STIMCXX_PORT (apb_clk_en_o),

    STIMCXX_PORT (apb_addr_o),
    STIMCXX_PORT (apb_sel_o),
    STIMCXX_PORT (apb_enable_o),
    STIMCXX_PORT (apb_write_o),
    STIMCXX_PORT (apb_strb_o),
    STIMCXX_PORT (apb_prot_o),
    STIMCXX_PORT (apb_wdata_o),

    STIMCXX_PORT (apb_ready_i),
    STIMCXX_PORT (apb_rdata_i),
    STIMCXX_PORT (apb_slverr_i)
{
    /* init... */
    apb_clk_en_o <<= 0;
    apb_sel_o    <<= 0;
    apb_enable_o <<= 0;
    apb_write_o  <<= 0;
    apb_prot_o   <<= 0;
    apb_addr_o   <<= 0;
    apb_wdata_o  <<= 0;
    apb_strb_o   <<= 0;

    STIMCXX_REGISTER_STARTUP_THREAD (testcontrol);
    STIMCXX_REGISTER_METHOD (posedge, apb_clk_i, clock);
    STIMCXX_REGISTER_METHOD (posedge, apb_resetn_i, reset_release);
}

apb_stim::~apb_stim ()
{}

bool apb_stim::write (uint32_t addr, uint8_t strb, uint32_t wdata)
{
    apb_clk_en_o <<= 1;
    apb_sel_o    <<= 1;
    apb_write_o  <<= 1;
    apb_addr_o   <<= addr;
    apb_wdata_o  <<= wdata;
    apb_strb_o   <<= strb;
    wait (clk_event);
    apb_enable_o <<= 1;

    bool result = true;
    while (true) {
        wait (clk_event);
        if (apb_ready_i == 1) {
            if (apb_slverr_i == 1) {
                result = false;
            }
            break;
        }
    }

    apb_clk_en_o <<= 0;
    apb_sel_o    <<= 0;
    apb_enable_o <<= 0;
    apb_write_o  <<= 0;
    apb_addr_o   <<= 0;
    apb_wdata_o  <<= 0;
    apb_strb_o   <<= 0;

    return result;
}

bool apb_stim::read (uint32_t addr, uint32_t &rdata)
{
    apb_clk_en_o <<= 1;
    apb_sel_o    <<= 1;
    apb_write_o  <<= 0;
    apb_addr_o   <<= addr;
    apb_wdata_o  <<= 0;
    apb_strb_o   <<= 0;
    wait (clk_event);
    apb_enable_o <<= 1;

    bool result = true;
    while (true) {
        wait (clk_event);
        if (apb_ready_i == 1) {
            if (apb_slverr_i == 1) {
                result = false;
            }
            break;
        }
    }

    apb_clk_en_o <<= 0;
    apb_sel_o    <<= 0;
    apb_enable_o <<= 0;
    apb_write_o  <<= 0;
    apb_addr_o   <<= 0;
    apb_strb_o   <<= 0;

    rdata = apb_rdata_i;

    return result;
}

void __attribute__((weak)) apb_stim::testcontrol ()

{
}

void apb_stim::clock ()
{
    clk_event.trigger ();
}

void apb_stim::reset_release ()
{
    reset_release_event.trigger ();
}


STIMCXX_INIT (apb_stim)

