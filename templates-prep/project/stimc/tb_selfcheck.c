#include "tb_selfcheck.h"
#include <stimc.h>

#include <stdio.h>

void tb_final_check (unsigned checks_done, unsigned errors, bool offensive)
{
        fprintf (stderr,"\n");
        if (checks_done <= 0) {
            if (offensive) {
                fprintf (stderr," #####   ####  ### ### ##  ## ##### #####   \n");
                fprintf (stderr," ##  ## ##  ## ####### ### ## ##    ##  ##  \n");
                fprintf (stderr," ##  ## ###### ## # ## ###### ####  ##  ##  \n");
                fprintf (stderr," ##  ## ##  ## ## # ## ## ### ##    ##  ##  \n");
                fprintf (stderr," #####  ##  ## ##   ## ##  ## ##### #####   \n");
                fprintf (stderr,"\n");
            }
            /* unknown */
            fprintf (stderr," ##  ## ##  ## ## ## ##  ##  ####  ##   ## ##  ##  \n");
            fprintf (stderr," ##  ## ### ## ####  ### ## ##  ## ## # ## ### ##  \n");
            fprintf (stderr," ##  ## ###### ###   ###### ##  ## ## # ## ######  \n");
            fprintf (stderr," ##  ## ## ### ####  ## ### ##  ## ####### ## ###  \n");
            fprintf (stderr,"  ####  ##  ## ## ## ##  ##  ####   ## ##  ##  ##  \n");
            fprintf (stderr,"\n");
            fprintf (stderr,"TBCHECK: UNWNOWN\n");
        } else if (errors == 0) {
            if (offensive) {
                fprintf (stderr," #####  ##    ####   ####  #####  ##  ##         ##   ## ##### ##    ##      \n");
                fprintf (stderr," ##  ## ##   ##  ## ##  ## ##  ## ##  ##         ## # ## ##    ##    ##      \n");
                fprintf (stderr," #####  ##   ##  ## ##  ## ##  ##  ####          ## # ## ####  ##    ##      \n");
                fprintf (stderr," ##  ## ##   ##  ## ##  ## ##  ##   ##           ####### ##    ##    ##      \n");
                fprintf (stderr," #####  ##### ####   ####  #####    ##            ## ##  ##### ##### #####   \n");
                fprintf (stderr,"\n");
            }
            /* passed */
            fprintf (stderr," #####   ####   ##### ##### ##### #####   \n");
            fprintf (stderr," ##  ## ##  ## ##    ##     ##    ##  ##  \n");
            fprintf (stderr," #####  ######  ####  ####  ####  ##  ##  \n");
            fprintf (stderr," ##     ##  ##     ##    ## ##    ##  ##  \n");
            fprintf (stderr," ##     ##  ## ##### #####  ##### #####   \n");
            fprintf (stderr,"\n");
            fprintf (stderr,"TBCHECK: PASSED\n");
        } else {
            if (offensive) {
                fprintf (stderr," ##### ##  ##  ####  ## ## #### ##  ##  #####  \n");
                fprintf (stderr," ##    ##  ## ##  ## ####   ##  ### ## ##      \n");
                fprintf (stderr," ####  ##  ## ##     ###    ##  ###### ## ###  \n");
                fprintf (stderr," ##    ##  ## ##  ## ####   ##  ## ### ##  ##  \n");
                fprintf (stderr," ##     ####   ####  ## ## #### ##  ##  ####   \n");
                fprintf (stderr,"\n");
            }
            /* failed */
            fprintf (stderr," ##### ####  #### ##    ##### #####   \n");
            fprintf (stderr," ##   ##  ##  ##  ##    ##    ##  ##  \n");
            fprintf (stderr," #### ######  ##  ##    ####  ##  ##  \n");
            fprintf (stderr," ##   ##  ##  ##  ##    ##    ##  ##  \n");
            fprintf (stderr," ##   ##  ## #### ##### ##### #####   \n");
            fprintf (stderr,"\n");
            fprintf (stderr,"TBCHECK: FAILED\n");
        }
        stimc_finish ();
}
