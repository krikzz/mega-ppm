
#include "appmain.h"

int main() {

    neorv32_uart_setup(BAUD_RATE, 0, 0);
    GPIO_OUTPUT = 0; //cart leds
    printf("\n");


    ppm_start();

    FPGAIO->ctrl.exit_to_menu = 1;
    while (1) {
        asm("nop");
    }

    return 0;
}

void printHex(void *src, u32 size) {

    u8 *ptr = (u8 *) src;

    for (int i = 0; i < size; i += 4) {
        if (i % 16 == 0) {
            printf("\n");
        }
        printf("%x ", *(u32 *) & ptr[i]);
    }
    printf("\n");
}