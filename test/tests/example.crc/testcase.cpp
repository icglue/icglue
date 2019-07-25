
#include <apb_stim.h>
#include <rf_crc.h>
#include <tb_selfcheck.h>

// see https://crccalc.com/

#if 1
/*  CRC-8/SAE-J1850-ZERO */
#define CRC_WIDTH 8
#define CHECK     0x37
#define CRC_POLY  0x1D
#define CRC_INIT  0x00
#define REFIN     false
#define REFOUT    false
#define XOROUT    0x00
#elif 1
/*  CRC-8/DVB-S2 */
#define CRC_WIDTH 8
#define CHECK     0xBC
#define CRC_POLY  0xD5
#define CRC_INIT  0x00
#define REFIN     false
#define REFOUT    false
#define XOROUT    0x00
#elif 1
/*  CRC-16/USB */
#define CRC_WIDTH 16
#define CHECK     0xB4C8
#define CRC_POLY  0x8005
#define CRC_INIT  0xFFFF
#define REFIN     true
#define REFOUT    true
#define XOROUT    0xFFFF
#elif 1
/* CRC-16/CCITT-FALSE */
#define CRC_WIDTH 16
#define CHECK     0x29B1
#define CRC_POLY  0x1021
#define CRC_INIT  0xFFFF
#define REFIN     false
#define REFOUT    false
#define XOROUT    0x0000
#endif

unsigned int calc_crc(unsigned char message[], unsigned char length, bool refin, bool refout)
{
    unsigned int i, j, crc = CRC_INIT;
    unsigned int msg;

    for (i=0; i<length; i++) {
        msg = message[i];
        for (j=0; j<8; j++) {
            crc <<= 1;
            if ((crc & (1<<(CRC_WIDTH)))) {
                crc ^= CRC_POLY;
            }
            if (refin == 0) {
                if (msg & (1<<7)) {
                    crc ^= CRC_POLY;
                }
                msg <<= 1;
            } else {
                if (msg & 1) {
                    crc ^= CRC_POLY;
                }
                msg >>= 1;
            }
        }
    }

    crc = (crc & ((1<<CRC_WIDTH)-1));
    if (refout == 0) {
        return crc;
    } else {
        unsigned int crc_ref  = 0;
        unsigned int crc_mask = 1<<CRC_WIDTH;
        for (i=0; i<CRC_WIDTH; i++) {
            crc_mask >>= 1;
            if (crc & (1<<i)) {
                crc_ref |= crc_mask;
            }
        }
        return crc_ref;
    }
}

void apb_stim::testcontrol (void) {
    unsigned errors = 0;
    unsigned checks = 0;

    rf_crc_t *rf_crc = new rf_crc_t (*this, 0);

    wait (10, SC_NS);

    #define MSGLEN 9
    unsigned char message[] = { '1', '2', '3', '4', '5', '6', '7', '8', '9'};

    for (int i=0; i<MSGLEN; i++) {
        rf_crc->data.value  = message[i];
        if (rf_crc->next_common_state.value != rf_crc->next_fixed_state.value) {
            printf ("\nFAILURE: CRC common differs form fixed version (CRC = 0x%04X  -- REF = 0x%04X)\n", (unsigned int)rf_crc->next_common_state.value, (unsigned int)rf_crc->next_fixed_state.value);
            errors++;
        }
        checks++;
        if (i<MSGLEN-1) {
            rf_crc->state.value = rf_crc->next_fixed_state.value;
        }
    }

    unsigned int hardware_crc;

    if (!REFOUT) {
        hardware_crc = rf_crc->next_fixed_state.value;
    } else {
        hardware_crc = rf_crc->next_fixed_state_reflected.value;
    }
    printf ("HARDWARE-CRC: 0x%04X\n", hardware_crc ^ XOROUT);
    unsigned int software_crc = calc_crc(message, MSGLEN, REFIN, REFOUT);
    printf ("SOFTWARE-CRC: 0x%04X\n", software_crc ^ XOROUT);

    if (hardware_crc == software_crc) {
        printf ("\nSUCCESS: CRC equals reference implementation.\n");
        if ((hardware_crc ^ XOROUT) == CHECK) {
            printf ("SUCCESS: CRC equals CHECK = 0x%04X\n", CHECK);
        } else {
            printf ("\nFAILURE: CRC does not equal CHECK = 0x%04X -- CRC = 0x%04X\n", CHECK, hardware_crc ^ XOROUT);
            errors++;
        }
        checks++;
    } else {
        printf ("\nFAILURE: CRC does not equal reference implementation (CRC = 0x%04X  -- REF = 0x%0X)\n", hardware_crc, software_crc);
        errors++;
    }
    checks++;
    wait (10, SC_NS);

    tb_final_check (checks, errors, true);
}
