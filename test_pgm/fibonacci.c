void delay();
register int i   asm ("s11");
register int d   asm ("s10");

asm ("addi sp, s0, 1024");

void    delay(int);

int main() {
    int i_prev  = 0;
    i           = 1;
    d           = 10000000;

    while(1) {
        delay(d);
        i       = i + i_prev;
        i_prev  = i - i_prev;
    }
}

void delay(int delay) {
    for(int i = 0; i < delay; i++);
}
