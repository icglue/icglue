#include <apb_stim.h>
#include <rf_crc.hpp>
#include <tb_selfcheck.h>

void apb_stim::testcontrol (void) {
    unsigned errors = 0;
    unsigned checks = 0;

    rf_crc_t *rf = new rf_crc_t (*this, 0);

    wait (10, SC_NS);

    for (int i = 0; i < 4; i++) {
        if (rf->control.en != 0) {
            errors++;
            printf ("ERROR: expected en = 0\n");
        }
        rf->control.en = 1;
        checks++;
        if (rf->control.en != 1) {
            errors++;
            printf ("ERROR: expected en = 1\n");
        }
        rf->control.en = 0;
        checks++;
    }

    tb_final_check (checks, errors, true);
}
