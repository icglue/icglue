#ifndef __APB_STIM_H__
#define __APB_STIM_H__

#include "stimc++.h"
#include "regfile_contrib.h"

class apb_stim : public stimcxx_module, regfile_dev_subword {
    private:
        parameter ID;

        port apb_clk_i;
        port apb_resetn_i;
        port apb_clk_en_o;

        port apb_addr_o;
        port apb_sel_o;
        port apb_enable_o;
        port apb_write_o;
        port apb_strb_o;
        port apb_prot_o;
        port apb_wdata_o;

        port apb_ready_i;
        port apb_rdata_i;
        port apb_slverr_i;

        stimcxx_event clk_event;
        stimcxx_event reset_release_event;

    public:
        apb_stim ();
        virtual ~apb_stim ();

        bool write (uint32_t addr, uint8_t strb, uint32_t wdata);
        bool read (uint32_t addr, uint32_t &rdata);
        void testcontrol ();
        void clock ();
        void reset_release ();

        rf_data_t rfdev_read (rf_addr_t addr)
        {
            uint32_t rdata;

            read (addr, rdata);
            return rdata;
        }
        void rfdev_write_subword (rf_addr_t addr, rf_data_t value, unsigned int size)
        {
            uint8_t strb = ((1 << size) - 1) << (addr & 0x3);

            write (addr, strb, value);
        }
};

#endif

